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
OUTPUT_DIR=./output
TEMPLATE_DIR=./templates

function usage {
  cat <<EOF
Usage: $(basename "$0") [-<option letter> <option value>] [-h]

Options:

-i : Client ID
-n : KEYCLOAK URL (KEYCLOAK server name)
-x : Cient Secret
-r : Realm Name 
-u : UserID claim
Usage example: $0 -i CLIENT_ID -x CLIENT_SECRET -n KEYCLOAK_SERVER_URL [-r REALM_NAME -u USERID_CLAIM]"
EOF
}

while getopts "x:i:n:r:u:h:" option; do
    case "${option}" in
        i) KEYCLOAK_CLIENT_ID=${OPTARG};;
        x) KEYCLOAK_CLIENT_SECRET=${OPTARG};;
        n) KEYCLOAK_SERVER_URL=${OPTARG};;
        r) KEYCLOAK_REALM=${OPTARG};;
        u) KEYCLOAK_USERID_CLAIM=${OPTARG};;
        h) usage; exit 0;;
        *) usage; exit 1;;
    esac
done

if [[ -z ${KEYCLOAK_CLIENT_ID} ]]; then
  echo "CLIENT_ID has to be provided, either as in environment or with -i."
  exit 1
fi
if [[ -z ${KEYCLOAK_SERVER_URL} ]]; then
  echo "SERVER_URL has to be provided, either as in environment or with -n."
  exit 1
fi
if [[ -z ${KEYCLOAK_CLIENT_SECRET} ]]; then
  echo "CLIENT_SECRET has to be provided, either as in environment or with -x."
  exit 1
fi
if [[ -z ${KEYCLOAK_REALM} ]]; then
  echo "REALM not provided, using odm as realm name."
  KEYCLOAK_REALM=odm
fi
if [[ -z ${KEYCLOAK_USERID_CLAIM} ]]; then
  echo "USERID_CLAIM not provided, using preferred_username as user_id claim."
  KEYCLOAK_USERID_CLAIM=preferred_username
fi

mkdir -p $OUTPUT_DIR && cp $TEMPLATE_DIR/* $OUTPUT_DIR
echo "Generating files for KEYCLOAK"
sed -i.bak 's|KEYCLOAK_CLIENT_ID|'$KEYCLOAK_CLIENT_ID'|g' $OUTPUT_DIR/*
sed -i.bak 's|KEYCLOAK_CLIENT_SECRET|'$KEYCLOAK_CLIENT_SECRET'|g' $OUTPUT_DIR/*
sed -i.bak 's|KEYCLOAK_SERVER_URL|'$KEYCLOAK_SERVER_URL'|g' $OUTPUT_DIR/*
sed -i.bak 's|KEYCLOAK_USERID_CLAIM|'$KEYCLOAK_USERID_CLAIM'|g' $OUTPUT_DIR/*
# Claim replacement
ALLOW_DOMAIN=$(echo $KEYCLOAK_SERVER_URL | sed -e "s/\/realms\/$KEYCLOAK_REALM//" -e "s/https:\/\///")
sed -i.bak 's|KEYCLOAK_DOMAIN|'$ALLOW_DOMAIN'|g' $OUTPUT_DIR/*
rm -f $OUTPUT_DIR/*.bak
