# Set up a Microsoft Entra ID application using a client secret

<!-- TOC -->

- [Set up a Microsoft Entra ID application using a client secret](#set-up-an-microsoft-entra-id-application-using-a-client-secret)
- [Deploy ODM on a container configured with Microsoft Entra ID Part 2](#deploy-odm-on-a-container-configured-with-microsoft-entra-id-part-2)
    - [Prepare your environment for the ODM installation](#prepare-your-environment-for-the-odm-installation)
        - [Create a secret to use the Entitled Registry](#create-a-secret-to-use-the-entitled-registry)
        - [Create secrets to configure ODM with Microsoft Entra ID](#create-secrets-to-configure-odm-with-microsoft-entra-id)
    - [Install your ODM Helm release](#install-your-odm-helm-release)
        - [Add the public IBM Helm charts repository](#add-the-public-ibm-helm-charts-repository)
        - [Check that you can access the ODM chart](#check-that-you-can-access-the-odm-chart)
        - [Run the helm install command](#run-the-helm-install-command)
            - [a. Installation on OpenShift using Routes](#a-installation-on-openshift-using-routes)
            - [b. Installation using Ingress](#b-installation-using-ingress)
    - [Complete post-deployment tasks](#complete-post-deployment-tasks)
        - [Register the ODM redirect URLs](#register-the-odm-redirect-urls)
        - [Access the ODM services](#access-the-odm-services)
        - [Set up Rule Designer](#set-up-rule-designer)
        - [Getting Started with IBM Operational Decision Manager for Containers](#getting-started-with-ibm-operational-decision-manager-for-containers)
        - [Calling the ODM Runtime Service](#calling-the-odm-runtime-service)
- [Troubleshooting](#troubleshooting)
- [License](#license)

<!-- /TOC -->

1. Create the *ODM application*.

    In **Azure Active Directory** / **App registration**, click **New Registration**:

    * Name: **ODM Application**
    * Supported account types / Who can use this application or access this API?: select `Accounts in this organizational directory only (Default Directory only - Single tenant)`
    * Click **Register**

    ![New Web Application](images/RegisterApp.png)

2. Retrieve Tenant and Client information.

    In **Azure Active Directory** / **App Registration**, select **ODM Application** and click **Overview**:

    * Application (client) ID: **Client ID**. It will be referenced as `CLIENT_ID` in the next steps.
    * Directory (tenant) ID: **Your Tenant ID**. It will be referenced as `TENANT_ID` in the next steps.

    ![Tenant ID](images/GetTenantID.png)

3. Generate an OpenID client secret.

    In **Azure Active Directory** / **App registrations**, select **ODM Application**:

    * From the Overview page, click on the link Client credentials: **Add a certificate or secret** or on the **Manage / Certificates & secrets** tab
    * Click + New Client Secret
      * Description: `For ODM integration`
      * Click Add

   * Take note of the **Value**. It will be referenced as `CLIENT_SECRET` in the next steps.

   >Important: This client secret can not be revealed later. If you forgot to take note of it, you'll have to create another one.

4. Add Claims.

    In **Azure Active Directory** / **App registrations**, select **ODM Application**, and in **Manage / Token Configuration**:

  * Add Optional Email ID Claim
    * Click +Add optional claim
    * Select ID
    * Check Email
    * Click Add

  * Add Optional Email Access Claim
    * Click +Add optional claim
    * Select Access
    * Check Email
    * Click Add

    * Turn on Microsoft Graph email permission
      * Check Turn on the Microsoft Graph email permission
      * Click Add

  * Add Group Claim
    * Click +Add groups claim
    * Check Security Groups
    * Click Add

5. Create a custom claim named "identity"

   To allow ODM rest-api to use the password flow with email as user identifier and the client-credentials flow with client_id as user identifier, we need to create a new claim named "identity" that will take the relevant value according to the flow:

   In **Azure Active Directory** / **Enterprise applications**, select **ODM Application**, and in **Manage / Single sign-on**:

  * Click Edit in the "Attributes & Claims" section
    * Click + Add new claim
      * Name: identity
      * Fill 2 Claim conditions in the exact following order:
        1. User Type: Any / Scoped Groups: 0 / Source: Attribute / Value: <CLIENT_ID>
        2. User Type: Members / Scoped Groups: 0 / Source: Attribute / Value: user.mail
    * Click Save

6. API Permissions.

    In **Azure Active Directory** / **App Registration**, select **ODM Application**, and then click **API Permissions**.

    * Click Grant Admin Consent for Default Directory

    [Optional] If you are interested by the groups and users synchronization in the Business Console, you have to add some specific permission to allow Microsoft Graph Rest API Usage like :

    * Click on **Add a permission**, select **Application permissions** and choose **Group.Read.All**, **User.Read.All**
    * Don't forget to **Grant Admin Consent for Default Directory** on these API permissions 
    

7. Manifest change.

    In **Azure Active Directory** / **App Registration**, select **ODM Application**, and then click **Manifest**.

    As explained in [accessTokenAcceptedVersion attribute explanation](https://docs.microsoft.com/en-us/azure/active-directory/develop/reference-app-manifest#accesstokenacceptedversion-attribute), change the value to 2.

    ODM OpenID Liberty configuration needs version 2.0 for the issuerIdentifier. See the [openIdWebSecurity.xml](templates/openIdWebSecurity.xml) file.

    It is also necessary to set **acceptMappedClaims** to true to manage claims. Without this setting, you get the exception **AADSTS50146: This application is required to be configured with an application-specific signing key. It is either not configured with one, or the key has expired or is not yet valid.** when requesting a token.

   Then, click Save.

8. Check the configuration.

    Download the [azuread-odm-script.zip](azuread-odm-script.zip) file to your machine and unzip it in your working directory. This .zip file contains scripts and templates to verify and set up ODM.

    8.1 Verify the token issued using the 'Client Credentials' flow

    You can request an access token using the Client-Credentials flow to verify the token format.
    This token is used for the deployment between Decision Center and the Decision Server console:

    ```shell
    $ ./get-client-credential-token.sh -i <CLIENT_ID> -x <CLIENT_SECRET> -n <TENANT_ID>
    ```

    Where:

    - *TENANT_ID* and *CLIENT_ID* have been obtained from 'Retrieve Tenant and Client information' section.
    - *CLIENT_SECRET* is listed in your ODM Application, section **General** / **Client Credentials**

    You should get a token and by introspecting its value with [this online tool](https://jwt.ms) or with some [JWT cli](https://github.com/mike-engel/jwt-cli) you should get:

    **Token header**
    ```json
    {
      "typ": "JWT",
      "alg": "RS256",
      "kid": "-KI3Q9nNR7bRofxmeZoXqbHZGew"
    }
    ```

    **Token claims**
    ```json
    {
      "aud": "<CLIENT_ID>",
      "identity": "<CLIENT_ID>",
      ...
      "iss": "https://login.microsoftonline.com/<TENANT_ID>/v2.0",
      ...
      "ver": "2.0"
    }
    ```

    - *aud*: should be your CLIENT_ID
    - *identity*: should be your CLIENT_ID
    - *iss*: should end with 2.0. otherwise you should verify the previous step **Manifest change**
    - *ver*: should be 2.0. otherwise you should verify the previous step **Manifest change**

    8.2 Verify the token issued using the 'Password Credentials' flow

   To check that it has been correctly taken into account, you can request an ID token using the Password Credentials flow.

   This token is used for the invocation of the ODM components like Decision Center, Decision Servcer console, and the invocation of the Decision Server Runtime REST API.

    ```shell
    $ ./get-user-password-token.sh -i <CLIENT_ID> -x <CLIENT_SECRET> -n <TENANT_ID> -u <USERNAME> -p <PASSWORD>
    ```

   Where:

    - *TENANT_ID* and *CLIENT_ID* have been obtained from 'Retrieve Tenant and Client information' section.
    - *CLIENT_SECRET* is listed in your ODM Application, section **General** / **Client Credentials**
    - *USERNAME* and *PASSWORD* have been created from 'Create at least one user that belongs to this new group.' section.

     By introspecting the token value with this online tool [https://jwt.ms](https://jwt.ms), you should get:

    ```json
    {
      "aud": "<CLIENT_ID>",
      "iss": "https://login.microsoftonline.com/<TENANT_ID>/v2.0",
      ...
      "email": "<USERNAME>",
      "groups": [
        "<GROUP>"
      ],
      ...
      "ver": "2.0",
      "identity": "<USERNAME>"
    }
    ```

    Verify:
    - *aud*: should be your CLIENT_ID
    - *iss*: should end with 2.0. Otherwise you should verify the previous step **Manifest change**
    - *email*: should be present. Otherwise you should verify the creation of your user and fill the Email field.
    - *groups*: should contain your GROUP_ID
    - *ver*: should be 2.0. Otherwise you should verify the previous step **Manifest change**
    - *identity*: should be the user's email/username

  > If this command failed, try to log in to the [Azure portal](https://portal.azure.com/). You may have to enable 2FA and/or change the password for the first time.

# Deploy ODM on a container configured with Microsoft Entra ID (Part 2)

## Prepare your environment for the ODM installation

### Create a secret to use the Entitled Registry

1. To get your entitlement key, log in to [MyIBM Container Software Library](https://myibm.ibm.com/products-services/containerlibrary) with the IBMid and password that are associated with the entitled software.

    In the **Container software library** tile, verify your entitlement on the **View library** page, and then go to **Get entitlement key**  to retrieve the key.

2. Create a pull secret by running a `kubectl create secret` command.

    ```shell
    $ kubectl create secret docker-registry icregistry-secret \
        --docker-server=cp.icr.io \
        --docker-username=cp \
        --docker-password="<API_KEY_GENERATED>" \
        --docker-email=<USER_EMAIL>
    ```

    Where:

    - *API_KEY_GENERATED* is the entitlement key from the previous step. Make sure you enclose the key in double-quotes.
    - *USER_EMAIL* is the email address associated with your IBMid.

    > Note: The **cp.icr.io** value for the docker-server parameter is the only registry domain name that contains the images. You must set the *docker-username* to **cp** to use an entitlement key as *docker-password*.

3. Make a note of the secret name so that you can set it for the **image.pullSecrets** parameter when you run a helm install of your containers. The **image.repository** parameter is later set to *cp.icr.io/cp/cp4a/odm*.

### Create secrets to configure ODM with Microsoft Entra ID

1. Create a secret with the Microsoft Entra ID Server certificate.

    To allow ODM services to access the Microsoft Entra ID Server, it is mandatory to provide the Microsoft Entra ID Server certificate.
    You can create the secret as follows:

    ```shell
    keytool -printcert -sslserver login.microsoftonline.com -rfc > microsoft.crt
    kubectl create secret generic ms-secret --from-file=tls.crt=microsoft.crt
    ```

    Introspecting the Microsoft Entra ID login.microsoftonline.com certificate, you can see it has been signed by the Digicert Root CA authorithy.

    So we will also add the DigiCert Global Root CA from [this page](https://www.digicert.com/kb/digicert-root-certificates.htm):

    ```shell
    curl --silent --remote-name https://cacerts.digicert.com/DigiCertGlobalRootCA.crt.pem
    kubectl create secret generic digicert-secret --from-file=tls.crt=DigiCertGlobalRootCA.crt.pem
    ```

2. Generate the ODM configuration file for Microsoft Entra ID.

    If you have not yet done so, download the [azuread-odm-script.zip](azuread-odm-script.zip) file to your machine. This archive contains the [script](generateTemplate.sh) and the content of the [templates](templates) directory.

    The [script](generateTemplate.sh) allows you to generate the necessary configuration files.
    Generate the files with the following command:

    ```shell
    ./generateTemplate.sh -i <CLIENT_ID> -x <CLIENT_SECRET> -n <TENANT_ID> -g <GROUP_ID> [-a <SSO_DOMAIN>]
    ```

    Where:
    - *TENANT_ID* and *CLIENT_ID* have been obtained from [previous step](#retrieve-tenant-and-client-information)
    - *CLIENT_SECRET* is listed in your ODM Application, section **General** / **Client Credentials**
    - *GROUP_ID* is the identifier of the ODM Admin group created in a [previous step](#manage-group-and-user) (ID of the group named *odm-admin*)
    - *SSO_DOMAIN* is the domain name of your SSO. If your AzureAD is connected to another SSO, you should add the SSO domain name in this parameter. If your user has been declared as explained in step **Create at least one user that belongs to this new group**, you can omit this parameter.

    The following four files are generated into the `output` directory:

    - webSecurity.xml contains the mapping between Liberty J2EE ODM roles and Microsoft Entra ID groups and users:
      * All ODM roles are given to the GROUP_ID group
      * rtsAdministrators/resAdministrators/resExecutors ODM roles are given to the CLIENT_ID (which is seen as a user) to manage the client-credentials flow
    - openIdWebSecurity.xml contains two openIdConnectClient Liberty configurations:
      * For web access to the Decision Center and Decision Server consoles using userIdentifier="email" with the Authorization Code flow
      * For the rest-api calls using userIdentifier="aud" with the client-credentials flow
    - openIdParameters.properties configures several features like allowed domains, logout, and some internal ODM OpenId features
    - OdmOidcProviders.json configures the client-credentials OpenId provider used by the Decision Center server configuration to connect Decision Center to the Decision Server console and Decision Center to Decision Runner

3. Create the Microsoft Entra ID authentication secret.

    ```shell
    kubectl create secret generic azuread-auth-secret \
        --from-file=OdmOidcProviders.json=./output/OdmOidcProviders.json \
        --from-file=openIdParameters.properties=./output/openIdParameters.properties \
        --from-file=openIdWebSecurity.xml=./output/openIdWebSecurity.xml \
        --from-file=webSecurity.xml=./output/webSecurity.xml
    ```

4. Create the secret allowing to synchronize Decision Center Users and Groups with Entra ID.

    This section is optional.

    ODM Decision Center allows to [manage users and groups from the Business console](https://www.ibm.com/docs/en/odm/9.0.0?topic=center-enabling-users-groups) in order to set access security on specific projects.
    The Groups and Users import can be done using an LDAP connection.
    But, if the openId server also provides a SCIM server, then it can also be managed using a SCIM connection.

    However, in some context, it's not possible to use LDAP or SCIM to import groups and users inside Decision Center.
    We will explain here how to synchronize Decision Center Groups and Users with Entra ID by leveraging Entra ID and Decision Center rest-api.

    A script will be responsible to get groups and users located in the EntraID tenant using the Microsoft Graph API :
    - [for users](https://learn.microsoft.com/en-us/graph/api/resources/users?view=graph-rest-1.0&preserve-view=true)
    - [for groups](https://learn.microsoft.com/en-us/graph/api/resources/groups-overview?view=graph-rest-1.0&tabs=http)

    Then, it will generate a [group-security-configurations.xml](https://www.ibm.com/docs/en/odm/9.0.0?topic=access-optional-user-liberty-configurations#reference_w1b_xhq_2rb__title__3) file that will be consumed using the [Decision Center rest-api](https://www.ibm.com/docs/en/odm/9.0.0?topic=mufdc-creating-users-groups-roles-by-using-rest-api) to populate Groups and Users in the Administration Tab.

    In a kubernetes context, this script can be called by a CRON job.
    Using the new ODM sidecar container mechanism, it can also be managed by the Decision Center pod himself.

    ```shell
    kubectl create secret generic users-groups-synchro-secret \
        --from-file=sidecar-start.sh \
        --from-file=generate-user-group-mgt.sh
    ```
    > **Note**
    > The scripts will be used inside a container using the Decision Center image. It's possible to use a dedicated lighter image instead
    > by setting the helm chart parameter **--set decisionCenter.sidecar.image**
    > You can find a [Dockerfile](Dockerfile) containing the minimal tooling (bash,curl,jq) to execute the scripts.    

## Install your ODM Helm release

### Add the public IBM Helm charts repository

  ```shell
  helm repo add ibm-helm https://raw.githubusercontent.com/IBM/charts/master/repo/ibm-helm
  helm repo update
  ```

### Check that you can access the ODM chart

  ```shell
  helm search repo ibm-odm-prod
  NAME                  	CHART VERSION	APP VERSION	DESCRIPTION
  ibm-helm/ibm-odm-prod   24.0.0          9.0.0.0   	IBM Operational Decision Manager
  ```

### Run the `helm install` command

You can now install the product. We will use the PostgreSQL internal database and disable the data persistence (`internalDatabase.persistence.enabled=false`) to avoid any platform complexity concerning persistent volume allocation.

#### a. Installation on OpenShift using Routes

  See the [Preparing to install](https://www.ibm.com/docs/en/odm/9.0.0?topic=production-preparing-install-operational-decision-manager) documentation for additional information.

  ```shell
  helm install my-odm-release ibm-helm/ibm-odm-prod --set image.tag=9.0.0.0 \
          --set image.repository=cp.icr.io/cp/cp4a/odm --set image.pullSecrets=icregistry-secret \
          --set oidc.enabled=true \
          --set license=true \
          --set internalDatabase.persistence.enabled=false \
          --set customization.trustedCertificateList='{ms-secret,digicert-secret}' \
          --set customization.authSecretRef=azuread-auth-secret \
          --set internalDatabase.runAsUser='' --set customization.runAsUser='' --set service.enableRoute=true
  ```

> **Note**
> If you want the optional synchronization of groups and users with Entra ID, you have to add to the helm install command:
> 
> --set decisionCenter.sidecar.enabled=true --set decisionCenter.sidecar.confSecretRef=users-groups-synchro-secret

#### b. Installation using Ingress

  Refer to the following documentation to install an NGINX Ingress Controller on:
  - [Microsoft Azure Kubernetes Service](../../platform/azure/README.md#create-a-nginx-ingress-controller)
  - [Amazon Elastic Kubernetes Service](../../platform/eks/README-NGINX.md)
  - [Google Kubernetes Engine](../../platform/gcloud/README_NGINX.md)

  When the NGINX Ingress Controller is ready, you can install the ODM release with:

  ```
  helm install my-odm-release ibm-helm/ibm-odm-prod --set image.tag=9.0.0.0 \
          --set image.repository=cp.icr.io/cp/cp4a/odm --set image.pullSecrets=icregistry-secret \
          --set oidc.enabled=true \
          --set license=true \
          --set internalDatabase.persistence.enabled=false \
          --set customization.trustedCertificateList='{ms-secret,digicert-secret}' \
          --set customization.authSecretRef=azuread-auth-secret \
          --set service.ingress.enabled=true \
          --set service.ingress.annotations={"kubernetes.io/ingress.class: nginx"\,"nginx.ingress.kubernetes.io/backend-protocol: HTTPS"}
  ```

> **Note**
> By default, NGINX does not enable sticky session. If you want to use sticky session to connect to DC, refer to [Using sticky session for Decision Center connection](../../contrib/sticky-session/README.md)

> **Note**
> If you want the optional synchronization of groups and users with Entra ID, you have to add to the helm install command:
> 
> --set decisionCenter.sidecar.enabled=true --set decisionCenter.sidecar.confSecretRef=users-groups-synchro-secret

## Complete post-deployment tasks

### Register the ODM redirect URLs

1. Get the ODM endpoints.

    Refer to the [documentation](https://www.ibm.com/docs/en/odm/9.0.0?topic=tasks-configuring-external-access) to retrieve the endpoints.
    For example, on OpenShift you can get the route names and hosts with:

    ```shell
    kubectl get routes --no-headers --output custom-columns=":metadata.name,:spec.host"
    ```

    You get the following hosts:

    ```
    my-odm-release-odm-dc-route           <DC_HOST>
    my-odm-release-odm-dr-route           <DR_HOST>
    my-odm-release-odm-ds-console-route   <DS_CONSOLE_HOST>
    my-odm-release-odm-ds-runtime-route   <DS_RUNTIME_HOST>
    ```

    Using an Ingress, the endpoint is the address of the ODM ingress and is the same for all components. You can get it with:

    ```shell
    kubectl get ingress my-odm-release-odm-ingress
    ```

   You get the following ingress address:

    ```
    NAME                       CLASS    HOSTS   ADDRESS          PORTS   AGE
    my-odm-release-odm-ingress <none>   *       <INGRESS_ADDRESS>   80      14d
    ```

3. Register the redirect URIs into your Microsoft Entra ID application.

    The redirect URIs are built the following way:

      Using Routes:
      - Decision Center redirect URI:  `https://<DC_HOST>/decisioncenter/openid/redirect/odm`
      - Decision Runner redirect URI:  `https://<DR_HOST>/DecisionRunner/openid/redirect/odm`
      - Decision Server Console redirect URI:  `https://<DS_CONSOLE_HOST>/res/openid/redirect/odm`
      - Decision Server Runtime redirect URI:  `https://<DS_RUNTIME_HOST>/DecisionService/openid/redirect/odm`
      - Rule Designer redirect URI: `https://127.0.0.1:9081/oidcCallback`

      Using Ingress:
      - Decision Center redirect URI:  `https://<INGRESS_ADDRESS>/decisioncenter/openid/redirect/odm`
      - Decision Runner redirect URI:  `https://<INGRESS_ADDRESS>/DecisionRunner/openid/redirect/odm`
      - Decision Server Console redirect URI:  `https://<INGRESS_ADDRESS>/res/openid/redirect/odm`
      - Decision Server Runtime redirect URI:  `https://<INGRESS_ADDRESS>/DecisionService/openid/redirect/odm`
      - Rule Designer redirect URI: `https://127.0.0.1:9081/oidcCallback`

   From the Azure console, in **Azure Active Directory** / **App Registrations** / **ODM Application**:

    - Click the `Add a Redirect URI` link
    - Click `Add Platform`
    - Select `Web`
    - `Redirect URIs` Add the Decision Center redirect URI that you got earlier (`https://<DC_HOST>/decisioncenter/openid/redirect/odm` -- don't forget to replace <DC_HOST> with your actual host name!)
    - Check the `Access Token` and `ID Token` check boxes
    - Click `Configure`
    - Click the `Add URI` Link and enter another redirect URI
      - Repeat the previous step until all redirect URIs have been entered.

    - Click **Save** at the bottom of the page.
    ![Add URI](images/AddURI.png)

### Access the ODM services

Well done!  You can now connect to ODM using the endpoints you got [earlier](#register-the-odm-redirect-url) and log in as an ODM admin with the account you created in [the first step](#manage-group-and-user).

### Set up Rule Designer

To be able to securely connect your Rule Designer to the Decision Server and Decision Center services that are running in Certified Kubernetes, you need to establish a TLS connection through a security certificate in addition to the OpenID configuration.

1. Get the following configuration files:

    * `https://<DC_HOST>/decisioncenter/assets/truststore.jks`
    * `https://<DC_HOST>/decisioncenter/assets/OdmOidcProvidersRD.json`
      Where *DC_HOST* is the Decision Center endpoint.

2. Copy the `truststore.jks` and `OdmOidcProvidersRD.json` files to your Rule Designer installation directory next to the `eclipse.ini` file.

3. Edit your `eclipse.ini` file and add the following lines at the end:

    ```
    -Dcom.ibm.rules.studio.oidc.synchro.scopes=<CLIENT_ID>/.default
    -Dcom.ibm.rules.studio.oidc.res.scopes=<CLIENT_ID>/.default
    -Djavax.net.ssl.trustStore=<ECLIPSEINITDIR>/truststore.jks
    -Djavax.net.ssl.trustStorePassword=changeme
    -Dcom.ibm.rules.authentication.oidcconfig=<ECLIPSEINITDIR>/OdmOidcProvidersRD.json
    ```

    Where:
    - *changeme* is the fixed password to be used for the default truststore.jks file.
    - *ECLIPSEINITDIR* is the Rule Designer installation directory next to the eclipse.ini file.

4. Restart Rule Designer.

For more information, refer to the [documentation](https://www.ibm.com/docs/en/odm/9.0.0?topic=designer-importing-security-certificate-in-rule).

### Getting Started with IBM Operational Decision Manager for Containers

Get hands-on experience with IBM Operational Decision Manager in a container environment by following this [Getting started tutorial](https://github.com/DecisionsDev/odm-for-container-getting-started/blob/master/README.md).

### Calling the ODM Runtime Service

To manage ODM runtime call on the next steps, we used the [Loan Validation Decision Service project](https://github.com/DecisionsDev/odm-for-container-getting-started/blob/master/Loan%20Validation%20Service.zip)

Import the **Loan Validation Service** in Decision Center connected using *myodmuser*@YOURDOMAIN created at step 2

![Import project](../Keycloak/images/import_project.png)

Deploy the **Loan Validation Service** production_deployment ruleapps using the **production deployment** deployment configuration in the Deployments>Configurations tab.

![Deploy project](../Keycloak/images/deploy_project.png)

You can retrieve the payload.json from the ODM Decision Server Console or use [the provided payload](payload.json).

As explained in the ODM on Certified Kubernetes documentation [Configuring user access with OpenID](https://www.ibm.com/docs/en/odm/9.0.0?topic=access-configuring-user-openid), we advise to use basic authentication for the ODM runtime call for performance reasons and to avoid the issue of token expiration and revocation.

You can realize a basic authentication ODM runtime call the following way:

  ```shell
$ curl -H "Content-Type: application/json" -k --data @payload.json \
        -H "Authorization: Basic b2RtQWRtaW46b2RtQWRtaW4=" \
      https://<DS_RUNTIME_HOST>/DecisionService/rest/production_deployment/1.0/loan_validation_production/1.0
```

Where b2RtQWRtaW46b2RtQWRtaW4= is the base64 encoding of the current username:password odmAdmin:odmAdmin

But if you want to execute a bearer authentication ODM runtime call using the Client Credentials flow, you have to get a bearer access token:

```shell
$ curl -k -X POST -H "Content-Type: application/x-www-form-urlencoded" \
    -d 'client_id=<CLIENT_ID>&scope=<CLIENT_ID>%2F.default&client_secret=<CLIENT_SECRET>&grant_type=client_credentials' \
    'https://login.microsoftonline.com/<TENANT_ID>/oauth2/v2.0/token'
```

And use the retrieved access token in the following way:

  ```shell
$ curl -H "Content-Type: application/json" -k --data @payload.json \
        -H "Authorization: Bearer <ACCESS_TOKEN>" \
        https://<DS_RUNTIME_HOST>/DecisionService/rest/production_deployment/1.0/loan_validation_production/1.0
```

# Troubleshooting

If you encounter any issue, have a look at the [common troubleshooting explanation](../README.md#Troubleshooting)

# License

[Apache 2.0](/LICENSE)
