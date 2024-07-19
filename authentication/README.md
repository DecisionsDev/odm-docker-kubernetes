<!-- TOC depthfrom:1 depthto:6 withlinks:false updateonsave:false orderedlist:false -->

- Troubleshooting
    - Missing or invalid redirect
    - Missing or invalid OpenID Server Certificate
    - Missing or Invalid Allowed Domain List
    - Authorization issue

<!-- /TOC -->

# Troubleshooting

You should not encounter any issue with the delivered OpenID tutorials because we generate the major configuration files.
However, you might encounter an issue when manually configuring IBM Operational Decision Manager (ODM) with OpenID.
We provide here the most common issues and how to solve them.

The list is obviously not exhaustive.
Do not hesitate to contact us if you face a specific issue that you think needs to be reported.

## Missing or invalid redirect

This error prevents you from accessing the login page.
When you try to access an ODM console, according to the OpenID Application Flow, the OpenID ODM application tries to reach a valid redirect URI.
As explained in the documentation, the redirects are:
  * https://<Decision_Center_URL>/decisioncenter/openid/redirect/odm for the Decision Center
  * https://<Decision_Server_Console_URL>/res/openid/redirect/odm for the Decision Server Console

If you forgot to provide a redirect URI or if you provide an invalid redirect URI, an error like **Invalid parameter: redirect_uri** is displayed in the browser.

## Missing or invalid OpenID Server Certificate

For almost all OpenID servers, the communication between ODM and the OpenID Server is secured with HTTPS.

If you forgot to provide a valid certificate, you get an exception in the browser like:

```json
{"error_description":"OpenID Connect client returned with status: SEND_401","error":401}
```
And in the ODM pod logs, you see:

```
CWPKI0823E: SSL HANDSHAKE FAILURE:  A signer with SubjectDN [CN=*.<OPENID_SERVER_DOMAIN>] was sent from the host [<OPENID_SERVER_URL>:443].
The signer   might need to be added to local trust store [/config/security/truststore.jks], located in SSL configuration alias [odmDefaultSSLConfig].
The extended  error message from the SSL handshake exception is: [unable to find valid certification path to requested target].
```

Pay attention, for some OpenID servers like Azure AD, you also have to provide a root Certificate Authority (CA). For Azure AD, the root CA currently is [Digicert](https://www.digicert.com/).

## Missing or Invalid Allowed Domain List

ODM uses a check referer mechanism to prevent [CSRF attack](https://portswigger.net/web-security/csrf).
So, you have to provide the allowed domains for ODM by using the property OPENID_ALLOWED_DOMAINS that is included in the openIdParameters.properties file.
In general, an allowed domain corresponds to the OpenID server name. However, in some contexts like Azure AD, the OpenID server redirects to an enterprise portal.
So, you must also provide the enterprise portal URL with the list of allowed domains. OPENID_ALLOWED_DOMAINS is a list of comma-separated values. Wildcard * is not accepted.
Here is how to identify this issue:

* Decision Center is not accessible and you see the following message in the pod logs:
```
com.ibm.rules.decisioncenter.web.core.filters.SecurityCheckPointFilter isRefererHeaderValid Invalid request [Referer - https://<external-idp-domain-name>/]{"method":"GET","URL":"https:\/\/<Decision_Center_URL>:443\/odm\/decisioncenter"}**
```
* Decision Server Console is not accessible

## Authorization issue

If you do not use the Helm chart property **decisionCenter.disableAllAuthenticatedUser=true**, you only need to be authenticated with the OpenID server to access Decision Center as rtsUser.
However, if you want to have access to the Administration tab in Decision Center, you must be authorized by Liberty to belong to the rtsAdministrators group.
This can be done through a mapping mechanism in the webSecurity.xml file:

```xml
<variable name="odm.rtsAdministrators.group1" value="group:<OPENID_SERVER_URL_TO_REACH_THE_DEDICATED_GROUP>"/>
```

The URL that provides the dedicated OpenID Server syntax group depends on the OpenID Server but also on the openIdConnectClient groupId property that you use with this OpenID Server. Azure AD uses ObjectId. For Keycloak, we advise to use roles.
If you encounter issues to be authorized, follow this advice:
* To debug the Liberty authorization mechanism when accessing Decision Center, choose one of the following options:
    * Edit the Decision Center logging configmap of the current release by adding:
        **com.ibm.ws.security.\*=all:com.ibm.ws.webcontainer.security.\*=all** to the Liberty logging.
    * Create the **my-dc-logging-configmap** Decision Center configmap using [dc-logging.yaml](./dc-logging.yaml) with the command:
            **kubectl apply -f dc-logging.xml**
      and attach it to the Helm deployment using
            **-set decisionCenter.loggingRef=my-dc-logging-configmap**
* To debug the Liberty authorization mechanism when accessing Decision Server Console, choose one of the following options:
    * Edit the Decision Server Console logging configmap of the current release by adding:
        **com.ibm.ws.security.\*=all:com.ibm.ws.webcontainer.security.\*=all** to the Liberty logging.
    * Create the **my-dsc-logging-configmap** Decision Server configmap using [dsc-logging.yaml](./dsc-logging.yaml) with the command:
            **kubectl apply -f dsc-logging.xml**
      and attach it to the Helm deployment using
            **-set decisionServerConsole.loggingRef=my-dsc-logging-configmap**
* Wait for the pod to take into account the change and have a look at the pod logs.
* Try authenticating with the Decision Server URL.
* Redirect the Decision Center logs to a file with kubectl logs <DC_POD_NAME> > dc.logs because the Liberty logs are very verbose and impossible to analyze  on the fly.
* In the dc.logs file, search for the pattern **groupIds=[**
It should list all the group names to which the logged user belongs.
The mapping in the webSecurity.xml file must precisely use one of these group names.

Here is an example from the [Keycloak tutorial](./Keycloak/README.md) that illustrates a John Doe authentication:

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

We used:

```xml
<variable name="odm.rtsAdministrators.group1" value="group:KEYCLOAK_SERVER_URL/rtsAdministrators"/>
```

If the list is empty, it means that Liberty did not find any group in the **id_token** provided by the openIdConnectClient **groupId** property in the openIdWebSecurity.xml file.
Check that:
* You used the relevant property name (e.g. groupId="groups").
* The **id_token** found in the Liberty logs contains the expected **groups** names.

For example, you can find in the logs:

```
Private Credential: {com.ibm.wsspi.security.cred.cacheKey=aSU1t4UsE/P1t6P2LEqhSNC5g7gxaQUYPoTr6XRuL6M=,
token_type=Bearer,
access_token=eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJVMVZadVY1S18zbWNGclprVnJFSGFnQWxDaWV2S0ZjOTNoLWVMQ2lMR2hrIn0.eyJleHAiOjE2NjkwNDA3ODMsImlhdCI6MTY2OTA0MDQ4MywiYXV0aF90aW1lIjoxNjY5MDQwNDgyLCJqdGkiOiI4OTgzNTAzZi0wMzMxLTQxMmUtYWI5MS0zZWE2Yjc0Nzc3ZTMiLCJpc3MiOiJodHRwczovL2tleWNsb2FrLW1hdHRlc3QuYXBwcy5vY3AtcHNpdC1hZG8uY3AuZnlyZS5pYm0uY29tL3JlYWxtcy9vZG0iLCJzdWIiOiIxNDE4ZmY0OS04MjU4LTQzZjItODM5Yi01ZjJlMTEzNTc4MjciLCJ0eXAiOiJCZWFyZXIiLCJhenAiOiJvZG0iLCJzZXNzaW9uX3N0YXRlIjoiZDA2MjUwOTQtYjQ0OS00MWFiLWFlMDMtM2FmODAwYzY1NjRhIiwiYWNyIjoiMSIsInJlYWxtX2FjY2VzcyI6eyJyb2xlcyI6WyJydHNDb25maWdNYW5hZ2VycyIsInJlc0FkbWluaXN0cmF0b3JzIiwicmVzTW9uaXRvcnMiLCJydHNBZG1pbmlzdHJhdG9ycyIsInJ0c0luc3RhbGxlcnMiLCJyZXNEZXBsb3llcnMiLCJydHNVc2VycyIsInJlc0V4ZWN1dG9ycyJdfSwic2NvcGUiOiJvcGVuaWQgZW1haWwgcHJvZmlsZSIsInNpZCI6ImQwNjI1MDk0LWI0NDktNDFhYi1hZTAzLTNhZjgwMGM2NTY0YSIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJuYW1lIjoiSm9obiBEb2UiLCJncm91cHMiOlsicnRzQ29uZmlnTWFuYWdlcnMiLCJyZXNBZG1pbmlzdHJhdG9ycyIsInJlc01vbml0b3JzIiwicnRzQWRtaW5pc3RyYXRvcnMiLCJydHNJbnN0YWxsZXJzIiwicmVzRGVwbG95ZXJzIiwicnRzVXNlcnMiLCJyZXNFeGVjdXRvcnMiXSwicHJlZmVycmVkX3VzZXJuYW1lIjoiam9obmRvZUBteWNvbXBhbnkuY29tIiwiZ2l2ZW5fbmFtZSI6IkpvaG4iLCJmYW1pbHlfbmFtZSI6IkRvZSIsImVtYWlsIjoiam9obmRvZUBteWNvbXBhbnkuY29tIn0.HlgkXl5lrqBSxUwbvvPxE4gjmXk2jt1R5WLSUfwUtJSjrJNfkAScteTlvXf0uR4gGtdqeVznGCuwr0F88zKTXimKp1sIbCWIzsVzKrvPSG_VzlvJs-AHstXOGmfQSds2igQiXJWBXyaxnGV74cAlrrIZ7nwFRoeDmLgMhjFgcQ8aaF0-oZKZEye3DR7a0cqboSpYj1qD2ro9DGXeNTeB6-naPquWm83TLKBIlfXPY7Izf4DyZLqNoKhMp7xGX7D8fe6ozfYKJ3EwLLvEA9mOldJC-xomvcGwvMeeUCIE4m_9P0s-crVnUgecvdwM4wR0lCX83rnSwqCZWQUHwl8mtg,
com.ibm.ws.authentication.internal.assertion=true,
com.ibm.wssi.security.oidc.client.credential.storing.utc.time.milliseconds=1669040483111,
id_token=eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJVMVZadVY1S18zbWNGclprVnJFSGFnQWxDaWV2S0ZjOTNoLWVMQ2lMR2hrIn0.eyJleHAiOjE2NjkwNDA3ODMsImlhdCI6MTY2OTA0MDQ4MywiYXV0aF90aW1lIjoxNjY5MDQwNDgyLCJqdGkiOiI0YjQ5ZTkxZC1lODBkLTQyYTAtYTUxYi04YzY4Nzc5MDI1ZTIiLCJpc3MiOiJodHRwczovL2tleWNsb2FrLW1hdHRlc3QuYXBwcy5vY3AtcHNpdC1hZG8uY3AuZnlyZS5pYm0uY29tL3JlYWxtcy9vZG0iLCJhdWQiOiJvZG0iLCJzdWIiOiIxNDE4ZmY0OS04MjU4LTQzZjItODM5Yi01ZjJlMTEzNTc4MjciLCJ0eXAiOiJJRCIsImF6cCI6Im9kbSIsInNlc3Npb25fc3RhdGUiOiJkMDYyNTA5NC1iNDQ5LTQxYWItYWUwMy0zYWY4MDBjNjU2NGEiLCJhdF9oYXNoIjoieWdMM0xOQnNoVWEybVhsOWxqS3hZUSIsImFjciI6IjEiLCJzaWQiOiJkMDYyNTA5NC1iNDQ5LTQxYWItYWUwMy0zYWY4MDBjNjU2NGEiLCJlbWFpbF92ZXJpZmllZCI6dHJ1ZSwibmFtZSI6IkpvaG4gRG9lIiwiZ3JvdXBzIjpbInJ0c0NvbmZpZ01hbmFnZXJzIiwicmVzQWRtaW5pc3RyYXRvcnMiLCJyZXNNb25pdG9ycyIsInJ0c0FkbWluaXN0cmF0b3JzIiwicnRzSW5zdGFsbGVycyIsInJlc0RlcGxveWVycyIsInJ0c1VzZXJzIiwicmVzRXhlY3V0b3JzIl0sInByZWZlcnJlZF91c2VybmFtZSI6ImpvaG5kb2VAbXljb21wYW55LmNvbSIsImdpdmVuX25hbWUiOiJKb2huIiwiZmFtaWx5X25hbWUiOiJEb2UiLCJlbWFpbCI6ImpvaG5kb2VAbXljb21wYW55LmNvbSJ9.NBbZPp6Mymve3mLVyE0zKgW-yN1VZvZ5FnmpP93ImMDtMc2yYRw9wxZzQ_eZLsAulyR-SlkxIWhMESKcoIKW8Scm23rJembUgyfJ82btGBGAOIXAQDtN7rnGq4_6U6gUaUA7OIswErii4zG3GmXSLu3COBsAIYRaIPtGc_X1OM-bfc9jeGI8H2yK8y9MnlsvTTRaNT6YRNja-yuQKcVe3dukDb7hL5FvBCAWjWnZ0bocQobeYuXp3xV8I8j4z3hC-HAPmvSrgHOEJhokPNKlBfnACE4-1TFzu5fJQztbb8MfzCwVzvpLTmkTdTe3NMk7UDnrUYLfGtiGarGuOOAUYw, ...
```

Introspecting the **id_token** with [https://jwt.io](https://jwt.io), you should get:

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
