#!/usr/bin/env bash
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

set -o errexit
set -o pipefail
set -o nounset

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"

LDAP_CONFIGURATIONS_FILE="ldap-configurations.xml"
VERBOSE=false
INTERACTIVE_MODE=false
FOUND_LDAP_CONFIG=false
FOUND_WEBSECURITY=false
FOUND_TLS_SECURITY=false
USE_CURRENT_NAMESPACE=true
NAMESPACE=$(kubectl config view --minify -o jsonpath='{..namespace}')
PARAMS_FILE=""
declare -A LDAP_HOSTNAME
declare -A LDAP_PORT
declare -A LDAP_SSL
declare -A LDAP_BASE
declare -A LDAP_ADMIN_USERNAME
declare -A LDAP_ADMIN_PWD
declare -A LDAP_FILTER

usage() {
  echo "Usage: ${__base} [options]"
  echo "Options (optional):"
  echo "  -f, --propertiesFilePath <FILE>   Run ldapsearch without interaction using the parameters in this file"
  echo "  -i, --interactive                 Run ldapsearch in interactive mode"
  echo "  -n, --namespace     <NAMESPACE>   Namespace where ODM is installed"
  echo "  -v, --verbose                     Enable verbose output"
  echo "  -d, --debug                       Enable debug traces"
  echo "  -h, --help                        Show this help message and exit"
  exit 1
}

trace() {
    if [ "${VERBOSE}" = "true" ]; then 
        echo "$1"
    fi
}

get_xml_element() {
    local DATA="${1}"
    local START="<${2}>"
    local END="</${2}>"
    local BEGINNING_TRIMMED=${DATA##*${START}}
    local END_TRIMMED=${BEGINNING_TRIMMED%%${END}*}
    echo "${END_TRIMMED}"
}
get_xml_element_with_properties() {
    local DATA="${1}"
    local START="<${2}"
    local END="</${2}>"
    local END_2="/>"
    local BEGINNING_TRIMMED=${DATA##*${START}}
    local END_TRIMMED=${BEGINNING_TRIMMED%%${END}*}
    if [ "${END_TRIMMED}" = "${BEGINNING_TRIMMED}" ]; then
        END_TRIMMED=${BEGINNING_TRIMMED%%${END_2}*}
    fi
    echo "${END_TRIMMED}"
}
get_xml_element_with_properties_beginning() {
    local DATA="${1}"
    local START="<${2}"
    local BEGINNING_TRIMMED=${DATA#*${START}}
    echo "${BEGINNING_TRIMMED}"
}
get_xml_element_with_properties_end() {
    local BEGINNING_TRIMMED=${1}}
    local END="</${2}>"
    local END_2="/>"
    local END_TRIMMED=${BEGINNING_TRIMMED%%${END}*}
    if [ "${END_TRIMMED}" = "${BEGINNING_TRIMMED}" ]; then
        END_TRIMMED=${BEGINNING_TRIMMED%%${END_2}*}
    fi
    echo "${END_TRIMMED}"
}
get_xml_property() {
    local DATA="${1}"
    local PROP="${2}"
    local LINE=$(grep "${PROP}[ ]*=[ ]*\".*\"" <<< $DATA)
    local BEGINNING_TRIMMED=${LINE#*${PROP}}
    local BEGINNING_TRIMMED=${BEGINNING_TRIMMED#*\"}
    local END_TRIMMED=${BEGINNING_TRIMMED%%\"*}
    echo "${END_TRIMMED}"
}

parse_ldap_configurations_xml() {

    echo ""
    echo "Parsing ${LDAP_CONFIGURATIONS_FILE}"
    echo ""

    trace "${1}"
    trace ""

    ldapUrl=$(get_xml_element "${1}" "ldapUrl")
    searchConnectionDN=$(get_xml_element "${1}" "searchConnectionDN")
    searchConnectionPassword=$(get_xml_element "${1}" "searchConnectionPassword")
    groupSearchBase=$(get_xml_element "${1}" "groupSearchBase")
    groupSearchFilter=$(get_xml_element "${1}" "groupSearchFilter")
    groupMemberAttribute=$(get_xml_element "${1}" "groupMemberAttribute")
    userNameAttribute=$(get_xml_element "${1}" "userNameAttribute")

    echo "    Found:"
    echo "        ldapUrl                  = '${ldapUrl}'"
    echo "        searchConnectionDN       = '${searchConnectionDN}'"
    echo "        searchConnectionPassword = '<REDACTED>'"
    echo "        groupSearchBase          = '${groupSearchBase}'"
    echo "        groupSearchFilter        = '${groupSearchFilter}'"
    echo "        groupMemberAttribute     = '${groupMemberAttribute}'"
    echo "        userNameAttribute        = '${userNameAttribute}'"
    echo ""

    ldapUrlWithoutScheme=${ldapUrl#*://}
    LDAP_SSL[ldap-config]=""
    LDAP_PORT[ldap-config]="389"

    if [[ "${ldapUrl}" =~ "ldaps://" ]]; then
        #LDAP_SSL[ldap-config]='"--useSSL",'
        LDAP_SSL[ldap-config]="--useSSL"
        LDAP_PORT[ldap-config]="636"
    fi

    if [[ "${ldapUrlWithoutScheme}" =~ ":" ]]; then
        LDAP_HOSTNAME[ldap-config]=$(cut -d ':' -f 1 <<< "${ldapUrlWithoutScheme}")
        LDAP_PORT[ldap-config]=$(cut -d ':' -f 2 <<< "${ldapUrlWithoutScheme}")
    else
        LDAP_HOSTNAME[ldap-config]="${ldapUrlWithoutScheme}"
    fi

    LDAP_ADMIN_USERNAME[ldap-config]="${searchConnectionDN}"
    LDAP_ADMIN_PWD[ldap-config]="${searchConnectionPassword}"
    LDAP_BASE[ldap-config]="${groupSearchBase}"
    LDAP_FILTER[ldap-config]=$(sed "s|&amp;|\&|" <<< ${groupSearchFilter})    # replace any &amp; by &
}

parse_webSecurity_xml() {

    echo ""
    echo "Parsing webSecurity.xml"
    echo ""

    trace "${1}"
    trace ""

    ldapRegistry=$(get_xml_element_with_properties "${1}" "ldapRegistry")
    host=$(get_xml_property         "${ldapRegistry}" "host")
    port=$(get_xml_property         "${ldapRegistry}" "port")
    sslEnabled=$(get_xml_property   "${ldapRegistry}" "sslEnabled")
    baseDN=$(get_xml_property       "${ldapRegistry}" "baseDN")
    bindDN=$(get_xml_property       "${ldapRegistry}" "bindDN")
    bindPassword=$(get_xml_property "${ldapRegistry}" "bindPassword")
    groupFilter=$(get_xml_property  "${ldapRegistry}" "groupFilter")
    userFilter=$(get_xml_property   "${ldapRegistry}" "userFilter")

    echo "    Found:"
    echo "        host          = '${host}'"
    echo "        port          = '${port}'"
    echo "        sslEnabled    = '${sslEnabled}'"
    echo "        baseDN        = '${baseDN}'"
    echo "        bindDN        = '${bindDN}'"
    echo "        bindPassword  = '<REDACTED>'"
    echo "        groupFilter   = '${groupFilter}'"
    echo "        userFilter    = '${userFilter}'"
    echo ""

    if [ "${sslEnabled}" = "true" ]; then
        #LDAP_SSL[webSecurity]='"--useSSL",'
        LDAP_SSL[webSecurity]="--useSSL"
        LDAP_PORT[webSecurity]="636"
    else
        LDAP_SSL[webSecurity]=""
        LDAP_PORT[webSecurity]="389"
    fi
    if [ -n "${port}" ]; then
        LDAP_PORT[webSecurity]=${port}
    fi
    LDAP_HOSTNAME[webSecurity]=${host}
    LDAP_ADMIN_USERNAME[webSecurity]="${bindDN}"
    LDAP_ADMIN_PWD[webSecurity]="${bindPassword}"
    LDAP_BASE[webSecurity]="${baseDN}"
    LDAP_FILTER[webSecurity]=$(sed "s|&amp;|\&|" <<< ${groupFilter})                # replace &amp; by &
    LDAP_FILTER[webSecurity]=$(sed "s|%v|*|"     <<< ${LDAP_FILTER[webSecurity]})   # replace %v by *
}

parse_tlsSecurity_xml() {

    echo ""
    echo "Parsing tlsSecurity.xml"
    echo ""

    trace "${1}"
    trace ""

    local trustStoreRef=$(get_xml_property "${1}" "trustStoreRef")
    local previous
    local abstract=${1}
    local count=0
    while true; do
        previous=${abstract}
        abstract=$(get_xml_element_with_properties_beginning "${abstract}" "keyStore")
        keystore=$(get_xml_element_with_properties_end       "${abstract}" "keyStore")
        id________=$(get_xml_property "${keystore}" "id")
        TRUST_TYPE=$(get_xml_property "${keystore}" "type")
        TRUST_PASS=$(get_xml_property "${keystore}" "password")
        TRUST_PATH=$(get_xml_property "${keystore}" "location")

        if [ "${id______:-}" = "${trustStoreRef:-}" ]; then
            break
        fi
        count=$((count+1))
        if [[ "${abstract:-}" = "${previous:-}" || "${count}" -gt "10" ]]; then
            break
        fi
    done

    echo "    Found:"
    echo "        location      = '${TRUST_PATH:-}'"
    echo "        type          = '${TRUST_TYPE:-}'"
    echo "        password      = '<REDACTED>'"
    echo "        id            = '${id________}'"
    echo ""
}

copy_truststore() {

    if [ -n "${TRUST_PATH:-}" ]; then
        echo ""
        echo "Retrieving the truststore from '${DC}'..."
        TRUST_FILE="${PWD}/$(basename ${TRUST_PATH})"
        local RESULT=$(kubectl cp ${DC}:${TRUST_PATH} ${TRUST_FILE} --namespace ${NAMESPACE})
        if [ "$?" = "0" ]; then
            echo " - saved into ${TRUST_FILE}"
        else
            echo " unable to save ${TRUST_FILE}"
            echo " ${RESULT}"
        fi
    fi
}

start_pod() {

    local STATUS=$(kubectl get pod ldap-sdk-tools --namespace ${NAMESPACE} -o jsonpath='{.status.phase}' 2>/dev/null)
    trace "STATUS='${STATUS}'"

    if [ "${STATUS}" = "Running" ]; then
        POD_STARTED=true
        return
    fi

    echo " - starting pod 'ldap-sdk-tools'..."
    CMD=$(cat <<EOF
    kubectl run ldap-sdk-tools --namespace ${NAMESPACE} --restart=Never --image=pingidentity/ldap-sdk-tools:edge '--overrides=
    {
        "spec": {
            "securityContext": {
                "seccompProfile": {
                    "type": "RuntimeDefault"
                }
            },
            "containers": [
                {
                    "name": "default",
                    "image": "pingidentity/ldap-sdk-tools:edge",
                    "command": [
                        "/bin/sh"
                    ],
                    "tty": true
                }
            ]
        }
    }'
EOF
)
    trace "$CMD"
    RESULT=$(eval $CMD)
    if [ "$?" != "0" ]; then
        echo "   unable to start ldap-sdk-tools pod:"
        echo "   ${RESULT}"
    else
        POD_STARTED=true
    fi
}

stop_pod() {
    if [ ${POD_STARTED} = "true" ]; then
        echo ""
        echo " - deleting pod ldap-sdk-tools..."
        kubectl delete pod ldap-sdk-tools -n ${NAMESPACE}
        POD_STARTED=false
    fi
}

#
#  run ldapsearch using the parameters found in a file in a decisioncenter pod (either ldap-configurations.xml or webSecurity.xml)
#
test() {

    CHOICE="${1}"
    echo ""

    start_pod
    if [ "${POD_STARTED:-}" != "true" ]; then
        return
    fi

    if [[ -n "${TRUST_FILE:-}" ]]; then
        echo " - copying the truststore file '${TRUST_FILE}'..."
        CMD="kubectl cp ${TRUST_FILE} ldap-sdk-tools:/tmp/$(basename ${TRUST_FILE}) -n ${NAMESPACE}"
        trace "$CMD"
        local RESULT=$(eval $CMD)
        if [ "$?" != "0" ]; then
            echo "   Error while copying:"
            echo "   ${RESULT}"
            return
        fi
    fi

    echo " - Running the command:"
    echo ""
    echo "    ldapsearch --hostname           ${LDAP_HOSTNAME[${CHOICE}]}"
    echo "               --port               ${LDAP_PORT[${CHOICE}]}"
    if [ -n "${LDAP_SSL[${CHOICE}]}" ]; then 
    echo "               ${LDAP_SSL[${CHOICE}]}"; 
    fi
    echo "               --bindDN             ${LDAP_ADMIN_USERNAME[${CHOICE}]}"
    echo "               --bindPassword       <REDACTED>"
    echo "               --baseDN             ${LDAP_BASE[${CHOICE}]}"
    echo "               --filter             ${LDAP_FILTER[${CHOICE}]}"
    if [ "${FOUND_TLS_SECURITY}" = "true" ]; then 
    echo "               --trustStorePath     ${TRUST_FILE:-}"; 
    echo "               --trustStorePassword <REDACTED>"; 
    echo "               --trustStoreFormat   ${TRUST_TYPE:-}"; 
    fi
    echo ""
    CMD="kubectl exec -it -n ${NAMESPACE} ldap-sdk-tools -- ldapsearch \
            --hostname     '${LDAP_HOSTNAME[${CHOICE}]}' \
            --port         '${LDAP_PORT[${CHOICE}]}' \
            --bindDN       '${LDAP_ADMIN_USERNAME[${CHOICE}]}' \
            --bindPassword '${LDAP_ADMIN_PWD[${CHOICE}]}' \
            --baseDN       '${LDAP_BASE[${CHOICE}]}' \
            --filter       '${LDAP_FILTER[${CHOICE}]}'"
    if [ -n "${LDAP_SSL[${CHOICE}]}" ]; then 
        CMD="${CMD} \
            ${LDAP_SSL[${CHOICE}]}" 
    fi
    if [ "${FOUND_TLS_SECURITY}" = "true" ]; then
        CMD="${CMD} \
            --trustStorePath     '/tmp/$(basename ${TRUST_FILE:-})' \
            --trustStorePassword '${TRUST_PASS:-}' \
            --trustStoreFormat   '${TRUST_TYPE:-}'" 
    fi
    trace "$CMD"
    if ! eval $CMD ; then
        # an error occured. Catch this error here to prevent from aborting the script
        echo "" # dummy instruction
    fi
}

#
#   run ldapsearch using the user-defined ${PARAMS_FILE} as parameters 
#
test_with_params_file() {

    echo ""
    echo "Running ldapsearch with the parameters in '${PARAMS_FILE}'"

    echo " - parsing the file ${PARAMS_FILE}..."
    while IFS='=' read -r key value
    do
        trace "      ${key}=${value}"
        eval  "local ${key}=\${value}"
    done < "${PARAMS_FILE}"

    TEMP_PARAMS_FILE=$(mktemp)
    if [ -n "${trustStorePath:-}" ]; then
        sed "s|trustStorePath=${trustStorePath}|trustStorePath=/tmp/$(basename ${trustStorePath})|" "${PARAMS_FILE}" > "${TEMP_PARAMS_FILE}"
    else
        cp ${PARAMS_FILE} ${TEMP_PARAMS_FILE}
    fi

    local ERROR=false
    start_pod
    if [ "${POD_STARTED:-}" != "true" ]; then
        ERROR=true
    fi

    if [ "${ERROR}" = "false" ]; then
        echo " - copying the parameters file '${PARAMS_FILE}'..."
        CMD="kubectl cp ${TEMP_PARAMS_FILE} ldap-sdk-tools:/tmp/$(basename ${PARAMS_FILE}) -n ${NAMESPACE}"
        trace "$CMD"
        RESULT=$(eval $CMD)
        if [ "$?" != "0" ]; then
            echo "   Error while copying:"
            echo "   ${RESULT}"
            ERROR=true
        fi
    fi

    if [[ "${ERROR}" = "false" && -n "${trustStorePath:-}" ]]; then
        echo " - copying the truststore file '${trustStorePath}'..."
        CMD="kubectl cp ${trustStorePath} ldap-sdk-tools:/tmp/$(basename ${trustStorePath}) -n ${NAMESPACE}"
        trace "$CMD"
        RESULT=$(eval $CMD)
        if [ "$?" != "0" ]; then
            echo "   Error while copying:"
            echo "   ${RESULT}"
            ERROR=true
        fi
    fi

    if [ "${ERROR}" = "false" ]; then
        echo " - running ldapsearch..."
        CMD="kubectl exec -it -n ${NAMESPACE} ldap-sdk-tools -- ldapsearch --propertiesFilePath /tmp/$(basename ${PARAMS_FILE})"
        trace "$CMD"
        echo ""
        if ! eval $CMD ; then
            # an error occured. Catch this error here to prevent from aborting the script
            echo "" # dummy instruction
        fi
    fi

    stop_pod
    rm ${TEMP_PARAMS_FILE}
}

#
#   run ldapsearch interactively
#
test_interactive() {

    start_pod
    kubectl exec -it --namespace ${NAMESPACE} ldap-sdk-tools -- ldapsearch --interactive
}

create_params_file() {
    CHOICE=${1}
    cat >${PWD}/${1}.properties <<EOF
hostname=${LDAP_HOSTNAME[${CHOICE}]}
port=${LDAP_PORT[${CHOICE}]}
useSSL=$([ -z "${LDAP_SSL[${CHOICE}]}" ] && echo "false" || echo "true")
bindDN=${LDAP_ADMIN_USERNAME[${CHOICE}]}
bindPassword=${LDAP_ADMIN_PWD[${CHOICE}]}
baseDN=${LDAP_BASE[${CHOICE}]}
filter=${LDAP_FILTER[${CHOICE}]}
EOF

    if [[ "${FOUND_TLS_SECURITY}" = "true" && -n "${TRUST_FILE:-}" &&  -n "${TRUST_TYPE:-}" &&  -n "${TRUST_PASS:-}" ]]; then
        cat >>${PWD}/${1}.properties <<EOF
trustStoreFormat=${TRUST_TYPE}
trustStorePassword=${TRUST_PASS}
trustStorePath=${TRUST_FILE}
EOF
    fi

    echo " - created ${PWD}/${1}.properties"
}

create_all_params_files() {
    echo ""
    echo "Creating parameters files:"
    [ "${FOUND_LDAP_CONFIG}" = true ] && create_params_file "ldap-config"
    [ "${FOUND_WEBSECURITY}" = true ] && create_params_file "webSecurity"
    echo ""
}

### main ###

while true; do
  trace "argument='${1:-}'"
  case "${1:-}" in
    -n | --namespace )          if [ -z ${2:-} ]; then 
                                    echo "Please specify a namespace"
                                    usage
                                else 
                                    NAMESPACE="${2}"
                                    USE_CURRENT_NAMESPACE=false
                                fi
                                shift 2 ;;

    -f | --propertiesFilePath ) if [ -z ${2:-} ]; then 
                                    echo "Please specify a file"
                                    usage
                                elif [ ! -f ${2:-} ]; then 
                                    echo "Please specify a file: '${2:-}' does not exist or is not a file"
                                    usage
                                else 
                                    PARAMS_FILE="${2}"
                                fi
                                shift 2 ;;

    -i | --interactive )        INTERACTIVE_MODE=true;  shift ;;
    '' )                        break ;;
    -v | --verbose )            VERBOSE=true;  shift ;;
    -d | --debug )              set -o xtrace; shift ;;
    -h | --help | *)            usage ;;
  esac
done

if [ -n "${PARAMS_FILE}" ]; then
    test_with_params_file
    exit 0
fi

if [ "${INTERACTIVE_MODE}" = false ]; then

    if [ "${USE_CURRENT_NAMESPACE}" = true ]; then
        echo "Using the current namespace (${NAMESPACE})."
    fi

    # find decisioncenter pod
    DC_LIST=($(kubectl get pods --no-headers -o custom-columns=':metadata.name' --namespace ${NAMESPACE} --selector app.kubernetes.io/component=decisionCenter))
    NUM_DC_PODs=${#DC_LIST[@]}
    for DC in ${DC_LIST[@]}; do
        #trace "DC='${DC}'"
        break # any decisioncenter pod will do, take the first one
    done
    if [ -z "${DC:-}" ]; then
        echo "No Decision Center pod found in the namespace '${NAMESPACE}'."

    else
        echo "Found ${NUM_DC_PODs} Decision Center pod(s) in the namespace '${NAMESPACE}'."
        echo ""
        echo "Checking the LDAP config files in ${DC}."

        # read ldap-configurations.xml
        LDAP_CONFIG=$(kubectl exec ${DC} --namespace ${NAMESPACE} -- /bin/sh -c "FILE=/opt/ibm/wlp/usr/servers/defaultServer/auth/${LDAP_CONFIGURATIONS_FILE}; if [ -f \${FILE} ]; then cat \${FILE}; fi")
        if [ -n "${LDAP_CONFIG}" ]; then
            echo " - Found the file '${LDAP_CONFIGURATIONS_FILE}'."
            FOUND_LDAP_CONFIG=true
        fi

        # read webSecurity.xml
        WEBSECURITY=$(kubectl exec ${DC} --namespace ${NAMESPACE} -- /bin/sh -c "FILE=/opt/ibm/wlp/usr/servers/defaultServer/auth/webSecurity.xml; if [ -f \${FILE} ]; then cat \${FILE}; fi")
        if [ -n "${WEBSECURITY}" ]; then
            echo " - Found the file 'webSecurity.xml'"
            FOUND_WEBSECURITY=true
        fi

        # read tlsSecurity.xml
        TLS_SECURITY=$(kubectl exec ${DC} --namespace ${NAMESPACE} -- /bin/sh -c "FILE=/opt/ibm/wlp/usr/servers/defaultServer/tlsSecurity.xml; if [ -f \${FILE} ]; then cat \${FILE}; fi")
        if [ -n "${TLS_SECURITY}" ]; then
            echo " - Found the file 'tlsSecurity.xml'"
            FOUND_TLS_SECURITY=true
        fi

        # parse the files
        if [ -n "${LDAP_CONFIG}" ]; then
            parse_ldap_configurations_xml "${LDAP_CONFIG}"
        fi
        if [ -n "${WEBSECURITY}" ]; then
            parse_webSecurity_xml "${WEBSECURITY}"
        fi
        if [ -n "${TLS_SECURITY}" ]; then
            parse_tlsSecurity_xml "${TLS_SECURITY}"
            copy_truststore
        fi

        if [[ "${FOUND_LDAP_CONFIG}" == false && "${FOUND_WEBSECURITY}" == false ]]; then
            # automatically chose the interactive mode if neither LDAP configuration file was found
            INTERACTIVE_MODE=true
        fi
    fi
fi

if [ "${INTERACTIVE_MODE}" = true ]; then
    test_interactive
    stop_pod
    exit 0
fi

while true; do

    echo ""
    echo "You can either:"
    CHOICES=("test using ${LDAP_CONFIGURATIONS_FILE}" \
             "test using webSecurity.xml" \
             "test interactively" \
             "create parameters file(s) from ${LDAP_CONFIGURATIONS_FILE} and webSecurity.xml" \
             "quit")
    PS3="Your choice: "

    select CHOICE in "${CHOICES[@]}"; do
        case "${REPLY}" in
            1) if [ "${FOUND_LDAP_CONFIG}" = true ]; then test "ldap-config"; break; else echo "invalid choice: missing file ${LDAP_CONFIGURATIONS_FILE}"; fi ;;
            2) if [ "${FOUND_WEBSECURITY}" = true ]; then test "webSecurity"; break; else echo "invalid choice: missing file webSecurity.xml"; fi ;;
            3) test_interactive; break ;;
            4) create_all_params_files; break ;;
            5) stop_pod; exit 0 ;;
        esac
    done
done
