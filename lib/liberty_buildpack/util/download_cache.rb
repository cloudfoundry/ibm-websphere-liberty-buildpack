# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2013 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'liberty_buildpack/diagnostics'
require 'liberty_buildpack/util'
require 'net/http'
require 'tmpdir'
require 'uri'

module LibertyBuildpack::Util

  # A cache for downloaded files that is configured to use a filesystem as the backing store. This cache uses standard
  # file locking (<tt>File.flock()</tt>) in order ensure that mutation of files in the cache is non-concurrent across
  # processes.  Reading files (once they've been downloaded) happens concurrently so read performance is not impacted.
  class DownloadCache

    # Creates an instance of the cache that is backed by the filesystem rooted at +cache_root+
    #
    # @param [String] cache_root the filesystem root for downloaded files to be cached in
    def initialize(cache_root = Dir.tmpdir)
      Dir.mkdir(cache_root) unless File.exists? cache_root
      @cache_root = cache_root
      @logger = LibertyBuildpack::Diagnostics::LoggerFactory.get_logger
    end

    # Retrieves an item from the cache.  Retrieval of the item uses the following algorithm:
    #
    # 1. Obtain an exclusive lock based on the URI of the item. This allows concurrency for different items, but not for
    #    the same item.
    # 2. If the the cached item does not exist, download from +uri+ and cache it, its +Etag+, and its +Last-Modified+
    #    values if they exist.
    # 3. If the cached file does exist, and the original download had an +Etag+ or a +Last-Modified+ value, attempt to
    #    download from +uri+ again.  If the result is +304+ (+Not-Modified+), then proceed without changing the cached
    #    item.  If it is anything else, overwrite the cached file and its +Etag+ and +Last-Modified+ values if they exist.
    # 4. Downgrade the lock to a shared lock as no further mutation of the cache is possible.  This allows concurrency for
    #    read access of the item.
    # 5. Yield the cached file (opened read-only) to the passed in block. Once the block is complete, the file is closed
    #    and the lock is released.
    #
    # @param [String] uri the uri to download if the item is not already in the cache.  Also used in the case where the
    #                     item is already in the cache, to validate that the item is up to date
    # @yieldparam [File] file the file representing the cached item. In order to ensure that the file is not changed or
    #                    deleted while it is being used, the cached item can only be accessed as part of a block.
    # @return [void]
    def get(uri)
      filenames = filenames(uri)
      File.open(filenames[:lock], File::CREAT) do |lock_file|
        lock_file.flock(File::LOCK_EX)

        if should_update(filenames)
          update(filenames, uri)
        elsif should_download(filenames)
          download(filenames, uri)
        end

        lock_file.flock(File::LOCK_SH)

        File.open(filenames[:cached], File::RDONLY) do |cached_file|
          yield cached_file
        end
      end
    end

    # Remove an item from the cache
    #
    # @param [String] uri the URI of the item to remove
    # @return [void]
    def evict(uri)
      filenames = filenames(uri)
      File.open(filenames[:lock], File::CREAT) do |lock_file|
        lock_file.flock(File::LOCK_EX)

        delete_file filenames[:cached]
        delete_file filenames[:etag]
        delete_file filenames[:last_modified]
        delete_file filenames[:lock]
      end
    end

    private

      ADMIN_CACHE = File.join('..', '..', '..', 'admin_cache').freeze

      HTTP_ERRORS = [
        EOFError,
        Errno::ECONNREFUSED,
        Errno::ECONNRESET,
        Errno::EHOSTUNREACH,
        Errno::EINVAL,
        Errno::EPIPE,
        Errno::ETIMEDOUT,
        Net::HTTPBadResponse,
        Net::HTTPHeaderSyntaxError,
        Net::ProtocolError,
        SocketError,
        Timeout::Error
      ]

      def delete_file(filename)
        File.delete filename if File.exists? filename
      end

      def download(filenames, uri)
        return if look_aside(filenames, uri) || check_locally(filenames, uri)
        rich_uri = URI(uri)

        Net::HTTP.start(rich_uri.host, rich_uri.port, use_ssl: use_ssl?(rich_uri)) do |http|
          request = Net::HTTP::Get.new(rich_uri.request_uri)
          http.request request do |response|
            write_response(filenames, response)
          end
        end

      rescue *HTTP_ERRORS => e
        puts 'FAIL'
        raise "Unable to download from #{uri}: #{e}"
      end

      def filenames(uri)
        key = URI.escape(uri, '/')
        {
          cached: File.join(@cache_root, "#{key}.cached"),
          etag: File.join(@cache_root, "#{key}.etag"),
          last_modified: File.join(@cache_root, "#{key}.last_modified"),
          lock: File.join(@cache_root, "#{key}.lock")
        }
      end

      def persist_header(response, header, filename)
        unless response[header].nil?
          File.open(filename, File::CREAT | File::WRONLY) do |file|
            file.write(response[header])
          end
        end
      end

      def set_header(request, header, filename)
        if File.exists?(filename)
          File.open(filename, File::RDONLY) do |file|
            request[header] = file.read
          end
        end
      end

      def should_download(filenames)
        !File.exists?(filenames[:cached])
      end

      def should_update(filenames)
        File.exists?(filenames[:cached]) && (File.exists?(filenames[:etag]) || File.exists?(filenames[:last_modified]))
      end

      def update(filenames, uri)
        rich_uri = URI(uri)

        Net::HTTP.start(rich_uri.host, rich_uri.port, use_ssl: use_ssl?(rich_uri)) do |http|
          request = Net::HTTP::Get.new(rich_uri.request_uri)
          set_header request, 'If-None-Match', filenames[:etag]
          set_header request, 'If-Modified-Since', filenames[:last_modified]

          http.request request do |response|
            write_response(filenames, response) unless response.code == '304'
          end
        end

      rescue *HTTP_ERRORS => e
        @logger.warn "Unable to update from #{uri}: #{e}. Using cached version."
      end

      def look_aside(filenames, uri)
        cache_locations = []
        cache_locations << File.expand_path(ADMIN_CACHE, File.dirname(__FILE__))
        buildpack_cache_directory = ENV['BUILDPACK_CACHE']
        cache_locations << File.join(buildpack_cache_directory, 'ibm-liberty-buildpack') unless buildpack_cache_directory.nil?
        cache_locations = cache_locations.select { |location| File.directory? location }
        return false if cache_locations.empty?
        @logger.debug "Looking in buildpack cache for #{uri}."
        key = URI.escape(uri, '/')
        cache_locations.each do |buildpack_cache|
          stashed = File.join(buildpack_cache, "#{key}.cached")
          @logger.debug { "Looking in buildpack cache for file '#{stashed}'" }
          if File.exist? stashed
            copy_to_cache(stashed, filenames[:cached])
            @logger.debug "Using copy of #{uri} from buildpack cache."
            return true
          else
            @logger.debug "Buildpack cache does not contain #{uri}..."
            @logger.debug { "Buildpack cache contents:\n#{`ls -lR #{buildpack_cache}`}" }
          end
        end
        false
      end

      def copy_to_cache(stashed, cache_filename)
        if File.basename(stashed).end_with?('.bin.cached')
          FileUtils.cp stashed, cache_filename
        else
          FileUtils.ln_s stashed, cache_filename
        end
      end

      def check_locally(filenames, uri)
        # Check if it's a local file and treat it as cached
        if File.exist?(uri)
          FileUtils.ln_s File.expand_path(uri), filenames[:cached]
          @logger.debug "Using local file #{uri}"
          return true
        end
          false
      end

      def use_ssl?(uri)
        uri.scheme == 'https'
      end

      def write_response(filenames, response)
        persist_header response, 'Etag', filenames[:etag]
        persist_header response, 'Last-Modified', filenames[:last_modified]

        File.open(filenames[:cached], File::CREAT | File::WRONLY) do |cached_file|
          response.read_body do |chunk|
            cached_file.write(chunk)
          end
        end
      end

  end

end
