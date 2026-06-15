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
-x : Cient Secret
-n : PING_FEDERATE URL (PING_FEDERATE server name)
Usage example: $0 -i CLIENT_ID -x CLIENT_SECRET -n PING_FEDERATE_SERVER_URL"
EOF
}

while getopts "x:i:n:h:" option; do
    case "${option}" in
        i) PING_FEDERATE_CLIENT_ID=${OPTARG};;
        x) PING_FEDERATE_CLIENT_SECRET=${OPTARG};;
        n) PING_FEDERATE_SERVER_URL=${OPTARG};;
        h) usage; exit 0;;
        *) usage; exit 1;;
    esac
done

if [[ -z ${PING_FEDERATE_CLIENT_ID} ]]; then
  echo "CLIENT_ID has to be provided, either as in environment or with -i."
  exit 1
fi
if [[ -z ${PING_FEDERATE_SERVER_URL} ]]; then
  echo "SERVER_URL has to be provided, either as in environment or with -n."
  exit 1
fi
if [[ -z ${PING_FEDERATE_CLIENT_SECRET} ]]; then
  echo "CLIENT_SECRET has to be provided, either as in environment or with -x."
  exit 1
fi


mkdir -p $OUTPUT_DIR && cp $TEMPLATE_DIR/* $OUTPUT_DIR
echo "Generating files for PING_FEDERATE"
sed -i.bak 's|PING_FEDERATE_CLIENT_ID|'$PING_FEDERATE_CLIENT_ID'|g' $OUTPUT_DIR/*
sed -i.bak 's|PING_FEDERATE_CLIENT_SECRET|'$PING_FEDERATE_CLIENT_SECRET'|g' $OUTPUT_DIR/*
sed -i.bak 's|PING_FEDERATE_SERVER_URL|'$PING_FEDERATE_SERVER_URL'|g' $OUTPUT_DIR/*
# Claim replacement
ALLOW_DOMAIN=$(echo $PING_FEDERATE_SERVER_URL | sed -e "s/\/realms\/$PING_FEDERATE_REALM//" -e "s/https:\/\///")
sed -i.bak 's|PING_FEDERATE_DOMAIN|'$ALLOW_DOMAIN'|g' $OUTPUT_DIR/*
rm -f $OUTPUT_DIR/*.bak
