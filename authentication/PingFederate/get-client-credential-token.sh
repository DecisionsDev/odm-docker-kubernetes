#!/bin/bash
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

function usage {
  cat <<EOF
Usage: $(basename "$0") [-<option letter> <option value>] [-h]

Options:


-i : Client ID
-n : PingFederate Server URL
-x : Cient Secret

Usage example: $0 -i PingFederateClientId -x PingFederateClientSecret -n PingFederateServerURL"
EOF
}

while getopts "x:i:n:s:h" option; do
    case "${option}" in
        i) PingFederate_CLIENT_ID=${OPTARG};;
        n) PingFederate_SERVER_URL=${OPTARG};;
        x) PingFederate_CLIENT_SECRET=${OPTARG};;
        h) usage; exit 0;;
        *) usage; exit 1;;
    esac
done

if [[ -z ${PingFederate_CLIENT_ID} ]]; then
  echo "PingFederate_CLIENT_ID has to be provided, either as in environment or with -i."
  exit 1
fi
if [[ -z ${PingFederate_SERVER_URL} ]]; then
  echo "PingFederate_SERVER_URL has to be provided, either as in environment or with -n."
  exit 1
fi
if [[ -z ${PingFederate_CLIENT_SECRET} ]]; then
  echo "PingFederate_CLIENT_SECRET has to be provided, either as in environment or with -x."
  exit 1
fi

RESULT=$(curl -k -X POST -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$PingFederate_CLIENT_ID&scope=odm_cc&client_secret=$PingFederate_CLIENT_SECRET&grant_type=client_credentials" \
  "$PingFederate_SERVER_URL/token")


echo "Retrieve this Token : $RESULT"
echo "-------------------------------------------"  
echo "Open a browser at this URL : https://jwt.io"
echo "-------------------------------------------"
echo " Copy paste the id_token : "
echo $RESULT | sed 's|.*"access_token":*"\([^"]*\)".*|\1|g'
echo "====> "
echo " Verify this field exists in your Token :"
echo " identity = <CLIENT_ID> "
