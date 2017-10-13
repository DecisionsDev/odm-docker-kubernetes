#!/bin/sh


if [ ! -f $HOME/.cache/$ICP_CV_FILE_NAME ]; then
    echo "ICP Content Verification: Starting download..."
    AUTH_TOKEN=$(curl -i -H "X-Auth-User: $AUTH_USER" -H "X-Auth-Key:$AUTH_KEY" https://dal05.objectstorage.softlayer.net/auth/v1.0 | grep -E "X-Auth-Token:" | awk {'print $2'})
    curl -O -H "X-Auth-Token: $AUTH_TOKEN" $ICP_CV_URL
    mv $ICP_CV_FILE_NAME $HOME/.cache/
    cd $HOME/.cache
    tar xzvf $ICP_CV_FILE_NAME
    cd -
    echo "ICP Content Verification: download finished..."
else
    echo "ICP Content Verification: Loading from cache..."
    echo "ICP Content Verification: Loading finished..."
fi
