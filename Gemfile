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

source 'https://rubygems.org'

group :development do
  gem 'rake'
  gem 'redcarpet'
  gem 'rainbow', '~> 2.1.0'
  gem 'rubocop', '0.42.0'
  gem 'yard'
  gem 'e2mmap'
  gem 'thwait'
  gem 'rubocop-rake'
  gem 'core'
  gem 'rspec'
  gem 'solargraph'
  gem 'irb'
end

group :development, :test do
  gem 'rspec'
end

group :test do
  gem 'webmock', '~>3.15.2'
  gem 'simplecov-rcov'
  gem 'ci_reporter'
  gem 'tee'
end
