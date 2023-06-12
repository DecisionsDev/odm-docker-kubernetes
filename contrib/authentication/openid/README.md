# Configuring user access with external OIDC providers

In the context of the IBM Cloud Pak for Business Automation, Operational Decision Manager for production can be configured with an external OpenID Connect server (OIDC Provider). You must set `oidc.external_server` to true, in your custom resource file.

## Before you begin

You must configure a basic or LDAP authentication registry for your ODM services before you can configure ODM with an OIDC provider. To understand better ODM roles, see [Understanding user roles and user groups](https://ibmdocs-test.dcs.ibm.com/docs/cloud-paks/cp-biz-automation/21.0.x?topic=access-understanding-user-roles-user-groups).

ODM uses hardcoded roles with three users and three groups for each role. All authenticated users have by default the `rtsUser` role.

The following lines show the ODM configuration.

```xml
rtsAdministrators:
<user name="rtsAdmUser1" access-id="${odm.rtsAdministrators.user1}"/>
<user name="rtsAdmUser2" access-id="${odm.rtsAministrators.user2}"/>
<user name="rtsAdmUser3" access-id="${odm.rtsAdministrators.user3}"/>
<group name="rtsAdmGroup1" access-id="${odm.rtsAdministrators.group1}"/>
<group name="rtsAdmGroup2" access-id="${odm.rtsAdministrators.group2}"/>
<group name="rtsAdmGroup3" access-id="${odm.rtsAdministrators.group3}"/>
```

Similar users and groups exist for the other roles `rtsConfigManagers`, `resAdministrators`, `resExecutors`, `resMonitors`, and `resDeployers`. You can find an example in the [configuration](../../../configuration/security) folder.

## About this task

You need to create a number of secrets before you can install an ODM instance with an external OIDC provider and use web application single sign-on (SSO). The following diagram shows the ODM services with an external OIDC provider after a successful installation.

![ODM web application SSO](images/diag_oidc_interaction.jpg)

The following procedure describes how to manually configure ODM with an external OpenID Connect server. You must define the mapping between the liberty roles and the LDAP groups by creating a secret and reference it in the customization.authSecretRef parameter.

## Procedure

1.  Create a secret that maps groups to the ODM roles.

    This secret grants user access to the ODM services with an external OIDC provider.

    - Create a webSecurity.xml file to define the mapping to the OIDC groups.

      See the [configuration](../../../configuration/security) folder on how to put all of the definitions that your environment needs into the webSecurity.xml file.

    - Create a secret for the webSecurity.xml file.

      > Note: The secret must be registered with the webSecurity.xml key. If you did use a different file name, for example sample-webSecurity-OIDC.xml, you can still register it by specifying your file name when you create the secret.
      >```
      >kubectl create secret generic <my-websecurity-secret> \
      >        --from-file=webSecurity.xml=<path_to_your_file>/sample-webSecurity-OIDC.xml
      > ```

      Make sure that you create the secret in the same namespace as the namespace that you use for the ODM instance. To create the secret, use the following command.

      ```
      kubectl create secret generic <my-websecurity-secret> --from-file=webSecurity.xml
      ```

      Where <my-websecurity-secret\> is the name that you give to the secret.

    Make a note of the secret name so that you can set the customization.authSecretRef parameter in the configuration of your ODM instance.

    When the custom resource is deployed, you can edit this file in the secret `<namespace>-odm-oidc-auth-operator-secret` to change the authorization configuration.

2.  Set the external OpenID provider parameters in the custom resource to true.

    ```yaml
    odm_configuration:
      oidc:
         enabled: true
         external_server: true
    ```

3.  Provide the certificate of the OpenID server.

    For more information, see [Importing the certificate of an external service](https://ibmdocs-test.dcs.ibm.com/docs/cloud-paks/cp-biz-automation/21.0.x?topic=services-importing-certificate-external-service).

4.  Provide the URL of the external OpenID server.

    ```yaml
    odm_configuration:
      oidc:
         serverUrl: my-openid-serverUrl
    ```

5.  To protect Decision Center and Decision Server Console against CSRF attacks, provide the allowed domains list (separated by a comma) that can be used to access ODM consoles. Generally, the minimal domain contains the OpenID server URL (without https://).

    ```yaml
    odm_configuration:
      oidc:
         allowedDomains: my-openid-alloweddomains
    ```

6.  Provide the name of the OpenID provider.

    > Note: If not provided, "`ums`" is set.

    ``` { .prettyprint .language-yaml}
    odm_configuration:
      oidc:
         provider: my-openid-provider
    ```

7.  Create a secret with an OpenID client ID and password to request the authentication token from the OpenID instance.

    ```
    kubectl create secret generic my_openid_clientid_secret \
       --from-literal=clientId=MY-OPENID-CLIENT-ID \
       --from-literal=clientSecret=MY-OPENID-CLIENT-SECRET
    ```

    If not provided, a secret is generated by using some default values: `clientId=<namespace>-odm-oidc-client-id-secret` and `clientSecret=<namespace>-odm-oidc-client-id-secret-value`.

    ```yaml
    odm_configuration:
      oidc:
         clientRef: my_openid_clientid_secret
    ```

8.  To make the ODM URLs accessible, a list of URLs must be registered to the OpenID server.

    For more information, see [OpenID Connect Dynamic Client Registration](https://openid.net/specs/openid-connect-registration-1_0-17.html).

    A job automatically registers the redirect URL on the OpenID server when UMS is the provider (`oidc.provider: "ums"`). The job contains some cURL scripts that are compatible only with a UMS provider. If you are using Okta, Keycloak, or another OpenID provider, you need to register the redirect manually. To manage the registration, you must create an OpenID administrator secret.

    The administrator secret is used to call the OpenID REST API to register the URLs of the ODM services. The registration process can provide useful information for the ODM services, including the OAuth 2.0 client ID and client secret.

    You create a secret by running the following command.

    ```
    kubectl create secret generic my_openid_admin_secret \
      --from-literal=adminUser=OPENID-ADMIN-USERNAME \
      --from-literal=adminPassword=OPENID-ADMIN-PASSWORD
    ```

    Then, set the secret name in the CR file.

    ```yaml
    odm_configuration:
      oidc:
         adminRef: my_openid_admin_secret
    ```

## Advanced configuration
### [Optional] Configure OIDC endpoints
If you need to modify the OIDC endpoints or the token format, because the template is not compatible, you can create your own openIdParameters.properties file and provide it to the ODM instance.

   * Create the properties file with the following formatting.

    ```
    OPENID_SERVER_URL=<oidc.serverUrl>
    OPENID_PROVIDER=<oidc.provider>
    OPENID_CLIENT_ID=OPENID_CLIENT_ID # provided or generated
    OPENID_CLIENT_SECRET=OPENID_CLIENT_SECRET # provided or generated
    OPENID_ALLOWED_DOMAINS=<oidc.allowedDomains>
    OPENID_AUTHORIZATION_URL=<oidc.serverUrl>/oidc/endpoint/<oidc.provider>/authorize
    OPENID_TOKEN_URL=<oidc.serverUrl>/oidc/endpoint/<oidc.provider>/token
    OPENID_INTROSPECTION_URL=<oidc.serverUrl>/oidc/endpoint/<oidc.provider>/introspect
    OPENID_LOGOUT_URL=<oidc.serverUrl>/oidc/endpoint/<oidc.provider>/logout
    OPENID_TOKEN_FORMAT=NON-JWT
    ```

    > Note: If OPENID_CLIENT_ID and OPENID_CLIENT_SECRET are left blank, the values are replaced by the oidc.clientRef secret values.

   * Re-create the secret <my-websecurity-secret\> with the openIdParameters.properties file, and apply the change.

    ```
    kubectl create secret generic <my-websecurity-secret>
            --from-file=webSecurity.xml=webSecurity.xml
            --from-file=openIdParameters.properties=openIdParameters.properties

    kubectl apply -f custom_resource.yaml
    ```

### [Optional] Changing Liberty Openid configuration
If you need to add or modify a parameter to the `openidConnectClient` tag in the openIdWebSecurity.xml file, you can write your own file and provide it to the ODM instance.

   * Create the XML file with the following formatting.

    ```xml
    <server>
      <variable name="ServerHost" value="<oidc.serverUrl>"/>
      <openidConnectClient authFilterRef="browserAuthFilter" id="odm" scope="openid"
                           clientId="OPENID_CLIENT_ID" clientSecret="OPENID_CLIENT_SECRET"
                           signatureAlgorithm="RS256" inboundPropagation="supported"
                           jwkEndpointUrl="${ServerHost}/oidc/endpoint/<oidc.provider>/jwk"
                           issuerIdentifier="${ServerHost}/oidc/endpoint/<oidc.provider>"
                           authorizationEndpointUrl="${ServerHost}/oidc/endpoint/<oidc.provider>/authorize"
                           tokenEndpointUrl="${ServerHost}/oidc/endpoint/<oidc.provider>/token"
                           validationEndpointUrl="${ServerHost}/oidc/endpoint/<oidc.provider>/introspect"/>
      <openidConnectClient authFilterRef="apiAuthFilter" id="odmapi" scope="openid"
                           clientId="__OPENID_CLIENT_ID__" clientSecret="__OPENID_CLIENT_SECRET__"
                           signatureAlgorithm="RS256" inboundPropagation="required"
                           jwkEndpointUrl="${ServerHost}/oidc/endpoint/<oidc.provider>/jwk"
                           issuerIdentifier="${ServerHost}/oidc/endpoint/<oidc.provider>"
                           authorizationEndpointUrl="${ServerHost}/oidc/endpoint/<oidc.provider>/authorize"
                           tokenEndpointUrl="${ServerHost}/oidc/endpoint/<oidc.provider>/token"
                           validationEndpointUrl="${ServerHost}/oidc/endpoint/<oidc.provider>/introspect"/>
    </server>
    ```

    > Note: The **authFilterRef**, **id**, and **inboundPropagation** values must not be modified, as they are used internally. If **clientId** and **clientSecret** are left blank, the values are replaced by the oidc.clientRef secret values.

   * Re-create the secret <my-websecurity-secret\>, add the openIdWebSecurity.xml file, and apply the change.

    ```
    kubectl create secret generic <my-websecurity-secret>
            --from-file=webSecurity.xml=webSecurity.xml
            --from-file=openIdWebSecurity.xml=openIdWebSecurity.xml

    kubectl apply -f custom_resource.yaml
    ```

    For more information about Liberty endpoints, see [OpenID Connect endpoint URLs](https://ibmdocs-test.dcs.ibm.com/docs/en/was-liberty/zos?topic=connect-openid-endpoint-urls).


## Results

- [Optional] To use an external OIDC provider with Rule Designer, see [Configuring Rule Designer](https://ibmdocs-test.dcs.ibm.com/docs/en/odm/8.12.0?topic=parties-configuring-rule-designer).

  You must import the security certificate that is used in the ODM instance into Rule Designer. For more information, see [Importing a security certificate in Rule Designer](https://ibmdocs-test.dcs.ibm.com/docs/en/cloud-paks/cp-biz-automation/21.0.x?topic=designer-importing-security-certificate-in-rule). To provide the truststore.jks file to the eclipse.ini, you can identify the ODM pods with the `oc get pods | grep odm` command, and then copy the file by running the `oc cp` command.

  ```
  oc cp <project name>/<ODM pod name>:/config/security/truststore.jks ./truststore.jks
  ```

  The default password of the provided truststore.jks file is `changeit`. The clientId and clientSecret parameters can be set in Step 7 of the procedure.

  If you did not provide client credentials, an ID and password is created for you with the values `clientId=<CR_NAME>-odm-oidc-client-id` and `clientSecret=<CR_NAME>-odm-oidc-client-id-secret-value`. You need these values so that you can connect Rule Designer as a client.

> Note: The access token is validated for all requests. The validation process has an impact on the Decision Server Runtime performance. To improve the performance, `LtpaToken` cookies are enabled in the `openidConnectClient` Liberty configuration to manage the token. However, for demanding applications that require high performance, `LtpaToken` cookies are sometimes not enough. In this case, use basic authentication to call the Decision Server Runtime.
> The Liberty OpenID configuration contains a parameter that manages basic authentication. The default configuration in webSecurity.xml provides a basic registry with a resExecutor user that has the resExecutors role, as illustrated in the following code sample.
> ```xml
> <server>
>       <basicRegistry id="basic" realm="basic">
>         <user name="resExecutor" password="resExecutor"/>
>         <group name="basicResExecutors">
>           <member name="resExecutor" />
>         </group>
>       </basicRegistry>
>       <variable name="odm.resExecutors.group1" value="group:basic/basicResExecutors"/>
> </server>
> ```
> So you can call a decision service like this:
> ```
> curl -H "Content-Type: application/json" -k --data @loanvalidation.json \
>      -H "Authorization: Basic cmVzRXhlY3V0b3I6cmVzRXhlY3V0b3I=" \
>      https://DecisionServerRuntime:Port/DecisionService/rest/LoanValidationDS/1.0/loan_validation_with_score_and_grade/1.0
> ```
> Where `cmVzRXhlY3V0b3I6cmVzRXhlY3V0b3I=` is the base64 encoding of the current username:password resExecutor:resExecutor
>
> You can modify the default basic registry, users, and groups by modifying the webSecurity.xml file.

- If you want to call the REST API, you must get an access token by running a cURL command with the following endpoint:
`https://<oidc.serverUrl\>/oidc/endpoint/<oidc.provider\>/token`.

  You can then authenticate with the "Bearer <access-token\>". For more information, see [How a Liberty-based application obtains an access token from UMS SSO](con_ums_sso_liberty.dita).

  The following diagram shows the API invocations with an external OIDC provider.

  ![ODM service API invocations](images/diag_oidc_other_interaction_api.jpg)

  For more information, see [Invoking the Token Endpoint for OpenID Connect](https://ibmdocs-test.dcs.ibm.com/docs/en/was-liberty/zos?topic=liberty-invoking-token-endpoint-openid-connect).

- The following OIDC groups provide an example of how to map these ODM roles.
  -   oidcFullAccess, a group to manage all ODM roles.
  -   oidcRtsAdministrator, a group for the `rtsAdministrators` role.
  -   oidcRtsConfigManager, a group for the `rtsConfigManagers` role.
  -   oidcRtsInstaller, a group for the `rtsInstallers` role.
  -   oidcResAdministrator, a group for the `resAdministrators` role.
  -   oidcResMonitor, a group for the `resMonitors` role.
  -   oidcResExecutor, a group for the `resExecutors` role.
  -   oidcResDeployer, a group for the `resDeployers` role.

  The users and groups must be defined in the OpenID server. The names that you intend to use must exist in an associated registry so that they can be mapped to an ODM user or group.

- The following OpenID server definition shows an example of this mapping with a group `group:o=defaultWIMFileBasedRealm/oidcAllRoles` defined in a basic registry, and a group `group:o=defaultWIMFileBasedRealm/cn=oidcRtsAdministrator,ou=memberlist,ou=examplegroups,o=example.org` defined in an LDAP registry.

  ```xml
  <server>
      <federatedRepository id="vmm">
          <primaryRealm name="o=defaultWIMFileBasedRealm">
              <participatingBaseEntry name="o=BasicRegistry"/>
              <participatingBaseEntry name="o=example.org"/>
          </primaryRealm>
      </federatedRepository>
      <basicRegistry id="basicRegistry">
      <!-- User with full access through oidcAllRoles group -->
          <user name="odmAdmin" password="odmAdmin" />
      <!-- Group that has full access -->
          <group name="oidcAllRoles">
              <member name="odmAdmin" />
         </group>
      </basicRegistry>
      <ldapRegistry baseDN="o=example.org" host="mydomain.example.org"
          id="bp" ldapType="IBM Security Directory Server" port="389">
          <ldapEntityType name="PersonAccount">
              <objectClass>mycompanyPerson</objectClass>
              <searchBase>ou=mydomain,o=example.org</searchBase>
          </ldapEntityType>
          <ldapEntityType name="Group">
              <objectClass>groupOfUniqueNames</objectClass>
              <searchBase>ou=memberlist,ou=examplegroups,o=example.org</searchBase>
          </ldapEntityType>
          <idsFilters userFilter="(&amp;(objectclass=Person)(|(uid=%v)(mail=%v)))"
              groupFilter="(&amp;(cn=%v)(objectclass=groupOfUniqueNames))"
              groupMemberIdMap="groupOfUniqueNames:uniqueMember" />
     </ldapRegistry>
  </server>
  ```

  The mapping itself is done with variable definitions and key-value pairs. A cert-kubernetes/ODM/configuration/security/sample-webSecurity-OIDC.xml file can be used as a starting point to map your ODM users and groups to the users and groups. For more information about downloading cert-kubernetes, see [Preparing for an Enterprise deployment](../../com.ibm.dba.install/op_topics/tsk_prep_operator.html). The variable definitions in the sample file use the following scenario:

  -   A user `generalAdmin` (defined through an LDAP registry). A user that has access to all applications.
  -   A group `oidcAllRoles` (defined through a basic registry). A group of users that has access to all applications.
  -   A group `oidcRtsAdministrator` (defined through an LDAP registry). A group of users that has admin access to Decision Center.
  -   A group `oidcRtsConfigmanager` (defined through an LDAP registry). A group of users that can configure deployments in Decision Center.
  -   A group `oidcResAdministrator` (defined through an LDAP registry). A group of users that has admin access to Decision Server console.
  -   A group `oidcResDeployer` (defined through an LDAP registry). A group of users that can deploy in Decision Server console.
  -   A group `oidcResMonitor` (defined through an LDAP registry). A group of users that can monitor Decision Server console.
  -   A group `oidcResExecutor` (defined through an LDAP registry). A group of users that can execute decisions in Decision Server Runtime.

## Related information

- [Configuring user access with UMS](https://ibmdocs-test.dcs.ibm.com/docs/cloud-paks/cp-biz-automation/21.0.x?topic=access-configuring-user-ums)

- [Configuring user access](https://ibmdocs-test.dcs.ibm.com/docs/cloud-paks/cp-biz-automation/21.0.x?topic=manager-configuring-user-access)

- [ODM configuration parameters](https://ibmdocs-test.dcs.ibm.com/docs/cloud-paks/cp-biz-automation/21.0.x?topic=parameters-operational-decision-manager)

- [Preparing to install ODM](https://ibmdocs-test.dcs.ibm.com/docs/cloud-paks/cp-biz-automation/21.0.x?topic=capabilities-preparing-install-operational-decision-manager)

- [User Management Services](https://ibmdocs-test.dcs.ibm.com/docs/en/cloud-paks/cp-biz-automation/21.0.x?topic=services-ums-single-sign)
