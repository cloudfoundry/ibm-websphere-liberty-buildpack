#!/usr/bin/env ruby
# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2013-2017 the original author or authors.
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

require_relative 'memory_size'

def memory_limit
  memory_limit = ENV['MEMORY_LIMIT']
  memory_limit_size = MemorySize.new(memory_limit)
  raise "Invalid negative $MEMORY_LIMIT #{memory_limit}" if memory_limit_size < 0
  memory_limit_size
end

def heap_size
  heap_size_ratio = File.read('.memory_config/heap_size_ratio_config')
  new_heap_size = memory_limit * heap_size_ratio.to_f
  new_heap_size
end

def java_opts_file
  server_name = File.read('.memory_config/server_name_information')
  "/home/vcap/app/wlp/usr/servers/#{server_name}/jvm.options"
end

def set_memory_config
  if File.readlines(java_opts_file).grep(/-Xmx/).size > 0
    puts 'User already set max heap size (-Xmx)'
  else
    puts "Setting JDK heap to: -Xmx#{heap_size}"
    File.open(java_opts_file, 'a') do |file|
      file.puts "-Xmx#{heap_size}"
    end
  end
end

set_memory_config
