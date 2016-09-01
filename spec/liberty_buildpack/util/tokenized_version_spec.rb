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
require 'liberty_buildpack/util/tokenized_version'

module LibertyBuildpack::Util
  describe TokenizedVersion do
    it 'defaults to a wildcard if no version is supplied' do
      expect(TokenizedVersion.new(nil)).to eq(TokenizedVersion.new('+'))
    end

    it 'should order major versions correctly' do
      expect(TokenizedVersion.new('3.0.0')).to be > TokenizedVersion.new('2.0.0')
      expect(TokenizedVersion.new('10.0.0')).to be > TokenizedVersion.new('2.0.0')
    end

    it 'should order minor versions correctly' do
      expect(TokenizedVersion.new('0.3.0')).to be > TokenizedVersion.new('0.2.0')
      expect(TokenizedVersion.new('0.10.0')).to be > TokenizedVersion.new('0.2.0')
    end

    it 'should order micro versions correctly' do
      expect(TokenizedVersion.new('0.0.3')).to be > TokenizedVersion.new('0.0.2')
      expect(TokenizedVersion.new('0.0.10')).to be > TokenizedVersion.new('0.0.2')
    end

    it 'should order qualifiers correctly' do
      expect(TokenizedVersion.new('1.7.0_28a')).to be > TokenizedVersion.new('1.7.0_28')
    end

    it 'should accept a qualifier with embedded periods and hyphens' do
      TokenizedVersion.new('0.5.0_BUILD-20120731.141622-16')
    end

    it 'should raise an exception when the major version is not numeric' do
      expect { TokenizedVersion.new('A') }.to raise_error(/Invalid/)
    end

    it 'should raise an exception when the minor version is not numeric' do
      expect { TokenizedVersion.new('1.A') }.to raise_error(/Invalid/)
      expect { TokenizedVersion.new('1..0') }.to raise_error(/Invalid/)
    end

    it 'should raise an exception when the micro version is not numeric' do
      expect { TokenizedVersion.new('1.6.A') }.to raise_error(/Invalid/)
      expect { TokenizedVersion.new('1.6..') }.to raise_error(/Invalid/)
      expect { TokenizedVersion.new('1.6._0') }.to raise_error(/Invalid/)
      expect { TokenizedVersion.new('1.6_26') }.to raise_error(/Invalid/)
    end

    it 'should raise an exception when micro version is missing' do
      expect { TokenizedVersion.new('1.6') }.to raise_error(/Invalid/)
    end

    it 'should raise an exception when major version is not legal' do
      expect { TokenizedVersion.new('1+') }.to raise_error(/Invalid/)
    end

    it 'should raise an exception when minor version is not legal' do
      expect { TokenizedVersion.new('1.6+') }.to raise_error(/Invalid/)
    end

    it 'should raise an exception when micro version is not legal' do
      expect { TokenizedVersion.new('1.6.0+') }.to raise_error(/Invalid/)
    end

    it 'should raise an exception when qualifier version is not legal' do
      expect { TokenizedVersion.new('1.6.0_05+') }.to raise_error(/Invalid/)
    end

    it 'should raise an exception when the qualifier is not letter, number, or hyphen' do
      expect { TokenizedVersion.new('1.6.0_?') }.to raise_error(/Invalid/)
      expect { TokenizedVersion.new('1.6.0__5') }.to raise_error(/Invalid/)
      expect { TokenizedVersion.new('1.6.0_A.') }.to raise_error(/Invalid/)
    end

    it 'should raise an exception when a major version wildcard is followed by anything' do
      expect { TokenizedVersion.new('+.6.0_26') }.to raise_error(/Invalid/)
    end

    it 'should raise an exception when a minor version wildcard is followed by anything' do
      expect { TokenizedVersion.new('1.+.0_26') }.to raise_error(/Invalid/)
    end

    it 'should raise an exception when a micro version wildcard is followed by anything' do
      expect { TokenizedVersion.new('1.6.+_26') }.to raise_error(/Invalid/)
    end

    it 'should raise an exception when too many components are specified' do
      expect { TokenizedVersion.new('1.6.0.25') }.to raise_error(/Invalid/)
      expect { TokenizedVersion.new('1.6.0.25_27') }.to raise_error(/Invalid/)
    end

    it 'should raise an exception when not enough components are specified' do
      expect { TokenizedVersion.new('_25') }.to raise_error(/Invalid/)
    end

    it 'should raise an exception when a wildcard is specified but should not be' do
      expect { TokenizedVersion.new('+', false) }.to raise_error(/Invalid/)
      expect { TokenizedVersion.new('1.+', false) }.to raise_error(/Invalid/)
      expect { TokenizedVersion.new('1.1.+', false) }.to raise_error(/Invalid/)
      expect { TokenizedVersion.new('1.1.1_+', false) }.to raise_error(/Invalid/)
    end

    it 'should raise an exception when a version ends with a component separator' do
      expect { TokenizedVersion.new('1.') }.to raise_error(/Invalid/)
      expect { TokenizedVersion.new('1.7.') }.to raise_error(/Invalid/)
      expect { TokenizedVersion.new('1.7.0_') }.to raise_error(/Invalid/)
    end
  end
end
