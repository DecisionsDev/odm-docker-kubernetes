#!/usr/bin/env sh

cat <&0 | yq '(select(.kind == "Deployment") | select(.metadata.name == "*-odm-decisionserverconsole")       | .spec.replicas) = 2' \
        | yq '(select(.kind == "Deployment") | select(.metadata.name == "*-odm-decisionserverconsole")       | .spec.template.spec.automountServiceAccountToken) = true' \
        | yq '(select(.kind == "Service")    | select(.metadata.name == "*-odm-decisionserverconsole")       | .spec.selector.status) = "active"' \
        | yq '(select(.kind == "Service")    | select(.metadata.name == "*-odm-decisionserverconsole-notif") | .spec.selector.status) = "active"'
