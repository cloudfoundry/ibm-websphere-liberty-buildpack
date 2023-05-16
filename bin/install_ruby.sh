#!/usr/bin/env bash
# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright IBM Corp. 2023
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


set -e
set -u
set -o pipefail

BUILDPACK_DIR="$(cd "$(dirname "${0}")/.." && pwd)"
readonly BUILDPACK_DIR

RUBY_DIR="/tmp/ruby"
readonly RUBY_DIR

function util::config::lookup() {
  sed '/^#/d' < "${BUILDPACK_DIR}/config/ruby.yml"
}

function util::cache::present() {
  if [[ -e "${BUILDPACK_DIR}/admin_cache" ]]; then
    return 0
  else
    return 1
  fi
}

function util::index::lookup() {
  local repository_root
  repository_root="$(grep "repository_root" <<< "$(util::config::lookup)" | cut -d' ' -f2)"

  local uri
  uri="${repository_root}/index.yml"

  if util::cache::present; then
    cached_file="$(ls ${BUILDPACK_DIR}/admin_cache | grep "ruby-buildpack")"
 	cat "${BUILDPACK_DIR}/admin_cache/$cached_file"
  else
    curl -ssL "${uri}"
  fi
}

function util::semver::parse() {
  local version major minor patch
  version="$(grep "version" <<< "$(util::config::lookup)" | cut -d' ' -f2)"
  major="$(cut -d'.' -f1 <<< "${version}")"
  minor="$(cut -d'.' -f2 <<< "${version}")"
  patch="$(cut -d'.' -f3 <<< "${version}")"

  printf "%s" "${major/+/*}\\.${minor/+/*}\\.${patch/+/*}"
}

function util::dep::isCached () {
  local uri
  uri="${1}"

  local isCached
  isCached=1

  if util::cache::present; then
    file="$(echo "$uri" | cut -d'_' -f6)"

    cached_file="$(ls ${BUILDPACK_DIR}/admin_cache | grep $file)"
 
    if [ -n "$cached_file" ]; then
	  isCached=0
    else
      isCached=1
    fi
  else
    isCached=1
  fi
 
  return $isCached
}

function util::ruby::stream() {
  local uri
  uri="${1}"

  if util::cache::present; then
    file="$(echo "$uri" | cut -d'_' -f6)"
    cached_file="$(ls ${BUILDPACK_DIR}/admin_cache | grep $file)"
    echo "${BUILDPACK_DIR}/admin_cache/$cached_file"
  else
    curl -ssL "${uri}"
  fi
}

function util::install() {
  
  local index semver
  index="$(util::index::lookup)"
  semver="$(util::semver::parse)"

  local uri
  uri="$(grep "${semver}" <<< "${index}" | head -n 1 | awk '{print $2}')"
  
  if util::dep::isCached "${uri}"; then
    file=`util::ruby::stream "${uri}"`
    tar xzf $file -C "${RUBY_DIR}"
  else
    util::ruby::stream "${uri}" | tar xz -C "${RUBY_DIR}"
  fi
}

function util::print::error() {
  local message red reset
  message="${1}"
  red="\033[0;31m"
  reset="\033[0;39m"

  echo -e "${red}${message}${reset}" >&2
  exit 1
}

function main() {

  if [[ ! -e "${RUBY_DIR}" ]]; then

    mkdir -p "${RUBY_DIR}"
    
    util::install
  fi

}

main "${@:-}"
