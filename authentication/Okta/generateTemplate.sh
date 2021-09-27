#!/bin/bash

export OKTA_CLAIM_GROUPS="groups"
export OKTA_CLAIM_LOGIN="loginName"
OUTPUT_DIR=./output
TEMPLATE_DIR=./templates
function usage {
    print "$0 Available options:"
    print " -x : Cient Secret"
    print " -i : Client ID"
    print " -s : Okta Server URL"
    print " -g : Okta ODM Group"
    print " "
    print "Usage example : $0 -i qqdfqg -x qsdfqsdfqf -s https://fr-ibmodmdev.okta.com -g odm-user"
}
while getopts "x:i:s:g:h" option 
do
    case "${option}" in
        x)
            OKTA_CLIENT_SECRET=${OPTARG}
            ;;
        i)
            OKTA_CLIENT_ID=${OPTARG}
            ;;
        s)
            OKTA_SERVER_URL=${OPTARG}
            ;;
        g)
            OKTA_ODM_GROUP=${OPTARG}
            ;;
        h)
            usage
            exit 0
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done


mkdir -p $OUTPUT_DIR && cp $TEMPLATE_DIR/* $OUTPUT_DIR
echo "Generating files for Okta"
sed -i ''  's|OKTA_SERVER_URL|'$OKTA_SERVER_URL'|g' $OUTPUT_DIR/*.*
sed -i ''  's|OKTA_CLIENT_SECRET|'$OKTA_CLIENT_SECRET'|g' $OUTPUT_DIR/*.*
sed -i ''  's|OKTA_CLIENT_ID|'$OKTA_CLIENT_ID'|g' $OUTPUT_DIR/*.*
sed -i ''  's|OKTA_ODM_GROUP|'$OKTA_ODM_GROUP'|g' $OUTPUT_DIR/*.*
# Claim replacement
sed -i ''  's|OKTA_CLAIM_GROUPS|'$OKTA_CLAIM_GROUPS'|g' $OUTPUT_DIR/*.*
sed -i ''  's|OKTA_CLAIM_LOGIN|'$OKTA_CLAIM_LOGIN'|g' $OUTPUT_DIR/*.*
