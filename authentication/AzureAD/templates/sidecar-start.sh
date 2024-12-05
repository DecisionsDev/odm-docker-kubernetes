#!/bin/bash

while true
do
  echo "synchronize groups and users every minute"
  /tmp/sidecarconf/generate-user-group-mgt.sh -i AZUREAD_CLIENT_ID -x AZUREAD_CLIENT_SECRET -t AZUREAD_TENANT_ID -v
  sleep 60
done
