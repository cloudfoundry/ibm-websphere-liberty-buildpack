# IBM WebSphere Application Server Liberty Buildpack
# Copyright IBM Corp. 2013, 2021
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

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new

require 'yard'
puts 'debug yard'
YARD::Rake::YardocTask.new do |t|
  t.options = ['--no-stats']
end

require 'rubocop/rake_task'
puts 'debugging'
RuboCop::RakeTask.new do |t|
  Sickill::Rainbow.enabled = true if ENV.key? 'RAKE_FORCE_COLOR'
  puts 'rubocop end'
end

require 'open3'
task :check_api_doc do
  puts "\nChecking API documentation..."
  output = Open3.capture3('yard stats --list-undoc')[0]
  if output !~ /100.00% documented/
    puts "\nFailed due to undocumented public API:\n\n#{output}"
    exit 1
  else
    puts "\n#{output}\n"
  end
end

require 'rake/clean'
CLEAN.include %w(.yardoc coverage)
CLOBBER.include %w(doc pkg)

task default: [:rubocop, :check_api_doc, :yard, :spec]

desc 'Package buildpack together with admin cache'
task :package, [:zipfile, :hosts, :version] do |t, args|
  source = File.dirname(__FILE__)
  basename = File.basename(source)
  if args.zipfile.nil?
    zipfile = File.expand_path(File.join('..', "#{basename}.zip"), source)
  else
    zipfile = File.expand_path(args.zipfile)
    zipfile << '.zip' unless zipfile.end_with? '.zip'
  end
  puts "Using #{zipfile} as a buildpack zip output file"
  if File.exist? zipfile
    puts 'The output file already exists. Change the output location.'
    exit 1
  end
  if args.hosts.nil?
    cache_hosts = nil
    puts 'Caching all resources'
  else
    cache_hosts = args.hosts.split
    puts "Caching files hosted on #{cache_hosts.join(', ')}"
  end
  require 'tmpdir'
  Dir.mktmpdir do |root|
    $LOAD_PATH.unshift File.expand_path(File.join('..', 'resources'), __FILE__)
    require 'download_buildpack_cache'

    # Copy only the set of source files needed by the buildpack at runtime
    ['bin', 'config', 'doc', 'lib', 'resources', 'LICENSE', 'NOTICE', '.gitignore'].each do |entry|
      file = File.join(source, entry)
      FileUtils.cp_r(file, root) if File.exist? file
    end

    # Copy git files allowing easy retrieval of repository from the remote.
    # These files will allow to run 'git fetch' in the unzipped directory to
    # retrieve the latest version of the repository from the 'origin' remote.
    # After such fetch the files which were not copied will be shown as
    # 'deleted'. They can be retrieved using 'git checkout -- <file/dir name>'.
    git_dst = File.join(root, '.git')
    # git requires '.git/objects' directory to exist
    FileUtils.mkdir_p File.join(git_dst, 'objects')
    %w(config HEAD index).each do |entry|
      file = File.join(source, '.git', entry)
      FileUtils.cp_r(file, git_dst)
    end
    # .git/refs/heads directory contains local branch references
    refs_dst = File.join(git_dst, 'refs')
    FileUtils.mkdir_p refs_dst
    FileUtils.cp_r(File.join(source, '.git', 'refs', 'heads'), refs_dst)

    # Create version.txt if :version was specified
    File.open(File.join(root, 'config', 'version.yml'), 'w') do |file|
      file.puts "version: #{args.version}"
      file.puts "remote: ''"
      file.puts "hash: ''"
    end unless args.version.nil?

    bc = BuildpackCache.new(File.join(root, 'admin_cache'))
    # Collect all remote content using all config files
    configs = bc.collect_configs nil, cache_hosts
    bc.download_cache(configs)
    # Fix file permissions
    system("find #{root} -type f -exec chmod a+r {} \\;")
    system("find #{root} -type d -exec chmod a+rx {} \\;")
    system("chmod a+rx #{root}/bin/*")
    system("cd #{root} && zip -r #{zipfile} .")
  end
end
