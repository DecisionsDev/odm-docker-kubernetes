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
FOUND_LDAP_CONFIG=false
FOUND_WEBSECURITY=false
USE_CURRENT_NAMESPACE=true
NAMESPACE=$(kubectl config view --minify -o jsonpath='{..namespace}')
PARAMS_FILE=""
declare -i PODCOUNT=0
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
  echo "  -n, --namespace           Namespace where ODM is installed"
  echo "  -f, --propertiesFilePath  File containing the parameters for ldapsearch"
  echo "  -h, --help                Show this help message and exit"
  echo "  -v, --verbose             Enable verbose output"
  echo "  -d, --debug               Enable debug traces"
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
    local BEGINNING_TRIMMED=${DATA##*${START}}
    local END_TRIMMED=${BEGINNING_TRIMMED%%${END}*}
    echo "${END_TRIMMED}"
}
get_xml_property() {
    local DATA="${1}"
    local PROP="${2}"
    local LINE=$(grep "${PROP}[ ]*=[ ]*\".*\"" <<< $DATA)
    local BEGINNING_TRIMMED=${LINE#*\"}
    local END_TRIMMED=${BEGINNING_TRIMMED%\"*}
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
        LDAP_SSL[ldap-config]='"--useSSL",'
        #LDAP_SSL[ldap-config]="--useSSL"
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
        LDAP_SSL[webSecurity]='"--useSSL",'
        #LDAP_SSL[webSecurity]="--useSSL"
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

#
#  run ldapsearch using the parameters found in a file in a decisioncenter pod (either ldap-configurations.xml or webSecurity.xml)
#
test() {

    CHOICE="${1}"

    echo ""
    echo "Running command:"
    echo ""
    echo "    ldapsearch --hostname     ${LDAP_HOSTNAME[${CHOICE}]}"
    echo "               --port         ${LDAP_PORT[${CHOICE}]}"
    if [ -n "${LDAP_SSL[${CHOICE}]}" ]; then echo "               ${LDAP_SSL[${CHOICE}]:1:-2}"; fi
    echo "               --bindDN       ${LDAP_ADMIN_USERNAME[${CHOICE}]}"
    echo "               --bindPassword <REDACTED>"
    echo "               --baseDN       ${LDAP_BASE[${CHOICE}]}"
    echo "               --filter       ${LDAP_FILTER[${CHOICE}]}"
    echo ""

    PODCOUNT+=1
    CMD=$(cat <<EOF
        kubectl run -it ldap-sdk-tools-${PODCOUNT} --namespace ${NAMESPACE} --rm --restart=Never --image=pingidentity/ldap-sdk-tools:edge --overrides='
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
                            "/opt/tools/ldapsearch"
                        ],
                        "args": [
                            "--hostname",     "${LDAP_HOSTNAME[${CHOICE}]}",
                            "--port",         "${LDAP_PORT[${CHOICE}]}",            ${LDAP_SSL[${CHOICE}]}
                            "--bindDN",       "${LDAP_ADMIN_USERNAME[${CHOICE}]}",
                            "--bindPassword", "${LDAP_ADMIN_PWD[${CHOICE}]}",
                            "--baseDN",       "${LDAP_BASE[${CHOICE}]}",
                            "--filter",       "${LDAP_FILTER[${CHOICE}]}"
                        ],
                        "tty": true
                    }
                ]
            }
        }'
EOF
)
    trace "${CMD}"
    trace ""
    eval "${CMD}"
}

#
#   run ldapsearch using the user-defined ${PARAMS_FILE} as parameters 
#
test_with_params_file() {

    echo ""
    echo "Running ldapsearch with the parameters in '${PARAMS_FILE}'"
    echo ""

    PARAMS=`cat ${PARAMS_FILE}`
    if [ -z "${PARAMS}" ]; then
        echo "empty file"
        exit 1
    fi
    trace ${PARAMS}
    trace ""

    # convert linebreaks into \n (required by JSON)
    PARAMS_NO_LINEBREAK=${PARAMS//$'\n'/'\\n'}

    # useful to convert back \n into linebreaks
    WHAT=''\'''\''\\\\n'\'''\'''
    BY=''\''$'\''\\n'\'''\'''

    [[ ${DEBUG:-} == "true" ]] && SET_X="set -x; " || SET_X=""
    CMD=$(cat <<EOF
    kubectl run -it ldap-sdk-tools --namespace ${NAMESPACE} --rm --restart=Never --image=pingidentity/ldap-sdk-tools:edge '--overrides=
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
                    "args": [
                        "-c", "${SET_X} PARAMS_NO_LINEBREAK=\"${PARAMS_NO_LINEBREAK}\";  echo \"\${PARAMS_NO_LINEBREAK//${WHAT}/${BY}}\" > /opt/params; sleep 5; ldapsearch --propertiesFilePath /opt/params "
                    ],
                    "tty": true
                }
            ]
        }
    }'
EOF
)
    trace $CMD
    eval $CMD
    exit $?
}

#
#   run ldapsearch interactively
#
test_interactive() {

    echo ""
    echo "Running command:"
    echo ""
    echo "    ldapsearch --interactive"
    echo ""

    PODCOUNT+=1
    CMD=$(cat <<EOF
        kubectl run -it ldap-sdk-tools-${PODCOUNT} --namespace ${NAMESPACE} --rm --restart=Never --image=pingidentity/ldap-sdk-tools:edge --overrides='
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
                        "args": [
                            "-c", "echo 1; sleep 5; /opt/tools/ldapsearch --interactive"
                        ],
                        "stdin": true,
                        "tty": true
                    }
                ]
            }
        }'
EOF
)
    eval "${CMD}"
}

create_params_file() {
    CHOICE=${1}
    cat >${PWD}/${1}.properties <<EOF
hostname=${LDAP_HOSTNAME[${CHOICE}]}
port=${LDAP_PORT[${CHOICE}]}
enableSSL=$([ -z "${LDAP_SSL[${CHOICE}]}" ] && echo "false" || echo "true")
bindDN=${LDAP_ADMIN_USERNAME[${CHOICE}]}
bindPassword=${LDAP_ADMIN_PWD[${CHOICE}]}
baseDN=${LDAP_BASE[${CHOICE}]}
filter=${LDAP_FILTER[${CHOICE}]}
EOF
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

    '' )                        break ;;
    -v | --verbose )            VERBOSE=true;  shift ;;
    -d | --debug )              set -o xtrace; shift ;;
    -h | --help | *)            usage ;;
  esac
done

if [ -n "${PARAMS_FILE}" ]; then
    test_with_params_file
fi

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

    # parse the files
    if [ -n "${LDAP_CONFIG}" ]; then
        parse_ldap_configurations_xml "${LDAP_CONFIG}"
    fi
    if [ -n "${WEBSECURITY}" ]; then
        parse_webSecurity_xml "${WEBSECURITY}"
    fi
fi

while true; do

    if [[ "${FOUND_LDAP_CONFIG}" == false && "${FOUND_WEBSECURITY}" == false ]]; then
        # automatically chose the interactive mode if no file was found
        test_interactive
        break
    else
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
                1) if [ "${FOUND_LDAP_CONFIG}" = true ]; then CHOICE="ldap-config"; break; else echo "invalid choice: missing file ${LDAP_CONFIGURATIONS_FILE}"; fi ;;
                2) if [ "${FOUND_WEBSECURITY}" = true ]; then CHOICE="webSecurity"; break; else echo "invalid choice: missing file webSecurity.xml"; fi ;;
                3) break ;;
                4) create_all_params_files; break ;;
                5) break ;;
            esac
        done

        if [ "${REPLY}" = "5" ]; then
            break
        elif [ "${REPLY}" = "3" ]; then
            test_interactive
        elif [[ "${REPLY}" != "4" ]]; then
            test "${CHOICE}"
        fi
    fi
done
