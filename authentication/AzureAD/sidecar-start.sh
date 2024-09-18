#!/bin/bash

while true
do
  echo "synchronize groups and users every minute"
  /tmp/sidecarconf/generate-user-group-mgt.sh -i <CLIENT_ID> -x <CLIENT_SECRET> -t <TENANT_ID> -v
  sleep 60
done
