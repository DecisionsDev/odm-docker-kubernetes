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
-n : AZUREAD domain (AZUREAD server name)
-x : Cient Secret
-u : AZUREAD_USERNAME
-p : AZUREAD_PASSWORD

Usage example: $0 -i AzureADClientId -x AzureADClientSecret -n <Application ID (GUID)> -u <AZUREAD_USERNAME> -p <AZUREAD_PASSWORD>"
EOF
}

while getopts "x:i:n:s:u:p:h" option; do
    case "${option}" in
        u) AZUREAD_USERNAME=${OPTARG};;
        p) AZUREAD_PASSWORD=${OPTARG};;
        i) AZUREAD_CLIENT_ID=${OPTARG};;
        n) AZUREAD_TENANT_ID=${OPTARG};;
        x) AZUREAD_CLIENT_SECRET=${OPTARG};;
        h) usage; exit 0;;
        *) usage; exit 1;;
    esac
done

if [[ -z ${AZUREAD_USERNAME}} ]]; then
  echo "AZUREAD_USERNAME has to be provided, either as in environment or with -u."
  exit 1
fi
if [[ -z ${AZUREAD_PASSWORD}} ]]; then
  echo "AZUREAD_PASSWORD has to be provided, either as in environment or with -p."
  exit 1
fi
if [[ -z ${AZUREAD_CLIENT_ID} ]]; then
  echo "AZUREAD_CLIENT_ID has to be provided, either as in environment or with -i."
  exit 1
fi
if [[ -z ${AZUREAD_TENANT_ID} ]]; then
  echo "AZUREAD_TENANT_ID has to be provided, either as in environment or with -n."
  exit 1
fi
if [[ -z ${AZUREAD_CLIENT_SECRET} ]]; then
  echo "AZUREAD_CLIENT_SECRET has to be provided, either as in environment or with -x."
  exit 1
fi
if [[ ${AZUREAD_TENANT_ID} != "https://.*" ]]; then
  AZUREAD_SERVER_URL=https://login.microsoftonline.com/${AZUREAD_TENANT_ID}
else
  AZUREAD_SERVER_URL=${AZUREAD_TENANT_ID}
fi
echo "Use Authentication URL Server : $AZUREAD_SERVER_URL"
RESULT=$(curl --silent -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "client_id=${AZUREAD_CLIENT_ID}&username=${AZUREAD_USERNAME}&scope=openid&password=${AZUREAD_PASSWORD}&client_secret=${AZUREAD_CLIENT_SECRET}&grant_type=password" \
  "$AZUREAD_SERVER_URL/oauth2/v2.0/token")

echo "============================================="
echo "1. Open a browser at this URL: https://jwt.ms"
echo "============================================="
echo "2. Copy paste the id_token:"
echo ${RESULT//\}} | sed "s/.*id_token\"://g" |tr -d \"
echo "============================================="
echo "3. Verify this fields exists in your Token :"
echo "   - email = Should correspond to your email "
echo "   - groups = List of group for your User."
echo "   - iss = should contains the v2.0 suffix"
echo "   - ver = should be 2.0. "
