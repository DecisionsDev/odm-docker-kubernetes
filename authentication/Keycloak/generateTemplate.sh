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
export KEYCLOAK_USERID="preferred_username"
OUTPUT_DIR=./output
TEMPLATE_DIR=./templates

function usage {
  cat <<EOF
Usage: $(basename "$0") [-<option letter> <option value>] [-h]

Options:

-i : Client ID
-n : KEYCLOAK URL (KEYCLOAK server name)
-x : Cient Secret
-g : ODM Admin Group
-a : Allow others domains (Optional)
Usage example: $0 -i KeycloakClientId -x KeycloakClientSecret [-g <ODM Admin Group> -a <domain name>]"
EOF
}

while getopts "x:i:n:g:ha:" option; do
    case "${option}" in
        i) KEYCLOAK_CLIENT_ID=${OPTARG};;
        n) KEYCLOAK_URL=${OPTARG};;
        x) KEYCLOAK_CLIENT_SECRET=${OPTARG};;
        g) KEYCLOAK_ADMIN_GROUP=${OPTARG};;
        a) ALLOW_DOMAIN=${OPTARG};;
        h) usage; exit 0;;
        *) usage; exit 1;;
    esac
done

if [[ -z ${KEYCLOAK_CLIENT_ID} ]]; then
  echo "KEYCLOAK_CLIENT_ID has to be provided, either as in environment or with -i."
  exit 1
fi
if [[ -z ${KEYCLOAK_URL} ]]; then
  echo "KEYCLOAK_URL has to be provided, either as in environment or with -n."
  exit 1
fi
if [[ -z ${KEYCLOAK_CLIENT_SECRET} ]]; then
  echo "KEYCLOAK_CLIENT_SECRET has to be provided, either as in environment or with -x."
  exit 1
fi

mkdir -p $OUTPUT_DIR && cp $TEMPLATE_DIR/* $OUTPUT_DIR
echo "Generating files for KEYCLOAK"
sed -i.bak 's|KEYCLOAK_CLIENT_ID|'$KEYCLOAK_CLIENT_ID'|g' $OUTPUT_DIR/*
sed -i.bak 's|KEYCLOAK_CLIENT_SECRET|'$KEYCLOAK_CLIENT_SECRET'|g' $OUTPUT_DIR/*
if [ ! -z "$KEYCLOAK_ADMIN_GROUP" ]; then
  sed -i.bak 's|KEYCLOAK_ADMIN_GROUP|'$KEYCLOAK_ADMIN_GROUP'|g' $OUTPUT_DIR/*
else
sed -i.bak 's|KEYCLOAK_ADMIN_GROUP|odm-admin|g' $OUTPUT_DIR/*
fi
sed -i.bak 's|KEYCLOAK_URL|'$KEYCLOAK_URL'|g' $OUTPUT_DIR/*
# Claim replacement
if [ ! -z "$ALLOW_DOMAIN" ]; then
  sed -i.bak 's|KEYCLOAK_DOMAIN|'$ALLOW_DOMAIN'|g' $OUTPUT_DIR/*
else

fi
rm -f $OUTPUT_DIR/*.bak
