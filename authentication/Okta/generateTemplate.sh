#!/bin/bash

export OKTA_CLAIM_GROUPS="groups"
export OKTA_CLAIM_LOGIN="email"
OUTPUT_DIR=./output
TEMPLATE_DIR=./templates

function usage {
  cat <<EOF
Usage: $(basename "$0") [-<option letter> <option value>] [-h]

Options:

-g : Okta ODM Group
-i : Client ID
-n : Okta domain (Okta server name)
-s : API scope
-x : Cient Secret

Usage example: $0 -i OktaclientId -x OktaclientSecret -s odmapiusers -n fr-ibmodmdev.okta.com -g odm-admin"
EOF
}

while getopts "x:i:n:s:g:h" option; do
    case "${option}" in
        g) OKTA_ODM_GROUP=${OPTARG};;
        i) OKTA_CLIENT_ID=${OPTARG};;
        n) OKTA_SERVER_NAME=${OPTARG};;
        s) OKTA_API_SCOPE=${OPTARG};;
        x) OKTA_CLIENT_SECRET=${OPTARG};;
        h) usage; exit 0;;
        *) usage; exit 1;;
    esac
done

if [[ -z ${OKTA_ODM_GROUP} ]]; then
  echo "OKTA_ODM_GROUP has to be provided, either as in environment or with -g."
  exit 1
fi
if [[ -z ${OKTA_CLIENT_ID} ]]; then
  echo "OKTA_CLIENT_ID has to be provided, either as in environment or with -i."
  exit 1
fi
if [[ -z ${OKTA_SERVER_NAME} ]]; then
  echo "OKTA_SERVER_NAME has to be provided, either as in environment or with -n."
  exit 1
fi
if [[ -z ${OKTA_API_SCOPE} ]]; then
  echo "OKTA_API_SCOPE has to be provided, either as in environment or with -s."
  exit 1
fi
if [[ -z ${OKTA_CLIENT_SECRET} ]]; then
  echo "OKTA_CLIENT_SECRET has to be provided, either as in environment or with -x."
  exit 1
fi
if [[ ${OKTA_SERVER_NAME} != "https://.*" ]]; then
  OKTA_SERVER_URL=https://${OKTA_SERVER_NAME}
else
  OKTA_SERVER_URL=${OKTA_SERVER_NAME}
fi

mkdir -p $OUTPUT_DIR && cp $TEMPLATE_DIR/* $OUTPUT_DIR
echo "Generating files for Okta"
sed -i.bak 's|OKTA_API_SCOPE|'$OKTA_API_SCOPE'|g' $OUTPUT_DIR/*
sed -i.bak 's|OKTA_CLIENT_ID|'$OKTA_CLIENT_ID'|g' $OUTPUT_DIR/*
sed -i.bak 's|OKTA_CLIENT_SECRET|'$OKTA_CLIENT_SECRET'|g' $OUTPUT_DIR/*
sed -i.bak 's|OKTA_ODM_GROUP|'$OKTA_ODM_GROUP'|g' $OUTPUT_DIR/*
sed -i.bak 's|OKTA_SERVER_URL|'$OKTA_SERVER_URL'|g' $OUTPUT_DIR/*
# Claim replacement
sed -i.bak 's|OKTA_CLAIM_GROUPS|'$OKTA_CLAIM_GROUPS'|g' $OUTPUT_DIR/*
sed -i.bak 's|OKTA_CLAIM_LOGIN|'$OKTA_CLAIM_LOGIN'|g' $OUTPUT_DIR/*
rm -f $OUTPUT_DIR/*.bak
