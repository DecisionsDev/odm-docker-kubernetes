#!/usr/bin/env sh

cat <&0 > all.yaml

kustomize build . && rm all.yaml
