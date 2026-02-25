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

-u : Cognito User Pool ID
-a : Cognito Domain Name
-r : Region
-i : Application Client ID
-s : Application Cient Secret
-c : Client-Credentials Client ID
-x : Client-Credentials Client Secret
-p : Client-Credentials Default Custom Scope
Usage example: $0 -i OdmClientId -s OdmClientSecret -r Region
EOF
}

while getopts "i:s:r:c:x:p:u:d:ha:" option; do
    case "${option}" in
        u) COGNITO_USER_POOL_ID=${OPTARG};;
        d) COGNITO_DOMAIN_NAME=${OPTARG};;
        r) COGNITO_REGION=${OPTARG};;
        i) COGNITO_APP_CLIENT_ID=${OPTARG};;
        s) COGNITO_APP_CLIENT_SECRET=${OPTARG};;
        c) COGNITO_CC_CLIENT_ID=${OPTARG};;
        x) COGNITO_CC_CLIENT_SECRET=${OPTARG};;
        p) COGNITO_CC_DEFAULT_CUSTOM_SCOPE=${OPTARG};;
        h) usage; exit 0;;
        *) usage; exit 1;;
    esac
done

if [[ -z ${COGNITO_USER_POOL_ID} ]]; then
  echo "COGNITO_USER_POOL_ID has to be provided, either as in environment or with -u."
  exit 1
fi
if [[ -z ${COGNITO_DOMAIN_NAME} ]]; then
  echo "COGNITO_DOMAIN_NAME has to be provided, either as in environment or with -d."
  exit 1
fi
if [[ -z ${COGNITO_REGION} ]]; then
  echo "COGNITO_REGION has to be provided, either as in environment or with -r."
  exit 1
fi
if [[ -z ${COGNITO_APP_CLIENT_ID} ]]; then
  echo "COGNITO_APP_CLIENT_ID has to be provided, either as in environment or with -i."
  exit 1
fi
if [[ -z ${COGNITO_APP_CLIENT_SECRET} ]]; then
  echo "COGNITO_APP_CLIENT_SECRET has to be provided, either as in environment or with -s."
  exit 1
fi
if [[ -z ${COGNITO_CC_CLIENT_ID} ]]; then
  echo "COGNITO_CC_CLIENT_ID has to be provided, either as in environment or with -c."
  exit 1
fi
if [[ -z ${COGNITO_CC_CLIENT_SECRET} ]]; then
  echo "COGNITO_CC_CLIENT_SECRET has to be provided, either as in environment or with -x."
  exit 1
fi
if [[ -z ${COGNITO_CC_DEFAULT_CUSTOM_SCOPE} ]]; then
  echo "COGNITO_CC_DEFAULT_CUSTOM_SCOPE has to be provided, either as in environment or with -p."
  exit 1
fi

mkdir -p $OUTPUT_DIR && cp $TEMPLATE_DIR/* $OUTPUT_DIR
echo "Generating files for COGNITO"
sed -i.bak 's|COGNITO_USER_POOL_ID|'$COGNITO_USER_POOL_ID'|g' $OUTPUT_DIR/*
sed -i.bak 's|COGNITO_DOMAIN_NAME|'$COGNITO_DOMAIN_NAME'|g' $OUTPUT_DIR/*
sed -i.bak 's|COGNITO_REGION|'$COGNITO_REGION'|g' $OUTPUT_DIR/*
sed -i.bak 's|COGNITO_APP_CLIENT_ID|'$COGNITO_APP_CLIENT_ID'|g' $OUTPUT_DIR/*
sed -i.bak 's|COGNITO_APP_CLIENT_SECRET|'$COGNITO_APP_CLIENT_SECRET'|g' $OUTPUT_DIR/*
sed -i.bak 's|COGNITO_CC_CLIENT_ID|'$COGNITO_CC_CLIENT_ID'|g' $OUTPUT_DIR/*
sed -i.bak 's|COGNITO_CC_CLIENT_SECRET|'$COGNITO_CC_CLIENT_SECRET'|g' $OUTPUT_DIR/*
sed -i.bak 's|COGNITO_CC_DEFAULT_CUSTOM_SCOPE|'$COGNITO_CC_DEFAULT_CUSTOM_SCOPE'|g' $OUTPUT_DIR/*
rm -f $OUTPUT_DIR/*.bak
