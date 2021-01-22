# frozen_string_literal: true

# IBM WebSphere Application Server Liberty Buildpack
# Copyright IBM Corp. 2013
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
require 'liberty_buildpack/util/properties'

module LibertyBuildpack::Util

  describe Properties do

    let(:properties) { Properties.new('spec/fixtures/test.properties') }

    it 'should parse properties' do
      expect(properties['alpha']).to eq('bravo')
      expect(properties['charlie']).to eq('delta')
      expect(properties['echo']).to eq('foxtrot')
      expect(properties['golf']).to eq('')
      expect(properties['Main-Class']).to eq('com.gopivotal.SimpleJava')
      expect(properties['hotel.india']).to eq('-Djuliet=kilo')
      expect(properties['lima']).to eq('-XX:mike="november oscar"')
      expect(properties['poppa']).to eq('quebec')
    end

  end

end
