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
export AZUREAD_CLAIM_GROUPS="groups"
export AZUREAD_CLAIM_LOGIN="loginName"
OUTPUT_DIR=./outputPKeyJWT
TEMPLATE_DIR=./templates_for_privatekeyjwt

function usage {
  cat <<EOF
Usage: $(basename "$0") [-<option letter> <option value>] [-h]

Options:

-g : AZUREAD ODM Group ID
-i : Client ID
-n : AZUREAD domain (AZUREAD server name)
-a : Allow others domains (Optional)
Usage example: $0 -i AzureADClientId -n <Application ID (GUID)> -g <GROUP ID (GUID)> [-a <domain name>]"
EOF
}

while getopts "x:i:n:s:g:ha:" option; do
    case "${option}" in
        g) AZUREAD_ODM_GROUP_ID=${OPTARG};;
        i) AZUREAD_CLIENT_ID=${OPTARG};;
        n) AZUREAD_SERVER_NAME=${OPTARG};;
        a) ALLOW_DOMAIN=${OPTARG};;
        h) usage; exit 0;;
        *) usage; exit 1;;
    esac
done

if [[ -z ${AZUREAD_ODM_GROUP_ID} ]]; then
  echo "AZUREAD_ODM_GROUP_ID has to be provided, either as in environment or with -g."
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

if [[ ${AZUREAD_SERVER_NAME} != "https://.*" ]]; then
  AZUREAD_SERVER_URL=https://login.microsoftonline.com/${AZUREAD_SERVER_NAME}
else
  AZUREAD_SERVER_URL=${AZUREAD_SERVER_NAME}
fi

mkdir -p $OUTPUT_DIR && cp $TEMPLATE_DIR/* $OUTPUT_DIR
echo "Generating files for AZUREAD"
sed -i.bak 's|AZUREAD_CLIENT_ID|'$AZUREAD_CLIENT_ID'|g' $OUTPUT_DIR/*
sed -i.bak 's|AZUREAD_ODM_GROUP_ID|'$AZUREAD_ODM_GROUP_ID'|g' $OUTPUT_DIR/*
sed -i.bak 's|AZUREAD_SERVER_URL|'$AZUREAD_SERVER_URL'|g' $OUTPUT_DIR/*
# Claim replacement
sed -i.bak 's|AZUREAD_CLAIM_GROUPS|'$AZUREAD_CLAIM_GROUPS'|g' $OUTPUT_DIR/*
sed -i.bak 's|AZUREAD_CLAIM_LOGIN|'$AZUREAD_CLAIM_LOGIN'|g' $OUTPUT_DIR/*
if [ ! -z "$ALLOW_DOMAIN" ]; then
  sed -i.bak 's|login.microsoftonline.com|'login.microsoftonline.com,$ALLOW_DOMAIN'|g' $OUTPUT_DIR/*
fi
rm -f $OUTPUT_DIR/*.bak
