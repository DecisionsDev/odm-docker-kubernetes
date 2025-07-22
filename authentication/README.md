# Troubleshooting

<!-- TOC -->

- [Tips](#tips)
    - [Reviewing the configuration files](#1-reviewing-the-configuration-files)
    - [Enabling detailed traces](#2-enabling-detailed-traces)
- [Common issues](#common-issues)
    - [Missing or invalid redirect](#1-missing-or-invalid-redirect)
    - [Missing or invalid OpenID Server Certificate](#2-missing-or-invalid-openid-server-certificate)
    - [Missing or Invalid Allowed Domain List](#3-missing-or-invalid-allowed-domain-list)
    - [Authorization issue](#4-authorization-issue)
    - [Proxy](#5-proxy)

<!-- /TOC -->

It is best to follow our OpenID tutorial suitable for your OpenID Connect Provider: either [EntraID](AzureAD/README.md), [Cognito](Cognito/README.md), [Keycloak](Keycloak/README.md) or [OKTA](Okta/README.md).

Each tutorial walks you through the steps of configuring your OpenID Connect Provider, and provides a script to generate the ODM configuration files and instructions to deploy ODM.

Should you encounter any issue, this page will help you with some troubleshooting tips and solutions to the most common issues.

Feel free to reach the support if you have any suggestion to improve this page.

## Tips
### 1) Reviewing the configuration files

Start by reviewing the configuration files as most errors come from inaccurate or inconsistent information in:
- the Helm chart parameters
- the ODM configuration files stored in the secret referenced by `customization.authSecretRef`:
  - OdmOidcProviders.json
  - openIdParameters.properties
  - openIdWebSecurity.xml
  - webSecurity.xml, ...

Also check that the `OdmOidcProviders.json` and `openIdParameters.properties` files do not contain any comment.

If you contact the support, please provide those files along with the logs (see the [ODM on kubernetes MustGather technote](https://www.ibm.com/support/pages/node/6404292?view=full) which can help to collect the logs from all the pods).

### 2) Enabling detailed traces

#### 2.1) Useful loggers

If the logs from the ODM pods (and the OpenID Connect Provider) are too terse, more detailed traces can be recorded in the ODM logs by enabling additional loggers.

- Start with the two loggers below:

| Logger | Level |
| ------ | ----- |
| com.ibm.ws.security.*  | all    |
| com.ibm.ws.webcontainer.security.* | all     |

- and enable the loggers below as well if needed:

| Logger | Level |
| ------ | ----- |
| com.ibm.oauth.*  | all    |
| com.ibm.wsspi.security.oauth20.* | all     |
| org.openid4java.* | all     |

#### 2.2) How to change the trace specification

Each ODM component (Decision Center, Decision Runner, Decision Server Console and Decision Server Runtime) has its own trace specification, stored in a ConfigMap.

A default ConfigMap for each ODM component is automatically generated if no custom trace specification is specified in the Helm chart parameters.

To change the trace specification of an ODM component, it is easiest to modify this default ConfigMap as explained in the [documentation](https://www.ibm.com/docs/en/odm/9.5.0?topic=kubernetes-customizing-log-levels), 

For instance add `com.ibm.ws.security.*=all:com.ibm.ws.webcontainer.security.*=all` to the value for the `traceSpecification` parameter of the `logging` element, eg. (for Decision Center):

```yaml
apiVersion: v1
data:
  dc-logging: "<server>\n\t<logging hideMessage=\"SRVE9967W\" traceFileName=\"stdout\"
    traceFormat=\"BASIC\" traceSpecification=\"*=audit:org.apache.solr.*=warning:com.ibm.rules.bdsl.search.solr.*=warning:com.ibm.ws.security.*=all:com.ibm.ws.webcontainer.security.*=all\"
    consoleLogLevel=\"INFO\"/>\n\t<!-- Uncomment to get access logs \n\t<httpAccessLogging
    filepath=\"/logs/access.log\" id=\"accessLogging\"/>\n\t-->\n</server>"
...
```

## Common issues:

## #1 Missing or invalid redirect
### 1.1) Symptoms
The consoles login page is not displayed, and an error like `Invalid parameter: redirect_uri` is displayed instead.

### 1.2) Cause
If the user needs to be authenticated, ODM sends a request to the OpenID Connect provider with the URI that the response (with the token) should be sent to.

The OpenID Connect provider ignores requests whose redirect URI is not registered for security reasons, in case the requester is malicious.
This ensures that the recipient of a token is trusted.

### 1.3) Solution
Follow the tutorial to register (or modify) the redirect URIs for each ODM application.

For the consoles, the redirect URIs are:
  * https://<Decision_Center_URL>/decisioncenter/openid/redirect/odm
  * https://<Decision_Server_Console_URL>/res/openid/redirect/odm

## #2 Missing or invalid OpenID Server Certificate
### 2.1) Symptoms
The browser displays the error:
```json
{"error_description":"OpenID Connect client returned with status: SEND_401","error":401}
```
and the ODM pod logs contains the error:

```
CWPKI0823E: SSL HANDSHAKE FAILURE:  A signer with SubjectDN [CN=*.<OPENID_SERVER_DOMAIN>] was sent from the host [<OPENID_SERVER_URL>:443].
The signer   might need to be added to local trust store [/config/security/truststore.jks], located in SSL configuration alias [odmDefaultSSLConfig].
The extended  error message from the SSL handshake exception is: [unable to find valid certification path to requested target].
```

### 2.2) Cause
The communication between ODM and the OpenID Connect Provider is usually secured with HTTPS.

A connection cannot be made if the certificate of OpenID Connect Provider is not trusted by ODM.

### 2.3) Solution
Follow the tutorial instructions to retrieve the certificate and let ODM trust it.

As explained in Entra ID tutorial, you might need to let ODM trust the root Certificate Authority (CA) too. Entra ID currently uses [Digicert](https://www.digicert.com/) as root CA.

## #3 Missing or Invalid Allowed Domain List
### 3.1) Symptoms
The console is not accessible with an error code `HTTP 400`,
and the ODM log contains the following errors:
  - Decision Center
    ```
    com.ibm.rules.decisioncenter.web.core.filters.SecurityCheckPointFilter isRefererHeaderValid Invalid request [Referer - https://<external-idp-domain-name>/]{"method":"GET","URL":"https:\/\/<Decision_Center_URL>:443\/odm\/decisioncenter"}**
    ```
  - Decision Server Console
    ```
    console       W   An unauthorized access has been detected from <ORIGIN> because the security token is incorrect or the request contains an invalid referer header. The console is potentially under a Cross-site request forgery attack.
    ```

### 3.2) Cause
ODM features a referrer check that ignores requests whose origin is unexpected to prevent [CSRF attacks](https://portswigger.net/web-security/csrf).

To ensure a normal behaviour, the OpenID server domain must be configured as trusted to prevent ODM from ignoring requests redirected from it.

Some OpenID Connect Providers (such as Entra ID) may send requests from an enterprise portal, and that domain must be trusted as well.

### 3.3) Solution
Set the property `OPENID_ALLOWED_DOMAINS` to the OpenID server domain in the `openIdParameters.properties` file.

If needed, add other domains (eg. the enterprise portal). `OPENID_ALLOWED_DOMAINS` expects a comma-separated value, and wildcards (such as '*') are not accepted.


## #4 Authorization issue
### 4.1) Symptoms

- You have the `rtsAdministrator` role but the `Administration` tab is not displayed in the Business Console,
- or you cannot log in the Business Console at all (if the Helm chart parameter `decisionCenter.disableAllAuthenticatedUser` is set to `true`),
- or you have at least the `rtsMonitor` role, but you are unable to log in the RES console.

### 4.2) Causes

Such symptoms indicate that the role of users is not processed correctly:
- either because the mapping between groups and roles is missing in ODM,
- or the information in a token that tells which group the user belongs to (aka 'claim'), is missing or might have a different name than expected.

### 4.3) Solution

1) Check the role mappings in `webSecurity.xml`.

    You should find lines such as the one below that specifies which group is granted an ODM role:

    ```xml
    <variable name="odm.rtsAdministrators.group1" value="group:<OPENID_SERVER_URL_TO_REACH_THE_DEDICATED_GROUP>"/>
    ```

    The syntax to identify a group varies depending on the OpenID Connect Provider.

1) Check the name of the 'claim' in `openIdWebSecurity.xml`

    In the example below, ODM is configured to expect that the access tokens contain a claim named `groups` that lists all the groups that the authenticated user belongs to:

    ```
    <openidConnectClient authFilterRef="browserAuthFilter" id="odm" scope="openid"
                         groupIdentifier="groups"
                         ...
    />
    <openidConnectClient authFilterRef=apiAuthFilter" id="odmapi" scope="openid"
                         groupIdentifier="groups"
                         ...
    />
    ```

1) Check the token contains the expected claim and that its value is the list of groups that the user actually belongs to.

    You can check the content of a token either in the OpenId Connect Provider portal, or by:
    - retrieving an access token (by sending a request to the 'token' endpoint),
    - and decrypting the access token (using a JWT decoder tool).

    Our tutorials provide scripts enabling to retrieve an access token.

    Here is an example of a token containing a claim named `groups`:
    ```json
    {
      "exp": 1669040783,
      "iat": 1669040483,
      "auth_time": 1669040482,
      "jti": "4b49e91d-e80d-42a0-a51b-8c68779025e2",
      "iss": "https://keycloak-mattest.apps.ocp-psit-ado.cp.fyre.ibm.com/realms/odm",
      "aud": "odm",
      "sub": "1418ff49-8258-43f2-839b-5f2e11357827",
      "typ": "ID",
      "azp": "odm",
      "session_state": "d0625094-b449-41ab-ae03-3af800c6564a",
      "at_hash": "ygL3LNBshUa2mXl9ljKxYQ",
      "acr": "1",
      "sid": "d0625094-b449-41ab-ae03-3af800c6564a",
      "email_verified": true,
      "name": "John Doe",
      "groups": [
        "rtsConfigManagers",
        "resAdministrators",
        "resMonitors",
        "rtsAdministrators",
        "rtsInstallers",
        "resDeployers",
        "rtsUsers",
        "resExecutors"
      ],
      "preferred_username": "johndoe@mycompany.com",
      "given_name": "John",
      "family_name": "Doe",
      "email": "johndoe@mycompany.com"
    }
    ```

1) If needed, enable detailed traces (see [Enabling detailed traces](#2-enabling-detailed-traces))

    For instance, to troubleshoot an Authorization issue is Decision Center:

    * Modify the `traceSpecification` for Decision Center by adding `com.ibm.ws.security.*=all:com.ibm.ws.webcontainer.security.*=all` and apply the change,
    * Wait for the decisioncenter pod to take into account the change and have a look at the pod logs,
    * Try authenticating in the Business Console,
    * Redirect the Decision Center logs to a file by running `kubectl logs <DC_POD_NAME> > dc.log` because the Liberty logs are very verbose and hard to analyze  on the fly.
    * In the `dc.log` file, search for the pattern **groupIds=[**
    It should list all the groups the authenticated user belongs to.
    One of these groups must be granted a suitable ODM role according to the role mapping in the `webSecurity.xml`.

      Here is an example of a trace when the user John Doe authenticates (from the [Keycloak tutorial](./Keycloak/README.md)):

      ```
      Public Credential: com.ibm.ws.security.credentials.wscred.WSCredentialImpl@151c2134,
        realmName=KEYCLOAK_SERVER_URL,securityName=johndoe@mycompany.com,
          realmSecurityName=KEYCLOAK_SERVER_URL/johndoe@mycompany.com,
          uniqueSecurityName=johndoe@mycompany.com,primaryGroupId=null,
          accessId=user:KEYCLOAK_SERVER_URL/johndoe@mycompany.com,
          groupIds=[group:KEYCLOAK_SERVER_URL/rtsAdministrators,
          group:KEYCLOAK_SERVER_URL/rtsConfigManagers,
          group:KEYCLOAK_SERVER_URL/resAdministrators,
          group:KEYCLOAK_SERVER_URL/resMonitors,
          group:KEYCLOAK_SERVER_URL/rtsInstallers,
          group:KEYCLOAK_SERVER_URL/resDeployers,
          group:KEYCLOAK_SERVER_URL/rtsUsers,
          group:KEYCLOAK_SERVER_URL/resExecutors]
      ```

## #5 Proxy
### 5.1) Symptoms
The consoles are not accessible with an error code `HTTP 401` or display an error message such as:
```
server IP address could not be found.
Try:
  Checking the connection
  Checking the proxy, firewall, and DNS configuration
```

and the ODM logs contains an error `CWWKS1708E` such as:

```
CWWKS1708E: The OpenID Connect client [odm] is unable to
The OpenID Connect agent [...] is unable to contact the OpenID Connect provider at [.../token]
to receive an ID token due to [...: Name or service not known].
```
or
```
CWWKS1708E: The OpenID Connect client [odm] is unable to contact the OpenID Connect provider at [.../token] 
to receive an ID token due to [Failed to reach endpoint .../token because of the following error: <!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<html><head>
<title>404 Not Found</title>
</head><body>
<h1>Not Found</h1>
<p>The requested URL .../token was not found on this server.</p>
</body></html>].
````
### 5.2) Cause
A proxy is preventing to connect to the OpenId Connect Provider.

To confirm it, you can try sending a request to the OpenId Connect Provider using `curl` from a shell within the pod.
And if it fails, try again after defining environment variables enabling to pass the proxy to confirm that it solves the problem, ie:
```
export HTTP_PROXY="http://userName:yourPassword@yourProxyURL:port"
export HTTPS_PROXY="http://userName:yourPassword@yourProxyURL:port"
```

### 5.3) Solution
The solution is to define the hostname, port, username and password of the proxy as JVM parameters:
```
-Dhttps.proxyHost=<hostname>
-Dhttps.proxyPort=<port>
-Dhttps.proxyUser=<username>
-Dhttps.proxyPassword=<password>
```
This needs to be done for each ODM component as the JVM parameters are individually defined for each ODM component.

- For each ODM component:

  1. Retrieve the default JVM parameters from the ConfigMap automatically created and named `<RELEASE_NAME>-odm-<COMPONENT>-jvm-options-configmap` where `<COMPONENT>` is either `dc`, `dr`, `ds-console` or `ds-runtime`:
      ```
      kubectl get configmap <RELEASE_NAME>-odm-<COMPONENT>-jvm-options-configmap -o yaml > <COMPONENT>-jvm-options.yaml
      ```

  1. Edit the .yaml file to add the new JVM parameters above, and change its name to `my-odm-<COMPONENT>-jvm-options-configmap` for instance:
      ```
      kubectl apply -f <COMPONENT>-jvm-options.yaml
      ```

  1. Set the Helm chart parameter `jvmOptionsRef` for the ODM component:

      For instance, for Decision Center:
      ```
      decisionCenter:
        jvmOptionsRef: my-odm-dc-jvm-options-configmap
      ```

- Add the parameter `useSystemPropertiesForHttpClientConnections="true"` in both openIdConnectClient elements in `openIdWebSecurity.xml` and update the secret that contains that file.

- Then redeploy the chart.