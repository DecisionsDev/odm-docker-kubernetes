#!/bin/bash

export AZUREAD_CLAIM_GROUPS="groups"
export AZUREAD_CLAIM_LOGIN="loginName"
OUTPUT_DIR=./output
TEMPLATE_DIR=./templates

function usage {
  cat <<EOF
Usage: $(basename "$0") [-<option letter> <option value>] [-h]

Options:

-g : AZUREAD ODM Group ID
-i : Client ID
-n : AZUREAD domain (AZUREAD server name)
-x : Cient Secret

Usage example: $0 -i AzureADClientId -x AzureADClientSecret -n <Application ID (GUID)> -g <GROUP ID (GUID)>"
EOF
}

while getopts "x:i:n:s:g:h" option; do
    case "${option}" in
        g) AZUREAD_ODM_GROUP_ID=${OPTARG};;
        i) AZUREAD_CLIENT_ID=${OPTARG};;
        n) AZUREAD_SERVER_NAME=${OPTARG};;
        x) AZUREAD_CLIENT_SECRET=${OPTARG};;
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
if [[ -z ${AZUREAD_CLIENT_SECRET} ]]; then
  echo "AZUREAD_CLIENT_SECRET has to be provided, either as in environment or with -x."
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
sed -i.bak 's|AZUREAD_CLIENT_SECRET|'$AZUREAD_CLIENT_SECRET'|g' $OUTPUT_DIR/*
sed -i.bak 's|AZUREAD_ODM_GROUP_ID|'$AZUREAD_ODM_GROUP_ID'|g' $OUTPUT_DIR/*
sed -i.bak 's|AZUREAD_SERVER_URL|'$AZUREAD_SERVER_URL'|g' $OUTPUT_DIR/*
# Claim replacement
sed -i.bak 's|AZUREAD_CLAIM_GROUPS|'$AZUREAD_CLAIM_GROUPS'|g' $OUTPUT_DIR/*
sed -i.bak 's|AZUREAD_CLAIM_LOGIN|'$AZUREAD_CLAIM_LOGIN'|g' $OUTPUT_DIR/*
rm -f $OUTPUT_DIR/*.bak
