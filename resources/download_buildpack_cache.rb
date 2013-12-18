#!/usr/bin/env ruby
# Encoding: utf-8

require 'net/http'
require 'uri'
require 'fileutils'
require 'yaml'
require 'logger'

$LOAD_PATH.unshift File.expand_path(File.join('..', '..', 'lib'), __FILE__)
require 'liberty_buildpack/repository/version_resolver'
require 'liberty_buildpack/util/tokenized_version'

# Utility class to download remote resources into local cache directory
class BuildpackCache

  INDEX_PATH = '/index.yml'.freeze
  REPOSITORY_ROOT = 'repository_root'.freeze
  VERSION = 'version'.freeze
  URI_KEY = 'uri'.freeze
  LICENSE_KEY = 'license'.freeze

  # Creates an instance with the specified logger and locale cache destination
  #
  # @param [String] cache_dir cache directory
  # @param [Logger] logger output destination for loggin information. Using STDOUT by default.
  def initialize(cache_dir, logger = nil)
    @cache_dir = cache_dir
    @logger = logger || Logger.new(STDOUT)
  end

  # Downloads remote resources into the cache directory
  #
  # @param [Array<Hash>] configs array of configurations referencing index.yml
  def download_cache(configs)
    if configs.empty?
      @logger.warn 'No cache to download.'
      return
    end

    FileUtils.mkdir_p(@cache_dir)

    configs.each do |config|
      # Download index.yml first.
      index_uri = index_path(config)
      download(index_uri)
      # Parse index.yml to see what files it references
      begin
        index = YAML.load_file(File.join(@cache_dir, filename(index_uri)))
      rescue => e
        abort "ERROR: Failed loading #{index_uri}: #{e}"
      end
      candidate = LibertyBuildpack::Util::TokenizedVersion.new(config[VERSION])
      version = LibertyBuildpack::Repository::VersionResolver.resolve(candidate, index.keys)
      version_info = index[version.to_s]
      if version_info.is_a? Hash
        file_uri = version_info[URI_KEY]
        license_uri = index[version.to_s][LICENSE_KEY]
        download(license_uri) if license_uri
      else
        file_uri = version_info
      end
      download(file_uri)
    end
  end

  # Obtains the path for a repository
  #
  # @param [Hash] config the configuration for the repository
  # @return [String] the path to the index.yml
  def index_path(config)
    uri = config[REPOSITORY_ROOT]
    uri = uri[0..-2] while uri.end_with? '/'
    "#{uri}#{INDEX_PATH}"
  end

  # Downloads remote location into a file in the cache directory
  #
  # @param [String] uri location of the remote resource
  def download(uri)
    target = File.join(@cache_dir, filename(uri))
    @logger.debug "Downloading file to #{target}"
    rich_uri = URI(uri)
    Net::HTTP.start(rich_uri.host, rich_uri.port, use_ssl: rich_uri.scheme == 'https') do |http|
      request = Net::HTTP::Get.new(rich_uri.request_uri)
      http.request request do |response|
        File.open(target, File::CREAT | File::WRONLY) do |file|
          response.read_body do |chunk|
            file.write(chunk)
          end
        end
      end
    end
  rescue => e
    @logger.error "Unable to download from #{uri}"
    puts e.backtrace
  end

  # Converts URI into a filename used in cache.
  #
  # @param [String] uri location of the remote resource
  def filename(uri)
    "#{URI.escape(uri, '/')}.cached"
  end

  # Returns array of config maps containing references to the root index.yml
  # of file sets to be included in the cache.
  #
  # @param [Array<String>] config_files list of config files to check. By default it contains all yml files in buildpack config directory.
  # @param [Array<String>] cached_hosts list of host names which content should be cached
  def collect_configs(config_files = nil, cached_hosts = ['public.dhe.ibm.com'])
    config_files = Dir[File.expand_path(File.join('..', '..', 'config', '*.yml'), __FILE__)] if config_files.nil?
    configs = []
    config_files.each do |file|
      @logger.debug "Checking #{file}"
      begin
        config = YAML.load_file(file)
      rescue => e
        abort "ERROR: Failed loading config #{file}: #{e}"
      end
      if !config.nil? && config.has_key?(REPOSITORY_ROOT) && config.has_key?(VERSION) && cached_hosts.include?(URI(config[REPOSITORY_ROOT]).host)
        configs.push(config)
      end
    end
    configs
  end
end

if __FILE__ == $PROGRAM_NAME
  if ARGV.length < 1
    puts "Usage: #{File.basename __FILE__} /path/to/cache"
    exit 1
  end

  bc = BuildpackCache.new(File.expand_path(ARGV[0]))
  configs = bc.collect_configs
  bc.download_cache(configs)

end
