#!/usr/bin/env ruby
# Encoding: utf-8

require 'net/http'
require 'uri'
require 'fileutils'
require 'yaml'
require 'logger'

$LOAD_PATH.unshift File.expand_path(File.join('..', '..', 'lib'), __FILE__)
require 'liberty_buildpack/repository/version_resolver'
require 'liberty_buildpack/util/configuration_utils'
require 'liberty_buildpack/util/tokenized_version'
require 'liberty_buildpack/diagnostics/logger_factory'

# Utility class to download remote resources into local cache directory
class BuildpackCache
  COMP_INDEX_PATH = '/component_index.yml'.freeze
  INDEX_PATH = '/index.yml'.freeze
  REPOSITORY_ROOT = 'repository_root'.freeze
  VERSION = 'version'.freeze
  DRIVER = 'driver'.freeze
  URI_KEY = 'uri'.freeze
  LICENSE_KEY = 'license'.freeze
  TYPE_KEY = 'type'.freeze

  # Creates an instance with the specified logger and locale cache destination
  #
  # @param [String] cache_dir cache directory
  # @param [Logger] logger output destination for loggin information. Using STDOUT by default.
  def initialize(cache_dir, logger = nil)
    @cache_dir = cache_dir
    @default_repository_root = default_repository_root
    @logger = logger || LibertyBuildpack::Diagnostics::LoggerFactory.create_logger('.')
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
      if version.nil?
        @logger.warn "No matches found for #{candidate} version in #{index_uri}."
        next
      end
      file_uri = download_license(index[version.to_s], config[TYPE_KEY])
      file = File.join(@cache_dir, filename(file_uri))
      download(file_uri, file)
      # If file is a component_index.yml parse and download files it references as well
      download_components(file_uri, file) if file_uri.end_with? COMP_INDEX_PATH
    end
  end

  def repository_root(config)
    uri = config[REPOSITORY_ROOT]
    uri = uri.gsub(/\{default.repository.root\}/, @default_repository_root)
             .gsub(/\{platform\}/, 'trusty')
             .gsub(/\{architecture\}/, 'x86_64')
             .chomp('/')
    uri
  end

  def index_path(config)
    uri = repository_root(config)
    "#{uri}#{INDEX_PATH}"
  end

  def download_license(file_uri, type)
    if file_uri.is_a? Hash
      license_uri = file_uri[LICENSE_KEY]
      license_file = File.join(@cache_dir, filename(license_uri))
      download(license_uri, license_file)
      file_uri = file_uri[type.nil? ? URI_KEY : type]
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

  def secure?(uri)
    uri.scheme == 'https'
  end

  def proxy(uri)
    proxy_uri = if secure?(uri)
                  URI.parse(ENV['https_proxy'] || ENV['HTTPS_PROXY'] || '')
                else
                  URI.parse(ENV['http_proxy'] || ENV['HTTP_PROXY'] || '')
                end

    @logger.debug { "Proxy: #{proxy_uri.host}, #{proxy_uri.port}, #{proxy_uri.user}, #{proxy_uri.password}" }
    Net::HTTP::Proxy(proxy_uri.host, proxy_uri.port, proxy_uri.user, proxy_uri.password)
  end

  # Downloads remote location into the specified target file
  #
  # @param [String] uri location of the remote resource
  # @param [String] target filename to copy remote content to
  def download(uri, target)
    @logger.debug "Downloading file to #{target}"
    rich_uri = URI(uri)
    if File.exist?(uri)
      FileUtils.cp uri, target
    else
      proxy(rich_uri).start(rich_uri.host, rich_uri.port, use_ssl: secure?(rich_uri)) do |http|
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
    "#{URI.escape(uri, ':/')}.cached"
  end

  # Returns array of config maps containing references to the root index.yml
  # of file sets to be included in the cache.
  #
  # @param [Array<String>] config_files list of config files to check. By default it contains all yml files in buildpack config and service config directories.
  # @param [Array<String>] cached_hosts list of host names which content should be cached. Collect all remote content by default.
  # @param [Array<String>] exclude_files list of YML file names to exclude from collection. Exclude none by default.
  def collect_configs(config_files = nil, cached_hosts = nil, exclude_files = nil)
    if config_files.nil?
      config_files = Dir[File.expand_path(File.join('..', '..', 'config', '*.yml'), __FILE__)]
      config_files.concat(Dir[File.expand_path(File.join('..', '..', 'lib', 'liberty_buildpack', 'services', 'config', '*.yml'), __FILE__)])
    end
    configs = []
    config_files.reject! { |f| exclude_files.include?(File.basename(f)) } unless exclude_files.nil?
    config_files.each do |file|
      @logger.debug "Checking #{file}"
      begin
        config = YAML.load_file(file)
      rescue => e
        abort "ERROR: Failed loading config #{file}: #{e}"
      end
      next if config.nil?
      config = config[DRIVER] || config
      if repository_configuration?(config) && (File.exist?(index_path(config)) || cached_hosts.nil? || cached_hosts.include?(URI(repository_root(config)).host))
        configs.push(config)
      end
    end
    configs
  end

  def repository_configuration?(configuration)
    configuration.key?(VERSION) && configuration.key?(REPOSITORY_ROOT) && !configuration[REPOSITORY_ROOT].empty?
  end

  def default_repository_root
    LibertyBuildpack::Util::ConfigurationUtils.load('repository', true, false)['default_repository_root'].chomp('/')
  end
end

if __FILE__ == $PROGRAM_NAME
  if ARGV.empty?
    puts "Usage: #{File.basename __FILE__} /path/to/cache"
    exit 1
  end

  bc = BuildpackCache.new(File.expand_path(ARGV[0]))
  configs = bc.collect_configs
  bc.download_cache(configs)

end
