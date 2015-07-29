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
  COMP_INDEX_PATH = '/component_index.yml'.freeze
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
      index_file = File.join(@cache_dir, filename(index_uri))
      download(index_uri, index_file)
      # Parse index.yml to see what files it references
      begin
        index = YAML.load_file(index_file)
      rescue => e
        abort "ERROR: Failed loading #{index_uri}: #{e}"
      end
      candidate = LibertyBuildpack::Util::TokenizedVersion.new(config[VERSION])
      version = LibertyBuildpack::Repository::VersionResolver.resolve(candidate, index.keys)
      file_uri = download_license(index[version.to_s])
      file = File.join(@cache_dir, filename(file_uri))
      download(file_uri, file)
      # If file is a component_index.yml parse and download files it references as well
      download_components(file_uri, file) if file_uri.end_with? COMP_INDEX_PATH
    end
  end

  def index_path(config)
    uri = config[REPOSITORY_ROOT]
    uri = uri[0..-2] while uri.end_with? '/'
    "#{uri}#{INDEX_PATH}"
  end

  def download_license(file_uri)
    if file_uri.is_a? Hash
      license_uri = file_uri[LICENSE_KEY]
      license_file = File.join(@cache_dir, filename(license_uri))
      download(license_uri, license_file)
      file_uri = file_uri[URI_KEY]
    end
    file_uri
  end

  # Downloads remote content referenced in component_index.yml
  def download_components(file_uri, file)
    begin
      comp_index = YAML.load_file(file)
    rescue => e
      abort "ERROR: Failed loading #{file_uri}: #{e}"
    end
    comp_index.values.each do |comp_uri|
      comp_file = File.join(@cache_dir, filename(comp_uri))
      download(comp_uri, comp_file)
    end
  end

  # Reads the environment variables to look for an HTTP proxy
  # and returns a Hash with the proxy host and port, if any.
  #
  # Read variables are (in this order): HTTPS_PROXY, https_proxy, HTTP_PROXY,
  # http_proxy. The first result obtained in this order is the one returned.
  #
  # If none is found, nil is returned.
  #
  # @return a hash like {:host => 'a host', :port => aPort} with the proxy configuration, or nil.
  def proxy_from_env
    proxy = ENV['HTTPS_PROXY']
    proxy = ENV['https_proxy'] unless proxy
    proxy = ENV['HTTP_PROXY'] unless proxy
    proxy = ENV['http_proxy'] unless proxy
    regex_get_host_port = %r{^https?://(.+):([0-9]+).*$}
    returned_proxy_hash = nil
    if (proxy) && (!proxy.empty?)
      captures = regex_get_host_port.match(proxy).captures
      proxy_host = captures[0]
      proxy_port = captures[1]
      returned_proxy_hash = { host: proxy_host, port: proxy_port }
    end
    # return returned_proxy_hash
  end

  # Downloads remote location into the specified target file
  #
  # @param [String] uri location of the remote resource
  # @param [String] target filename to copy remote content to
  def download(uri, target)
    @logger.debug "Downloading file to #{target}"
    rich_uri = URI(uri)
    if File.exists?(uri)
      FileUtils.cp uri, target
    else
      http_object = Net::HTTP
      # Modfications to use proxy environment variable
      proxy_hash = proxy_from_env
      http_object = Net::HTTP::Proxy(proxy_hash[:host], proxy_hash[:port]) if proxy_hash
      # end
      http_object.start(rich_uri.host, rich_uri.port, use_ssl: rich_uri.scheme == 'https') do |http|
        request = Net::HTTP::Get.new(rich_uri.request_uri)
        http.request request do |response|
          File.open(target, File::CREAT | File::WRONLY) do |file|
            response.read_body do |chunk|
              file.write(chunk)
            end
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
  # @param [Array<String>] cached_hosts list of host names which content should be cached. Collect all remote content by default.
  def collect_configs(config_files = nil, cached_hosts = nil)
    config_files = Dir[File.expand_path(File.join('..', '..', 'config', '*.yml'), __FILE__)] if config_files.nil?
    configs = []
    config_files.each do |file|
      @logger.debug "Checking #{file}"
      begin
        config = YAML.load_file(file)
      rescue => e
        abort "ERROR: Failed loading config #{file}: #{e}"
      end
      if !config.nil? && config.has_key?(REPOSITORY_ROOT) && config.has_key?(VERSION) && (File.exists?(index_path(config)) || cached_hosts.nil? || cached_hosts.include?(URI(config[REPOSITORY_ROOT]).host))
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
