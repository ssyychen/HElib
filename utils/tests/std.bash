# Copyright (C) 2020 IBM Corp.
# This program is Licensed under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance
# with the License. You may obtain a copy of the License at
#   http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License. See accompanying LICENSE file.

function random-char-string {
  local N=${1:-8}
  echo $(head /dev/urandom | LC_CTYPE=C tr -dc A-Za-z0-9 | head -c $N)
}

diff_threshold="../diff-threshold.py"
generate_data="../gen-data.py"
encode="../../coders/encode.py"
decode="../../coders/decode.py"
create_context="../../build/bin/create-context"
encrypt="../../build/bin/encrypt"
decrypt="../../build/bin/decrypt"
tmp_folder="tmp_$(random-char-string)"
prefix="test"
prefix_bgv="test_bgv"
prefix_bootstrap="test_bootstrap"
prefix_ckks="test_ckks"

sk_file_bgv="${prefix_bgv}.sk"
pk_file_bgv="${prefix_bgv}.pk"
sk_file_ckks="${prefix_ckks}.sk"
pk_file_ckks="${prefix_ckks}.pk"
sk_file_bootstrap="${prefix_bootstrap}.sk"
pk_file_bootstrap="${prefix_bootstrap}.pk"

function assert {
  if "$@"; then 
    return 0
  else
    techo "Output: $output"
    techo "Status: $status"
    return 1
  fi
}

function print-info-location {
  if [ "$DEBUG" == "true" ] || [ "$DEBUG" == "1" ]; then
    # Whitespace after because in `-p` flag mode printout (BATS bug)
    # seems to overwrite test name which then appear afterwards anyway.
    techo "DEBUG info in ${tmp_folder}.                "
  fi
}

function remove-test-directory {
  if [ "$DEBUG" == "true" ] || [ "$DEBUG" == "1" ]; then
    : # Don't delete.
  elif [ -z "$DEBUG" ] || [ "$DEBUG" == "false" ] || [ "$DEBUG" == "0" ]; then
    rm -r $1
  else            
    techo "Teardown: unrecognized value for DEBUG ${DEBUG}, assume false."
    rm -r $1
  fi
}

function check_python36 {
  req_maj=3
  req_min=6
  if which python3 > /dev/null 2>&1; then
    full_ver="$(python3 --version 2>&1 | awk '{ print $2 }')"
    maj="$(echo ${full_ver} | cut -d'.' -f 1)"
    min="$(echo ${full_ver} | cut -d'.' -f 2)"
    patch="$(echo ${full_ver} | cut -d'.' -f 3)"
    if [[ ! ( "${maj}" -eq "${req_maj}" && "${min}" -ge "${req_min}" ) ]]; then
      echo "Required python${req_maj} version ${req_maj}.${req_min}.0 or above.  Found version ${full_ver}"
      exit 1
    fi
  else
    >&2 echo "Cannot find required python${req_maj} version ${req_maj}.${req_min}.0 or above."
    exit 1
  fi
}

function check_locations {
  for prog in "$diff_threshold" "$generate_data" "$encode" "$decode"\
              "$create_context" "$encrypt" "$decrypt"; do
    if [ ! -f "$prog" ]; then
      >&2 echo "${prog} does not exist."
      exit 1
    fi
  done
}

function techo {
  while IFS= read -r line; do
    echo "# $line" >&3
  done <<< "$1"
}

function create-bgv-toy-params {
  rm -f "${prefix_bgv}".params
  touch "${prefix_bgv}".params
  echo "# Generated by bash test" >> "${prefix_bgv}".params
  echo "p=13" >> "${prefix_bgv}".params
  echo "m=7" >> "${prefix_bgv}".params
  echo "r=1" >> "${prefix_bgv}".params
  echo "c=2" >> "${prefix_bgv}".params
  echo "Qbits=10" >> "${prefix_bgv}".params
}

function create-bootstrap-toy-params {
  rm -f "${prefix_bootstrap}".params
  touch "${prefix_bootstrap}".params
  echo "# Generated by bash test" >> "${prefix_bootstrap}".params
  echo "p=17" >> "${prefix_bootstrap}".params
  echo "m=105" >> "${prefix_bootstrap}".params
  echo "r=1" >> "${prefix_bootstrap}".params
  echo "c=2" >> "${prefix_bootstrap}".params
  echo "Qbits=10" >> "${prefix_bootstrap}".params
  echo "c_m=100" >> "${prefix_bootstrap}".params
  echo "mvec=[3 35]" >> "${prefix_bootstrap}".params
  echo "gens=[71 76]" >> "${prefix_bootstrap}".params
  echo "ords=[2 2]" >> "${prefix_bootstrap}".params
}

function create-ckks-toy-params {
  rm -f "${prefix_ckks}".params
  touch "${prefix_ckks}".params
  echo "# Generated by bash test" >> "${prefix_ckks}".params
  echo "p=-1" >> "${prefix_ckks}".params
  echo "m=8" >> "${prefix_ckks}".params
  echo "r=20" >> "${prefix_ckks}".params
  echo "c=2" >> "${prefix_ckks}".params
  echo "Qbits=10" >> "${prefix_ckks}".params
}

function createContext {
  local scheme="$1"
  local src=$2
  local dest=$3
  local boot="$4"
  "$create_context" "$src" -o "$dest" --info-file $boot --scheme "$scheme"
}

function genData {
  local dest=$1
  local nelements=$2
  local scheme=$3
  local columns="$4"
  "${generate_data}" "${nelements}" "$scheme" $columns > "$dest"
}

