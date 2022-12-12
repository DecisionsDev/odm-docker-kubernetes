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
-u : Username 
-p : Password

Usage example: $0 -i AzureADClientId -x AzureADClientSecret -n <Application ID (GUID)> -u <USERNAME> -p <PASSWORD>"
EOF
}

while getopts "x:i:n:s:u:p:h" option; do
    case "${option}" in
        u) USERNAME=${OPTARG};;
        p) PASSWORD=${OPTARG};;
        i) AZUREAD_CLIENT_ID=${OPTARG};;
        n) AZUREAD_SERVER_NAME=${OPTARG};;
        x) AZUREAD_CLIENT_SECRET=${OPTARG};;
        h) usage; exit 0;;
        *) usage; exit 1;;
    esac
done

if [[ -z $USERNAME} ]]; then
  echo "USERNAME has to be provided, either as in environment or with -u."
  exit 1
fi
if [[ -z $PASSWORD} ]]; then
  echo "PASSWORD has to be provided, either as in environment or with -p."
  exit 1
fi
if [[ -z ${AZUREAD_CLIENT_ID} ]]; then
  echo "AZUREAD_CLIENT_ID has to be provided, either as in environment or with -i."
  exit 1
fi
if [[ -z ${AZUREAD_SERVER_NAME} ]]; then
  echo "AZUREAD_SERVER_NAME has to be provided, either as in environment or with -n."
  exit 1
fi
if [[ -z ${AZUREAD_CLIENT_SECRET} ]]; then
  echo "AZUREAD_CLIENT_SECRET has to be provided, either as in environment or with -x."
  exit 1
fi
if [[ ${AZUREAD_SERVER_NAME} != "https://.*" ]]; then
  AZUREAD_SERVER_URL=https://login.microsoftonline.com/${AZUREAD_SERVER_NAME}
else
  AZUREAD_SERVER_URL=${AZUREAD_SERVER_NAME}
fi
echo "Use Authentication URL Server : $AZUREAD_SERVER_URL"
RESULT=$(curl -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "client_id=$AZUREAD_CLIENT_ID&username=myodmusertest@ibmodmdev.onmicrosoft.com&scope=openid&password=My2ODMPassword?1&client_secret=$AZUREAD_CLIENT_SECRET&grant_type=password" \
  "$AZUREAD_SERVER_URL/oauth2/v2.0/token")

echo "Retrieve this Token : $RESULT"
echo "-------------------------------------------"  
echo "Open a browser at this URL : https://jwt.ms"
echo "-------------------------------------------"
echo " Copy paste the id_token : "
echo $RESULT | sed "s/.*id_token\"://g"
echo "====> "
echo " Verify this fields exists in your Token :"
echo " ver = should be 2.0. "
echo " iss = should contains the v2.0 suffix"
echo " email = Should correspond to your email "
echo " groups = List of group for your User."
