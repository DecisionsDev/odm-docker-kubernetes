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
-n : Keycloak Server URL
-x : Cient Secret
-u : Username 
-p : Password

Usage example: $0 -i KeycloakClientId -x KeycloakClientSecret -n KeycloakServerURL -u <USERNAME> -p <PASSWORD>"
EOF
}

while getopts "x:i:n:s:u:p:h" option; do
    case "${option}" in
        u) USERNAME=${OPTARG};;
        p) PASSWORD=${OPTARG};;
        i) KEYCLOAK_CLIENT_ID=${OPTARG};;
        n) KEYCLOAK_SERVER_URL=${OPTARG};;
        x) KEYCLOAK_CLIENT_SECRET=${OPTARG};;
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
if [[ -z ${KEYCLOAK_CLIENT_ID} ]]; then
  echo "KEYCLOAK_CLIENT_ID has to be provided, either as in environment or with -i."
  exit 1
fi
if [[ -z ${KEYCLOAK_SERVER_URL} ]]; then
  echo "KEYCLOAK_SERVER_URL has to be provided, either as in environment or with -n."
  exit 1
fi
if [[ -z ${KEYCLOAK_CLIENT_SECRET} ]]; then
  echo "KEYCLOAK_CLIENT_SECRET has to be provided, either as in environment or with -x."
  exit 1
fi
if [[ -z ${USERNAME} ]]; then
  echo "USERNAME not provided, use johndoe@mycompany.com"
  USERNAME=johndoe@mycompany.com
fi
if [[ -z ${PASSWORD} ]]; then
  echo "PASSWORD not provided, use johndoe"
  PASSWORD=johndoe
fi

RESULT=$(curl -k -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "client_id=$KEYCLOAK_CLIENT_ID&username=$USERNAME&scope=openid&password=$PASSWORD&client_secret=$KEYCLOAK_CLIENT_SECRET&grant_type=password" \
  "$KEYCLOAK_SERVER_URL/protocol/openid-connect/token")

echo "Retrieve this Token : $RESULT curl -k -X POST -H 'Content-Type: application/x-www-form-urlencoded" -d "client_id=$KEYCLOAK_CLIENT_ID&username=$USERNAME&scope=openid&password=$PASSWORD&client_secret=$KEYCLOAK_CLIENT_SECRET&grant_type=password'  '$KEYCLOAK_SERVER_URL/protocol/openid-connect/token'"
echo "-------------------------------------------"  
echo "Open a browser at this URL : https://jwt.io"
echo "-------------------------------------------"
echo " Copy paste the id_token : "
echo $RESULT | sed 's|.*"id_token":*"\([^"]*\)".*|\1|g'
echo "====> "
echo " Verify this fields exists in your Token :"
echo " iss = $KEYCLOAK_SERVER_URL"
echo " preferred_username = $USERNAME "
echo " groups = [\"rtsAdministrators\",\"rtsConfigManagers\",\"rtsInstallers\",\"resAdministrators\",\"resDeployers\",\"resMonitors\",\"resExecutors\"]"
