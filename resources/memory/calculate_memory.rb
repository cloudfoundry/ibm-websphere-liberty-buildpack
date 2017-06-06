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

require_relative 'memory_limit'
require_relative 'memory_size'
require_relative 'openjdk_memory_heuristic_factory'
require 'json'

def heap_size
  mem_limit = MemoryLimit.memory_limit
  heap_size_ratio = File.read('.memory_config/heap_size_ratio_config')
  if valid_float?(heap_size_ratio)
    heap_size_ratio = heap_size_ratio.to_f
  else
    puts "'#{heap_size_ratio}' is not a valid heap size ratio setting, using default value."
    heap_size_ratio = Float(0.75)
  end

  if mem_limit < MemorySize.new('512M')
    low_mem_heap_size_ratio = Float(0.5)
    unless heap_size_ratio != Float(0.75)
      heap_size_ratio = low_mem_heap_size_ratio
    end
  end
  new_heap_size = mem_limit * heap_size_ratio
  new_heap_size
end

def valid_float?(str)
  true if Float(str) rescue false # rubocop:disable Style/RescueModifier
end

def java_opts_file
  server_name = File.read('.memory_config/server_name_information')
  "/home/vcap/app/wlp/usr/servers/#{server_name}/jvm.options"
end

def set_ibmjdk_config
  if File.readlines(java_opts_file).grep(/-Xmx/).size > 0
    puts 'User already set max heap size (-Xmx)'
  else
    calculated_heap_size = heap_size
    puts "Setting JDK heap to: -Xmx#{calculated_heap_size}"
    File.open(java_opts_file, 'a') do |file|
      file.puts "-Xmx#{calculated_heap_size}"
    end
  end
end

def set_openjdk_config
  if File.readlines(java_opts_file).grep(/-Xmx/).size > 0
    puts 'User already set max heap size (-Xmx)'
  else
    puts 'Setting openJDK memory configuration'
    File.open(java_opts_file, 'a') do |file|
      file.puts OpenJDKMemoryHeuristicFactory.create_memory_heuristic(sizes, heuristics, openjdk_version).resolve
    end
  end
end

def sizes
  memory_sizes = File.read('.memory_config/sizes')
  JSON.parse memory_sizes.gsub('=>', ':')
end

def heuristics
  memory_heuristics = File.read('.memory_config/heuristics')
  JSON.parse memory_heuristics.gsub('=>', ':')
end

def openjdk_version
  if File.readlines('.memory_config/heuristics').grep(/metaspace/).size > 0
    '1.8.0'
  else
    '1.7.1'
  end
end

def ibm_jdk?
  File.file?('.memory_config/heap_size_ratio_config')
end

if ibm_jdk?
  set_ibmjdk_config
else
  set_openjdk_config
end
