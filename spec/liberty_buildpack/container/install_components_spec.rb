# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2014 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

require 'spec_helper'
require 'liberty_buildpack/container/install_components'

module LibertyBuildpack::Container

  describe InstallComponents do

    before do
      $stdout = StringIO.new
      $stderr = StringIO.new
    end

    after do
      $stdout = STDOUT
      $stderr = STDERR
    end

    describe 'zip' do

      it 'add zip' do
        install_components = InstallComponents.new

        install_components.add_zip('http://foo/bar')
        install_components.add_zip('https://bar/foo')

        expect(install_components.zips.size).to eq(2)
        expect(install_components.zips[0][0]).to eq('http://foo/bar')
        expect(install_components.zips[0][1]).to be_nil
        expect(install_components.zips[1][0]).to eq('https://bar/foo')
        expect(install_components.zips[1][1]).to be_nil
      end

      it 'add zip with directory' do
        install_components = InstallComponents.new

        install_components.add_zip('http://foo/bar', '.foo')
        install_components.add_zip('https://bar/foo', '.bar')

        expect(install_components.zips.size).to eq(2)
        expect(install_components.zips[0][0]).to eq('http://foo/bar')
        expect(install_components.zips[0][1]).to eq('.foo')
        expect(install_components.zips[1][0]).to eq('https://bar/foo')
        expect(install_components.zips[1][1]).to eq('.bar')
      end

    end

    describe 'esa' do

      it 'add esa' do
        install_components = InstallComponents.new

        install_components.add_esa('http://foo/bar.esa', '--acceptLicense')
        install_components.add_esa('https://bar/foo.esa', '--to=usr')

        expect(install_components.esas.size).to eq(2)
        expect(install_components.esas[0][0]).to eq('http://foo/bar.esa')
        expect(install_components.esas[0][1]).to eq('--acceptLicense')
        expect(install_components.esas[1][0]).to eq('https://bar/foo.esa')
        expect(install_components.esas[1][1]).to eq('--to=usr')
      end

    end

    describe 'esa & zip' do

      it 'add both' do
        install_components = InstallComponents.new

        install_components.add_zip('http://foo/bar')
        install_components.add_zip('https://bar/foo', '.bar')
        install_components.add_esa('http://foo/bar.esa', '--acceptLicense')

        expect(install_components.zips.size).to eq(2)
        expect(install_components.zips[0][0]).to eq('http://foo/bar')
        expect(install_components.zips[0][1]).to be_nil
        expect(install_components.zips[1][0]).to eq('https://bar/foo')
        expect(install_components.zips[1][1]).to eq('.bar')

        expect(install_components.esas.size).to eq(1)
        expect(install_components.esas[0][0]).to eq('http://foo/bar.esa')
        expect(install_components.esas[0][1]).to eq('--acceptLicense')
      end

    end

  end

end
