#!/bin/bash
# leader-election.sh - Leader election sidecar

set -e

# Configuration (Note that the environment variables are not defined by default and the default values are used)
LEASE_NAME="${LEASE_NAME:-decisionserverconsole-lease}"
LEASE_DURATION="${LEASE_DURATION:-15}"                      # in seconds
RENEW_INTERVAL="${RENEW_INTERVAL:-5}"                       # in seconds
LOG_BUFFERING_INTERVAL="${LOG_BUFFERING_INTERVAL:-900}"     # in seconds
STATUS_FILE="${STATUS_FILE:-/tmp/leader-status}"
HEARTBEAT_FILE="/tmp/heartbeat"

# optionally specify credentials to connect to the RES console in order to update the list of ruleapps & rulesets when a pod becomes active (and was inactive previously)
RESMONITOR_USER="resMonitor"    # change with your actual credentials
RESMONITOR_PWD="odmAdmin"       # or leave it empty to disable the update

# Configuration from injected parameters
NAMESPACE=$(cat /run/secrets/kubernetes.io/serviceaccount/namespace)
TOKEN=$(cat /run/secrets/kubernetes.io/serviceaccount/token)


# Validate required variables
if [ -z "$HOSTNAME" ]; then
    echo "ERROR: HOSTNAME environment variable not set"
    exit 1
fi
POD_NAME="${HOSTNAME}"

# Track current leadership status
IS_LEADER=""

# log buffering
LAST_MSG=""
BUFFERING_IDENTICAL_LOG_MSG=false
declare -i IDENTICAL_MSG_COUNT=0
declare -i MSG_BUFFERED_COUNT=0
declare -i LAST_FLUSH_EPOCH=0
log() {
    local msg=$1
    local now_epoch=$(date +%s)
    touch ${HEARTBEAT_FILE} # useful for the liveness probe

    if ${BUFFERING_IDENTICAL_LOG_MSG}; then
        local seconds_since_last_flush=$((${now_epoch} - ${LAST_FLUSH_EPOCH}))

        if [[ "${msg}" != "${LAST_MSG}" ]]; then
            if [ ${MSG_BUFFERED_COUNT} -gt 0 ]; then
                echo "$(date "+%D %T") ${LAST_MSG} (msg issued ${MSG_BUFFERED_COUNT} times in the last $((${seconds_since_last_flush} / 60)) minutes)"
            fi
            echo "$(date "+%D %T") ${msg}"
            LAST_MSG=${msg}

            # no longer in buffering mode
            BUFFERING_IDENTICAL_LOG_MSG=false
            IDENTICAL_MSG_COUNT=1
        else
            MSG_BUFFERED_COUNT+=1

            if [[ ${seconds_since_last_flush} -gt ${LOG_BUFFERING_INTERVAL} ]]; then
                echo "$(date "+%D %T") ${msg} (msg issued ${MSG_BUFFERED_COUNT} times in the last $((${seconds_since_last_flush} / 60)) minutes)"
                LAST_FLUSH_EPOCH=${now_epoch}
                MSG_BUFFERED_COUNT=0
            fi
        fi

    else # not buffering
        if [[ "${msg}" = "${LAST_MSG}" ]]; then
            IDENTICAL_MSG_COUNT+=1
            if [ ${IDENTICAL_MSG_COUNT} -eq 5 ]; then
                echo "$(date "+%D %T") ${msg}. Starting buffering identical messages (will issue one msg every $((${LOG_BUFFERING_INTERVAL} / 60)) minutes)."
                BUFFERING_IDENTICAL_LOG_MSG=true
                LAST_FLUSH_EPOCH=${now_epoch}
                MSG_BUFFERED_COUNT=0
            else
                echo "$(date "+%D %T") ${msg}"
            fi
        else
            echo "$(date "+%D %T") ${msg}"
            IDENTICAL_MSG_COUNT=1
            LAST_MSG=${msg}
        fi
    fi
}

# Function to get current time in RFC3339 format
get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%S.%6NZ"
}

# Function to get lease holder
get_lease() {
    RESULT=$(curl https://${KUBERNETES_SERVICE_HOST}:443/apis/coordination.k8s.io/v1/namespaces/${NAMESPACE}/leases/${LEASE_NAME} --header "Authorization: Bearer ${TOKEN}" --header "content-type: application/merge-patch+json" --insecure 2>/dev/null)
    echo "${RESULT}"
}

# Function to check if lease exists
lease_exists() {
    if [ "$(echo "$@" | jq -r '.code')" = "404" ]; then
        return 1    # does not exist
    else
        return 0    # exists
    fi
}

# Function to get lease holder
get_lease_holder() {
    echo "$@" | jq -r '.spec.holderIdentity'
}

# Function to get lease renew time
get_lease_renew_time() {
    echo "$@" | jq -r '.spec.renewTime'
}

# Function to check if lease is expired
is_lease_expired() {
    local renew_time=$(get_lease_renew_time "$@")
    
    if [ "$renew_time" = "null" ]; then
        return 0  # No renew time means expired
    fi
    
    # Convert times to epoch seconds for comparison
    local renew_epoch=$(date -d "$renew_time" +%s 2>/dev/null || echo 0)
    local now_epoch=$(date +%s)
    local expiry_epoch=$((renew_epoch + LEASE_DURATION))
    
    if [ $now_epoch -gt $expiry_epoch ]; then
        return 0  # Expired
    else
        return 1  # Not expired
    fi
}

# Function to create lease
create_lease() {
    RESULT=$(curl -X POST https://${KUBERNETES_SERVICE_HOST}:443/apis/coordination.k8s.io/v1/namespaces/${NAMESPACE}/leases \
                  -H "Authorization: Bearer $TOKEN" \
                  -H "Content-Type: application/json" \
                  -d "$(cat <<EOF
                      {
                          "apiVersion": "coordination.k8s.io/v1",
                          "kind": "Lease",
                          "metadata": {
                              "name": "$LEASE_NAME",
                              "namespace": "$NAMESPACE"
                          },
                          "spec": {
                              "holderIdentity": "$POD_NAME",
                              "leaseDurationSeconds": $LEASE_DURATION,
                              "renewTime": "$(get_timestamp)"
                          }
                      }
EOF
)" --insecure 2>/dev/null)

    if [[ "$?" -ne 0 || "$(echo $RESULT |jq -r '.status')" = "Failure" ]]; then
        return 1
    else
        return 0
    fi
}

# Function to update lease (renew or acquire)
update_lease() {
    RESULT=$(curl -X PATCH https://${KUBERNETES_SERVICE_HOST}:443/apis/coordination.k8s.io/v1/namespaces/${NAMESPACE}/leases/${LEASE_NAME} \
         -H "Authorization: Bearer $TOKEN" \
         -H "Content-Type: application/merge-patch+json" \
         -d "$(cat <<EOF
            {
                "spec": {
                    "holderIdentity": "$POD_NAME",
                    "renewTime": "$(get_timestamp)"
                }
            }
EOF
)" --insecure 2>/dev/null)

    if [[ "$?" -ne 0 || "$(echo $RESULT |jq -r '.status')" = "Failure" ]]; then
        return 1
    else
        return 0
    fi
}

# Function to check if the main container is ready
is_container_ready() {

    if [ "${CONTAINER_READY}" = "true" ]; then
        return 0
    elif [ "${CONTAINER_READY}" = "false" ]; then
        return 1
    fi

    RESULT=$(curl -X GET https://${KUBERNETES_SERVICE_HOST}:443/api/v1/namespaces/${NAMESPACE}/pods/${POD_NAME} \
                  -H "Authorization: Bearer $TOKEN" \
                  --insecure 2>/dev/null)

    if [[ "$?" -ne 0 || "$(echo $RESULT |jq -r '.status')" = "Failure" ]]; then
        log "Failed to check if the pod is ready: ${RESULT}"
        return 1
    elif [[ "$(echo $RESULT |jq -r '.status.containerStatuses[0].ready')" = "true" ]]; then
        CONTAINER_READY=true
        return 0
    else
        CONTAINER_READY=false
        return 1
    fi
}

# Function to update leader status
update_status() {
    local new_status=$1
    local label_status
    
    if [ "$IS_LEADER" != "$new_status" ]; then

        if [ "$new_status" = "true" ]; then
            label_status='active'
            log ">>> THIS POD IS NOW THE ACTIVE LEADER <<<"
            echo "active" > "$STATUS_FILE"
        else
            label_status='inactive'
            log ">>> This pod is now inactive (standby) <<<"
            echo "inactive" > "$STATUS_FILE"
        fi

        # if the pod is switching from inactive to active, let's update the list of ruleapps/rulesets if credentials are provided
        if [[ "${new_status}" = "true" && "${IS_LEADER}" != "" && -n "${RESMONITOR_USER}" && -n "${RESMONITOR_PWD}" ]]; then
            # call the REST API endpoint that returns all the ruleapps and rulesets, which updates the RES console as a side effect
            RESPONSE_CODE=$(curl https://127.0.0.1:9443/res/api/v1/ruleapps -u "${RESMONITOR_USER}:${RESMONITOR_PWD}" --insecure -o /dev/null -s -w '%{http_code}')
            if [[ "${RESPONSE_CODE}" = "200" ]]; then
                log "Updated the list of ruleapps/rulesets in the RES console"
            else
                log "Failed to update the list of ruleapps/rulesets in the RES console: received ${RESPONSE_CODE} HTTP code"
            fi
        fi

        IS_LEADER=${new_status}

        RESULT=$(curl -X PATCH https://${KUBERNETES_SERVICE_HOST}:443/api/v1/namespaces/${NAMESPACE}/pods/${POD_NAME} \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json-patch+json" \
            -d "$(cat <<EOF
                [
                    {
                        "op": "replace",
                        "path": "/metadata/labels/status",
                        "value": "$label_status"
                    }
                ]
EOF
)" --insecure 2>/dev/null)

        if [[ "$?" -ne 0 || "$(echo $RESULT |jq -r '.status')" = "Failure" ]]; then
            log "Failed to set the 'status' label of the pod to '$label_status': ${RESULT}"
            return 1
        else
            log "Set the 'status' label of the pod to '$label_status'"
            return 0
        fi
    fi
}

# Function to attempt acquiring or renewing leadership
try_acquire_leadership() {

    local lease="$(get_lease)"
    CONTAINER_READY="unknown"

    if ! $(lease_exists ${lease}); then
        if ! is_container_ready; then
            log "the main container is not ready"
            return 1
        else
            if create_lease; then
                log "Successfully acquired leadership (created new lease)"
                update_status true
                return 0
            else
                log "Failed to create lease: ${RESULT}"
                update_status false
                return 1
            fi
        fi
    fi
    
    # Lease exists, check who holds it
    local current_holder=$(get_lease_holder ${lease})
    if [ "$current_holder" = "$POD_NAME" ]; then # we are the leader

        if ! is_container_ready; then
            # let's keep the ownership until the lease expires (do not call update_status)
            log "the main container is not ready"
            return 1
        else
            # renew the lease ownership
            if update_lease; then
                log "Successfully renewed leadership"
                update_status true
                return 0
            else
                log "Failed to renew lease: ${RESULT}"
                update_status false
                return 1
            fi
        fi

    else # Someone else is the leader

        if ! $(is_lease_expired ${lease}); then
            log "Lease is held by $current_holder (not expired)"
            update_status false
            return 1
        else
            if ! is_container_ready; then
                # the lease is expired but we cannot take the ownership because the container is not ready
                log "the main container is not ready"
                # let's call update_status in case we used to be the leader to remove the label status=active
                update_status false
                return 1
            else
                log "Lease held by $current_holder has expired, attempting to acquire"
                if update_lease; then
                    log "Successfully acquired leadership from expired lease"
                    update_status true
                    return 0
                else
                    log "Failed to acquire expired lease: ${RESULT}"
                    update_status false
                    return 1
                fi
            fi
        fi
    fi
}

# Function to release lease on shutdown
release_lease() {
    log "Shutting down, releasing lease..."

    local lease=$(get_lease)
    local current_holder=$(get_lease_holder ${lease})

    if [ "$current_holder" = "$POD_NAME" ]; then
        RESULT=$(curl -X DELETE https://${KUBERNETES_SERVICE_HOST}:443/apis/coordination.k8s.io/v1/namespaces/${NAMESPACE}/leases/${LEASE_NAME} \
                      -H "Authorization: Bearer $TOKEN" \
                      --insecure 2>/dev/null)

        if [ "$(echo $RESULT |jq -r '.status')" = "Success" ]; then
            log "Successfully released leadership lease"
        else
            log "Failed to release leadership lease: ${RESULT}"
        fi
    fi
    
    exit 0
}

# Set up signal handlers for graceful shutdown
trap release_lease SIGTERM SIGINT

# Main loop - try to acquire/renew leadership periodically
log "Starting leader election for pod: $POD_NAME in namespace: $NAMESPACE (Lease name: $LEASE_NAME) - checking every ${RENEW_INTERVAL}s..."

while true; do
    if try_acquire_leadership; then
        # sleep for 5s
        sleep ${RENEW_INTERVAL}
    else
        # sleep for 5 to 10s
        sleep $(shuf -i ${RENEW_INTERVAL}-$((${RENEW_INTERVAL} * 2)) -n 1)
    fi
done
