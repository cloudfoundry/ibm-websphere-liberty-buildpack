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

require 'spec_helper'
require 'liberty_buildpack/util/format_duration'

describe 'format duration' do

  it 'should display seconds' do
    expect_time_string '0.0s', MILLISECOND
    expect_time_string '0.1s', TENTH
    expect_time_string '1.0s', SECOND
    expect_time_string '1.1s', SECOND + TENTH
    expect_time_string '1.1s', SECOND + TENTH + MILLISECOND
  end

  it 'should display minutes' do
    expect_time_string '1m 0s', MINUTE
    expect_time_string '1m 1s', MINUTE + SECOND
    expect_time_string '1m 1s', MINUTE + SECOND + TENTH
    expect_time_string '1m 1s', MINUTE + SECOND + TENTH + MILLISECOND
  end

  it 'should display hours' do
    expect_time_string '1h 0m', HOUR
    expect_time_string '1h 1m', HOUR + MINUTE
    expect_time_string '1h 1m', HOUR + MINUTE + SECOND
    expect_time_string '1h 1m', HOUR + MINUTE + SECOND + TENTH
    expect_time_string '1h 1m', HOUR + MINUTE + SECOND + TENTH + MILLISECOND
  end

  private

  MILLISECOND = 0.001

  TENTH = 100 * MILLISECOND

  SECOND = 10 * TENTH

  MINUTE = 60 * SECOND

  HOUR = 60 * MINUTE

  def expect_time_string(expected, time)
    expect(time.duration).to eq(expected)
  end

end
