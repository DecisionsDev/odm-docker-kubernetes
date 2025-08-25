# LDAP Troubleshooting

<!-- TOC -->

- [Introduction](#introduction)
- [Usage](#usage)
- [1) automated LDAP group search](#1-automated-ldap-group-search)
  - [Choices 1 or 2: Run a LDAP group search using the parameters extracted](#choices-1-and-2-run-a-ldap-group-search-using-the-parameters-extracted)
  - [Choice 3: Run a LDAP search in interactive mode](#choice-3-run-a-ldap-search-in-interactive-mode)
  - [Choice 4: Save the parameters extracted from the LDAP configuration files](#choice-4-save-the-parameters-extracted-from-the-ldap-configuration-files)
- [2) file-based LDAP search](#2-file-based-ldap-search)
- [3) interactive LDAP search](#3-interactive-ldap-search)
- [Common errors](#common-errors)
  - [a) Host not found (UnknownHostException)](#a-host-not-found-unknownhostexception)
  - [b) wrong Port number (An error occurred while attempting to establish a connection to server)](#b-wrong-port-number-an-error-occurred-while-attempting-to-establish-a-connection-to-server)
  - [c) Certificate not trusted (SSLHandshakeException (PKIX path building failed))](#c-certificate-not-trusted-sslhandshakeexception-pkix-path-building-failed)
  - [d) invalid Credentials](#d-invalid-credentials)
  - [e) baseDN not found](#e-basedn-not-found)
  - [f) invalid filter](#f-invalid-filter)


<!-- /TOC -->

## Introduction

The `ldap-diagnostic.sh` tool helps identify issues in the LDAP configuration of ODM on Kubernetes.

The tool can be used in three different ways:

1. the tool can extract the LDAP configuration and the truststore from one Decision Center pod and performs a LDAP group search using the parameters extracted to validate them. Those parameters and the truststore can be saved for use in the second mode below.

1. the tool can take a parameters file as argument and run a LDAP search according to the filter and other parameters specified in the file.

1. the tool can prompt the user to specify all the parameters of the LDAP search (host, port, credentials, baseDN, filter, ...).

The tool starts a pod named `ldap-sdk-tools` in the specified namespace (the current one by default) and an LDAP search is performed inside this pod using the [`ldapsearch` command line tool](https://docs.ldap.com/ldap-sdk/docs/tool-usages/ldapsearch.html).

## Usage

```shell
Usage: ldap-diagnostic.sh [options]
Options (optional):
  -f, --propertiesFilePath <FILE>   Run ldapsearch without interaction using the parameters in this file
  -i, --interactive                 Run ldapsearch in interactive mode
  -n, --namespace     <NAMESPACE>   Namespace where ODM is installed
  -v, --verbose                     Enable verbose output
  -d, --debug                       Enable debug traces
  -h, --help                        Show this help message and exit
```

  - automated LDAP group search

    ```shell
    ldap-diagnostic.sh [-n <NAMESPACE>]
    ```

  - file-based LDAP search

    ```shell
    ldap-diagnostic.sh -f <FILE> [-n <NAMESPACE>]
    ```

  - interactive LDAP search

    ```shell
    ldap-diagnostic.sh -i [-n <NAMESPACE>]
    ```

## 1) automated LDAP group search

In this mode the tool extracts the LDAP configuration and the truststore from one Decision Center pod. 

Pass the `-n <NAMESPACE>` argument to specify in which namespace a Decision Center pod can be found. If this argument is missing, the tools looks for a Decision Center pod in the current namespace.

The tool looks for the files below:
  - `webSecurity.xml`
  - `ldap-configurations.xml`
  - `tlsSecurity.xml`

> Note: 
> - `webSecurity.xml` is used for authenticating users 
> - `ldap-configurations.xml` for synchronizing the users and/or groups in Decision Center
> - `tlsSecurity.xml` specifies the truststore used (among other SSL parameters)

The tool parses those XML files using `xmllint` when it can be found. It is best to have `xmllint` installed as it is more reliable than the fallback solution.

The result of the parsing is then displayed and the user prompted:

```shell
$ ./ldap-diagnostic.sh                                                                                            
Using the current namespace (odm).
Found 1 Decision Center pod(s) in the namespace 'odm'.

Checking the LDAP config files in odm-ldap-odm-decisioncenter-5c8746999c-b6ttz.
 - Found the file 'ldap-configurations.xml'.
 - Found the file 'webSecurity.xml'
 - Found the file 'tlsSecurity.xml'

Parsing ldap-configurations.xml

    Found:
        ldapUrl                  = 'ldaps://ldap-ssl1.fyre.ibm.com:636'
        searchConnectionDN       = 'uid=admin,OU=users,DC=example,DC=org'
        searchConnectionPassword = '<REDACTED>'
        groupSearchBase          = 'ou=groups,dc=example,dc=org'
        groupSearchFilter        = '(&amp;(cn=*)(objectclass=groupOfUniqueNames))'
        groupMemberAttribute     = 'uniquemember'
        userNameAttribute        = 'cn'


Parsing webSecurity.xml

    Found:
        host          = 'ldap-ssl1.fyre.ibm.com'
        port          = '636'
        sslEnabled    = 'true'
        baseDN        = 'DC=example,DC=org'
        bindDN        = 'uid=admin,OU=users,DC=example,DC=org'
        bindPassword  = '<REDACTED>'
        groupFilter   = '(&amp;(CN=%v)(objectclass=groupOfUniqueNames))'
        userFilter    = '(&amp;(uid=%v)(objectclass=person))'


Parsing tlsSecurity.xml

    Found:
        location      = '/config/security/truststore.p12'
        type          = 'PKCS12'
        password      = '<REDACTED>'
        id            = 'odmDefaultTrustStore'


Retrieving the truststore from 'odm-ldap-odm-decisioncenter-5c8746999c-b6ttz'...
 - saved into /Users/dev/ldapsearch/truststore.p12

You can either:
1) test using ldap-configurations.xml     4) create parameters file(s) from ldap-configurations.xml and webSecurity.xml
2) test using webSecurity.xml             5) quit
3) test interactively
Your choice: 
```

You can either:
  1. Run a LDAP group search using the parameters extracted from `ldap-configurations.xml`
  1. Run a LDAP group search using the parameters extracted from `webSecurity.xml`
  1. Run a LDAP search using parameters entered interactively
  1. Save the parameters extracted from `ldap-configurations.xml` and `webSecurity.xml` in two files to be used in a file-based LDAP search
  1. Quit

### Choices 1 or 2: Run a LDAP group search using the parameters extracted

```shell
Your choice: 1

 - starting pod 'ldap-sdk-tools'...
 - copying the truststore file '/Users/dev/ldapsearch/truststore.p12'...
 - Running the command:

    ldapsearch --hostname           ldap-ssl1.fyre.ibm.com
               --port               636
               --useSSL
               --bindDN             uid=admin,OU=users,DC=example,DC=org
               --bindPassword       <REDACTED>
               --baseDN             ou=groups,dc=example,dc=org
               --filter             (&(cn=*)(objectclass=groupOfUniqueNames))
               --trustStorePath     /Users/dev/ldapsearch/truststore.p12
               --trustStorePassword <REDACTED>
               --trustStoreFormat   PKCS12

dn: cn=oidcResAdministrators,ou=groups,dc=example,dc=org
cn: oidcResAdministrators
uniqueMember: uid=oidcResAdmin,ou=users,dc=example,dc=org
uniqueMember: uid=admin,ou=users,dc=example,dc=org
uniqueMember: uid=dbadmin,ou=users,dc=example,dc=org
objectClass: groupOfUniqueNames
objectClass: top

<...>

dn: cn=oidcRtsAdministrators,ou=groups,dc=example,dc=org
cn: oidcRtsAdministrators
uniqueMember: uid=oidcRtsAdmin,ou=users,dc=example,dc=org
uniqueMember: uid=admin,ou=users,dc=example,dc=org
uniqueMember: uid=dbadmin,ou=users,dc=example,dc=org
objectClass: groupOfUniqueNames
objectClass: top


# Result Code:  0 (success)
# Number of Entries Returned:  8


You can either:
1) test using ldap-configurations.xml     4) create parameters file(s) from ldap-configurations.xml and webSecurity.xml
2) test using webSecurity.xml             5) quit
3) test interactively
Your choice: 
```

### Choice 3: Run a LDAP search in interactive mode

Press 3 and `ldapsearch` is started in interactive mode, asking for the connection parameters (host, port, SSL, bindDN, ...) and offering to set additional parameters:
```shell
Your choice: 3
Launching ldapsearch in interactive mode.

Enter the address of the directory server [localhost]: ldap-ssl1.fyre.ibm.com

Should the LDAP communication be encrypted?
1 - Yes.  Use SSL with default trust settings.
2 - Yes.  Use SSL with a manually specified configuration.
3 - Yes.  Use StartTLS with default trust settings.
4 - Yes.  Use StartTLS with a manually specified configuration.
5 - No.  Use unencrypted LDAP.

q - Quit this program

Enter choice [1]: 1

Enter the port on which to communicate with the directory server [636]: 636

<...>
```
See an example with the unabridged interaction in the alternative way to run `ldapsearch` in interactive mode: [3) interactive LDAP search](#3-interactive-ldap-search).


### Choice 4: Save the parameters extracted from the LDAP configuration files

This creates two properties files containing `ldapsearch` parameters with values extracted from `ldap-configurations.xml` and `webSecurity.xml` respectively:
  - `ldap-config.properties`
  - `webSecurity.properties`

Each file has a similar content. Here is an example below:

```ini
hostname=ldap-ssl1.fyre.ibm.com
port=636
useSSL=true
bindDN=uid=admin,OU=users,DC=example,DC=org
bindPassword=ayDAB4v2w8ih4wBXXmtR
baseDN=ou=groups,dc=example,dc=org
filter=(&(cn=*)(objectclass=groupOfUniqueNames))
trustStoreFormat=PKCS12
trustStorePassword=rpJd3AJG46PJKHntphQf
trustStorePath=/Users/dev/ldapsearch/truststore.p12
```

You can use either file to run a (file-based) LDAP search.

You can modify the values beforehand or add other parameters as defined in `ldapsearch` command line reference: https://docs.ldap.com/ldap-sdk/docs/tool-usages/ldapsearch.html .

## 2) file-based LDAP search

Either create a `ldapsearch` parameters file from scratch (see the list of parameters in `ldapsearch` command line reference link above) or generate it using the command [Choice 4: Saving the parameters extracted from the LDAP configuration files](#choice-4-save-the-parameters-extracted-from-the-ldap-configuration-files) when running the tool in [automated LDAP group search mode](#1-automated-ldap-group-search).

Then run the command `./ldap-diagnostic.sh -f <_LDAPSEARCH_PARAMETERS_FILE> -n <NAMESPACE>`

Example:
```
$ ./ldap-diagnostic.sh -f ldap-config.properties

Running ldapsearch with the parameters in 'ldap-config.properties'
 - parsing the file ldap-config.properties...
 - starting pod 'ldap-sdk-tools'...
 - copying the parameters file 'ldap-config.properties'...
 - copying the truststore file '/Users/dev/ldapsearch/truststore.p12'...
 - running ldapsearch...

# Arguments obtained from properties file '/tmp/ldap-config.properties':
#      --hostname ldap-ssl1.fyre.ibm.com
#      --port 636
#      --bindDN uid=admin,OU=users,DC=example,DC=org
#      --bindPassword '***REDACTED***'
#      --useSSL
#      --trustStorePath /tmp/truststore.p12
#      --trustStorePassword '***REDACTED***'
#      --trustStoreFormat PKCS12
#      --baseDN ou=groups,dc=example,dc=org
#      --filter '(&(cn=*)(objectclass=groupOfUniqueNames))'

dn: cn=oidcResAdministrators,ou=groups,dc=example,dc=org
cn: oidcResAdministrators
uniqueMember: uid=oidcResAdmin,ou=users,dc=example,dc=org
uniqueMember: uid=admin,ou=users,dc=example,dc=org
uniqueMember: uid=dbadmin,ou=users,dc=example,dc=org
objectClass: groupOfUniqueNames
objectClass: top

<...>

dn: cn=oidcRtsAdministrators,ou=groups,dc=example,dc=org
cn: oidcRtsAdministrators
uniqueMember: uid=oidcRtsAdmin,ou=users,dc=example,dc=org
uniqueMember: uid=admin,ou=users,dc=example,dc=org
uniqueMember: uid=dbadmin,ou=users,dc=example,dc=org
objectClass: groupOfUniqueNames
objectClass: top

# Result Code:  0 (success)
# Number of Entries Returned:  8


 - deleting pod ldap-sdk-tools...
pod "ldap-sdk-tools" deleted
```

## 3) interactive LDAP search

```
$ ./ldap-diagnostic.sh -i
 - starting pod 'ldap-sdk-tools'...
Launching ldapsearch in interactive mode.

Enter the address of the directory server [localhost]: ldap-ssl1.fyre.ibm.com

Should the LDAP communication be encrypted?
1 - Yes.  Use SSL with default trust settings.
2 - Yes.  Use SSL with a manually specified configuration.
3 - Yes.  Use StartTLS with default trust settings.
4 - Yes.  Use StartTLS with a manually specified configuration.
5 - No.  Use unencrypted LDAP.

q - Quit this program

Enter choice [1]: 1

Enter the port on which to communicate with the directory server [636]: 636

How do you wish to authenticate to the directory server?
1 - Use simple authentication
2 - Use SASL authentication
3 - Do not authenticate

q - Quit this program

Enter choice [1]: 1

Enter the DN of the user as whom you wish to bind, or simply press ENTER for
anonymous simple authentication: uid=admin,OU=users,DC=example,DC=org

Enter the password for the user: 
The server presented the following certificate chain:

     Subject: CN=ldap-ssl1.fyre.ibm.com,OU=Information Technology Dep.,O=A1A Car Wash,L=Albuquerque,ST=New Mexico,C=US
     Valid From: Sunday, August 24, 2025 at 09:52:00 AM GMT
     Valid Until: Monday, August 24, 2026 at 09:52:00 AM GMT
     SHA-1 Fingerprint: 55:61:30:b5:20:ea:c3:d4:89:18:65:3d:b0:5d:ee:6f:89:90:b2:50
     256-bit SHA-2 Fingerprint: 77:e0:1b:4f:52:d7:51:92:d0:f3:24:20:cb:9a:b3:f7:23:d3:f0:84:4d:c9:af:7e:fa:0c:2e:d7:88:7f:92:6e
     -
     Issuer 1 Subject: CN=docker-light-baseimage,OU=Information Technology Dep.,O=A1A Car Wash,L=Albuquerque,ST=New Mexico,C=US
     Valid From: Saturday, January 16, 2021 at 11:42:00 AM GMT
     Valid Until: Thursday, January 15, 2026 at 11:42:00 AM GMT
     SHA-1 Fingerprint: 05:49:5e:b8:4d:fc:f8:20:24:0a:61:a7:4e:21:e8:19:43:ea:4f:8f
     256-bit SHA-2 Fingerprint: ec:43:38:25:88:11:b7:43:bb:53:ad:28:e1:f9:e0:47:e1:24:48:50:a9:66:d4:4a:09:e1:b4:18:68:00:d9:f1

Do you wish to trust this certificate?  Enter 'y' or 'n': y

Would you like to alter the values of any command-line arguments for the tool?
 1 --enableSSLDebugging                  - false
 2 --baseDN                              -
 3 --scope                               - sub
 4 --sizeLimit                           - 0
 5 --timeLimitSeconds                    - 0
 6 --dereferencePolicy                   - never
 7 --typesOnly                           - false
 8 --requestedAttribute                  -
 9 --filter                              -
10 --filterFile                          -
11 --ldapURLFile                         -
12 --followReferrals                     - false
13 --retryFailedOperations               - false
14 --continueOnError                     - false
15 --ratePerSecond                       -
16 --useAdministrativeSession            - false
17 --dryRun                              - false
18 --wrapColumn                          -
19 --dontWrap                            - false
20 --suppressBase64EncodedValueComments  - false
21 --countEntries                        - false
22 --outputFile                          -
23 --compressOutput                      - false
24 --encryptOutput                       - false
25 --encryptionPassphraseFile            -
26 --separateOutputFilePerSearch         - false
27 --teeResultsToStandardOut             - false
28 --outputFormat                        - ldif
29 --requireMatch                        - false
30 --terse                               - false
31 --verbose                             - false
32 --bindControl                         -
33 --control                             -
34 --accessLogField                      -
35 --accountUsable                       - false
36 --authorizationIdentity               - false
37 --assertionFilter                     -
38 --excludeBranch                       -
39 --generateAccessToken                 - false
40 --getAuthorizationEntryAttribute      -
41 --getBackendSetID                     - false
42 --getEffectiveRightsAuthzID           -
43 --getEffectiveRightsAttribute         -
44 --getRecentLoginHistory               - false
45 --getServerID                         - false
46 --getUserResourceLimits               - false
47 --includeReplicationConflictEntries   - false
48 --includeSoftDeletedEntries           -
49 --draftLDUPSubentries                 - false
50 --rfc3672Subentries                   -
51 --joinRule                            -
52 --joinBaseDN                          -
53 --joinScope                           -
54 --joinSizeLimit                       -
55 --joinFilter                          -
56 --joinRequestedAttribute              -
57 --joinRequireMatch                    - false
58 --manageDsaIT                         - false
59 --matchedValuesFilter                 -
60 --matchingEntryCountControl           -
61 --operationPurpose                    -
62 --overrideSearchLimit                 -
63 --persistentSearch                    -
64 --permitUnindexedSearch               - false
65 --proxyAs                             -
66 --proxyV1As                           -
67 --rejectUnindexedSearch               - false
68 --routeToBackendSet                   -
69 --routeToServer                       -
70 --suppressOperationalAttributeUpdates -
71 --usePasswordPolicyControl            - false
72 --realAttributesOnly                  - false
73 --sortOrder                           -
74 --simplePageSize                      -
75 --virtualAttributesOnly               - false
76 --virtualListView                     -
77 --useJSONFormattedRequestControls     - false
78 --excludeAttribute                    -
79 --redactAttribute                     -
80 --hideRedactedValueCount              - false
81 --scrambleAttribute                   -
82 --scrambleJSONField                   -
83 --scrambleRandomSeed                  -
84 --renameAttributeFrom                 -
85 --renameAttributeTo                   -
86 --moveSubtreeFrom                     -
87 --moveSubtreeTo                       -
88 --scriptFriendly                      - false
89 --ldapVersion                         -
90 --help-debug                          - false
91 --enable-debug-logging                - false
92 --debug-log-level                     - severe
93 --debug-log-category                  -
94 --include-debug-stack-traces          - false
95 --use-multi-line-debug-messages       - false
96 --debug-log-file                      - /opt/ldapsearch.debug
 t {trailing arguments}                  -

 l - Re-prompt for the LDAP connection and authentication arguments
 d - Display the command to run ldapsearch with these settings
 r - Run ldapsearch with these settings
 q - Quit this program

Enter choice: 2   

Specify a new value for argument '--baseDN'

Description:Specifies the base DN that should be used for the search.  If a
            filter file is provided, then this base DN will be used for each
            search with a filter read from that file.  This argument must not
            be provided if the --ldapURLFile is given.  If no base DN is
            specified, then the null base DN will be used by default.

Value Constraints:A provided value must be able to be parsed as an LDAP
                  distinguished name as described in RFC 4514.

Enter a new value: ou=groups,dc=example,dc=org

Would you like to alter the values of any command-line arguments for the tool?
<...>
Enter choice: 9

Specify one or more new values for argument '--filter'

Description:Specifies a filter to use when processing a search.  This may be
            provided multiple times to issue multiple searches with different
            filters.  If this argument is provided, then the first trailing
            argument will not be interpreted as a search filter (all trailing
            arguments will be interpreted as requested attributes).

Value Constraints:A provided value must be able to be parsed as an LDAP search
                  filter as described in RFC 4515.

Enter the desired new value(s), pressing ENTER on an empty line to indicate no
more values are needed.

Enter a new value: (&(cn=*)(objectclass=groupOfUniqueNames))

Enter a new value: 

Would you like to alter the values of any command-line arguments for the tool?
<...>
Enter choice: r

Running the following command:
     ldapsearch \
          --hostname ldap-ssl1.fyre.ibm.com \
          --useSSL \
          --port 636 \
          --bindDN uid=admin,OU=users,DC=example,DC=org \
          --bindPassword '***REDACTED***' \
          --baseDN ou=groups,dc=example,dc=org \
          --filter '(&(cn=*)(objectclass=groupOfUniqueNames))'

The server presented the following certificate chain:

     Subject: CN=ldap-ssl1.fyre.ibm.com,OU=Information Technology Dep.,O=A1A Car Wash,L=Albuquerque,ST=New Mexico,C=US
     Valid From: Sunday, August 24, 2025 at 09:52:00 AM GMT
     Valid Until: Monday, August 24, 2026 at 09:52:00 AM GMT
     SHA-1 Fingerprint: 55:61:30:b5:20:ea:c3:d4:89:18:65:3d:b0:5d:ee:6f:89:90:b2:50
     256-bit SHA-2 Fingerprint: 77:e0:1b:4f:52:d7:51:92:d0:f3:24:20:cb:9a:b3:f7:23:d3:f0:84:4d:c9:af:7e:fa:0c:2e:d7:88:7f:92:6e
     -
     Issuer 1 Subject: CN=docker-light-baseimage,OU=Information Technology Dep.,O=A1A Car Wash,L=Albuquerque,ST=New Mexico,C=US
     Valid From: Saturday, January 16, 2021 at 11:42:00 AM GMT
     Valid Until: Thursday, January 15, 2026 at 11:42:00 AM GMT
     SHA-1 Fingerprint: 05:49:5e:b8:4d:fc:f8:20:24:0a:61:a7:4e:21:e8:19:43:ea:4f:8f
     256-bit SHA-2 Fingerprint: ec:43:38:25:88:11:b7:43:bb:53:ad:28:e1:f9:e0:47:e1:24:48:50:a9:66:d4:4a:09:e1:b4:18:68:00:d9:f1

Do you wish to trust this certificate?  Enter 'y' or 'n': y

dn: cn=oidcResAdministrators,ou=groups,dc=example,dc=org
cn: oidcResAdministrators
uniqueMember: uid=oidcResAdmin,ou=users,dc=example,dc=org
uniqueMember: uid=admin,ou=users,dc=example,dc=org
uniqueMember: uid=dbadmin,ou=users,dc=example,dc=org
objectClass: groupOfUniqueNames
objectClass: top

<...>

dn: cn=oidcRtsAdministrators,ou=groups,dc=example,dc=org
cn: oidcRtsAdministrators
uniqueMember: uid=oidcRtsAdmin,ou=users,dc=example,dc=org
uniqueMember: uid=admin,ou=users,dc=example,dc=org
uniqueMember: uid=dbadmin,ou=users,dc=example,dc=org
objectClass: groupOfUniqueNames
objectClass: top

# Result Code:  0 (success)
# Number of Entries Returned:  8

 - deleting pod ldap-sdk-tools...
pod "ldap-sdk-tools" deleted
````

## Common errors

### a) Host not found (UnknownHostException)

```shell
# An error occurred while attempting to create a connection pool to communicate
# with the directory server:  LDAPException(resultCode=91 (connect error),
# errorMessage='An error occurred while attempting to resolve address
# 'ldap-ssl1.fyre.ibm.com':
# UnknownHostException(ldap-ssl1.fyre.ibm.com: Name does not resolve),
# ldapSDKVersion=7.0.3, revision=b2dd76df6eebef961e35c4bc17912600a5db7eba')
command terminated with exit code 91
```

### b) wrong Port number (An error occurred while attempting to establish a connection to server)

```shell
# An error occurred while attempting to create a connection pool to communicate
# with the directory server:  LDAPException(resultCode=91 (connect error),
# errorMessage='An error occurred while attempting to connect to server
# ldap-ssl1.fyre.ibm.com:6360:  IOException(LDAPException(resultCode=91
# (connect error), errorMessage='An error occurred while attempting to
# establish a connection to server
# ldap-ssl1.fyre.ibm.com/9.30.248.242:6360:  ConnectException(Connection
# refused), ldapSDKVersion=7.0.3,
# revision=b2dd76df6eebef961e35c4bc17912600a5db7eba'))')
command terminated with exit code 91
```

### c) Certificate not trusted (SSLHandshakeException (PKIX path building failed))

```shell
# An error occurred while attempting to create a connection pool to communicate
# with the directory server:  LDAPException(resultCode=91 (connect error),
# errorMessage='An error occurred while attempting to connect to server
# ldap-ssl1.fyre.ibm.com:636:  IOException(LDAPException(resultCode=91
# (connect error), errorMessage='An error occurred while attempting to
# establish a connection to server ldap-ssl1.fyre.ibm.com/9.30.146.129:636:
# SSLHandshakeException(PKIX path building failed:
# sun.security.provider.certpath.SunCertPathBuilderException: unable to find
# valid certification path to requested target), ldapSDKVersion=7.0.3,
# revision=b2dd76df6eebef961e35c4bc17912600a5db7eba'))')
command terminated with exit code 91
```

### d) invalid credentials

```shell
# Bind Result:
# Result Code:  49 (invalid credentials)

# An error occurred while attempting to create a connection pool to communicate
# with the directory server:  LDAPException(resultCode=49 (invalid
# credentials), errorMessage='invalid credentials', ldapSDKVersion=7.0.3,
# revision=b2dd76df6eebef961e35c4bc17912600a5db7eba)
command terminated with exit code 49
```

### e) baseDN not found (no such object)

```shell
# Result Code:  32 (no such object)
```

### f) invalid filter

```shell
The provided value '&(cn=*)(objectclass=groupOfUniqueNames))' for argument '--filter' could not be parsed as a search filter:  Unable to parse string '&(cn=*)(objectclass=groupOfUniqueNames))' as an LDAP filter because there were a mismatched number of opening and closing parentheses found between positions 1 and 39.
command terminated with exit code 89
```