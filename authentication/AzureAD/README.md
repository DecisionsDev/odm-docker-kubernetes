# Configuration of ODM with Azure AD

<!-- TOC -->

- [What is Azure AD?](#what-is-azure-ad)
- [About this task](#about-this-task)
- [ODM OpenID flows](#odm-openid-flows)
- [Prerequisites](#prerequisites)
- [Log into the Azure AD instance](#log-into-the-azure-ad-instance)
- [Manage groups and users](#manage-groups-and-users)
- [Set up an application](#set-up-an-application)
- [Prepare your environment for the ODM installation](#prepare-your-environment-for-the-odm-installation)
- [Install your ODM Helm release](#install-your-odm-helm-release)
- [Complete post-deployment tasks](#complete-post-deployment-tasks)

<!-- /TOC -->

# Introduction

In the context of the Operational Decision Manager (ODM) on Certified Kubernetes offering, ODM for production can be configured with an external OpenID Connect server (OIDC provider), such as the Azure AD cloud service.

## What is Azure AD?

Azure Active Directory ([Azure AD](https://azure.microsoft.com/en-us/services/active-directory/#overview)),  is an enterprise identity service that provides single sign-on, multifactor authentication, and conditional access. This is the service that we use in this article.


## About this task

You need to create a number of secrets before you can install an ODM instance with an external OIDC provider such as the Azure AD service, and use web application single sign-on (SSO). The following diagram shows the ODM services with an external OIDC provider after a successful installation.

![ODM web application SSO](images/diag_azuread_interaction.jpg)

The following procedure describes how to manually configure ODM with an Azure AD service.

## ODM OpenID flows

OpenID Connect is an authentication standard built on top of OAuth 2.0. It adds a token called an ID token.

Terminology:

- **OpenID provider** — The authorization server that issues the ID token. In this case, Azure AD is the OpenID provider.
- **end user** — The end user whose details are contained in the ID token.
- **relying party** — The client application that requests the ID token from Azure AD.
- **ID token** — The token that is issued by the OpenID provider and contains information about the end user in the form of claims.
- **claim** — A piece of information about the end user.

The Authorization Code flow is best used by server-side apps in which the source code is not publicly exposed. The apps must be server-side because the request that exchanges the authorization code for a token requires a client secret, which has to be stored in your client. However, the server-side app requires an end user because it relies on interactions with the end user's web browser which redirects the user and then receives the authorization code.

![Authentication flow](images/AuthenticationFlow.png) (© Microsoft)

The Client Credentials flow is intended for server-side (AKA "confidential") client applications with no end user, which normally describes machine-to-machine communication. The application must be server-side because it must be trusted with the client secret, and since the credentials are hard-coded, it cannot be used by an actual end user. It involves a single, authenticated request to the token endpoint which returns an access token.

![Azure AD Client Credential Flow](images/ClientCredential.png) (© Microsoft)

The Microsoft identity platform supports the OAuth 2.0 Resource Owner Password Credentials (ROPC) grant, which allows an application to sign in the user by directly handling their password. Microsoft recommends you do not use the ROPC flow. In most scenarios, more secure alternatives are available and recommended. This flow requires a very high degree of trust in the application, and carries risks which are not present in other flows. You should only use this flow when other more secure flows cannot be used.

![Azure AD Password Flow](images/PasswordFlow.png) (© Microsoft)

## Prerequisites

You need the following elements:

- [Helm v3](https://helm.sh/docs/intro/install/)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl)
- Access to an Operational Decision Manager product
- Access to a CNCF Kubernetes cluster
- An admin Azure AD account

### Create an Azure AD account

If you do not own an Azure AD account, you can sign up for a [free Azure AD developer account](https://azure.microsoft.com/en-us/services/active-directory/)

# Configure an Azure AD instance for ODM (Part 1)

In this section, we explain how to:

- Manage groups and users
- Set up an application
- Configure the default Authorization server

## Log into the Azure AD instance

After activating your account by email, you should have access to your Aure AD instance. [Sign in to Azure](https://portal.azure.com/#home).

## Manage groups and users

1. Create a group for ODM administrators.

    In **Azure Active Directory** / **Groups**:
      * Click **New Group**
        * Group type: Security
        * Group name: *odm-admin*
        * Group description: *ODM Admin group*
        * Membership type: Assigned
        * Click **Create**

    ![Add Group](images/NewGroup.png)

    In **Azure Active Directory** / **Groups** take note of the Object ID. It will be referenced as ``GROUP_ID`` later in this tutorial.

    ![GroupID](images/GroupID.png)

2. Create at least one user that belongs to this new group.

    In **Azure Active Directory** / **Users**:

      * Click **New User** and in Basics fill in:
        * User principal name: *myodmuser*@YOURDOMAIN
        * Mail nickname / Derive from user principal name: checked
        * Display name: `<YourFirstName> <YourLastName>`
        * Password: `My2ODMPassword?`
        * Account enabled: checked

      * In Assignments fill in:
        * Click on Add group and select odm-admin

      * Click **Review + create** and then **Create**.

      ![New User Basics](images/NewUserBasics.png)
      ![New User Assignments](images/NewUserAssignments.png)

      * Click the **myodmuser** user previously created
        * Edit properties
        * Fill the email field with *myodmuser*@YOURDOMAIN

      * Try to log in to the [Azure portal](https://portal.azure.com/) with the user principal name.
       This may require to enable 2FA and/or change the password for the first time.

    Repeat this step for each user that you want to add.

## Set up an application

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

    ![Tenant ID](/images/AzureAD/GetTenantID.png)

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

  * Click on Edit of the "Attributes & Claims" section
    * Click + Add new claim
      * Name: identity
      * Fill 2 Claim conditions in the exact following order:
        1. User Type: Any / Scope Groups: 0 / Source: Attribute / Value: <CLIENT_ID>
        2. User Type: Members / Scope Groups: 0 / Source: Attribute / Value: user.mail
 
6. API Permissions.

    In **Azure Active Directory** / **App Registration**, select **ODM Application**, and then click **API Permissions**.

    * Click Grant Admin Consent for Default Directory

7. Manifest change.

    In **Azure Active Directory** / **App Registration**, select **ODM Application**, and then click **Manifest**.

    As explained in [accessTokenAcceptedVersion attribute explanation](https://docs.microsoft.com/en-us/azure/active-directory/develop/reference-app-manifest#accesstokenacceptedversion-attribute), change the value to 2.

    ODM OpenID Liberty configuration needs version 2.0 for the issuerIdentifier. See the [openIdWebSecurity.xml](templates/openIdWebSecurity.xml) file.


    It is also necessary to set **acceptMappedClaims** to true to manage claims. Without this setting, you get the exception **AADSTS50146: This application is required to be configured with an application-specific signing key. It is either not configured with one, or the key has expired or is not yet valid.** when requesting a token.


   Then, click Save.
   
8. Check the configuration.

    Download the [azuread-odm-script.zip](azuread-odm-script.zip) file to your machine and unzip it in your working directory. This .zip file contains scripts and templates to verify and set up ODM.

    8.1 Verify the Client Credential Token

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

    - *ver*: should be 2.0. otherwise you should verify the previous step **Manifest change**
    - *aud*: should be your CLIENT_ID
    - *iss*: should end with 2.0. otherwise you should verify the previous step **Manifest change**

    8.2 Verify the Client Password Token.

   To check that it has been correctly taken into account, you can request an ID token using the Client password flow.

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
      ...
      "iss": "https://login.microsoftonline.com/<TENANT_ID>/v2.0",
      ...
      "email": "<USERNAME>",
      "identity": "<USERNAME>",
      "groups": [
        "<GROUP>"
      ],
      ...
      "ver": "2.0"
    }
    ```

    Verify:
    - *aud*: should be your CLIENT_ID
    - *email*: should be present. Otherwise you should verify the creation of your user and fill the Email field.
    - *groups*: should contain your GROUP_ID
    - *iss*: should end with 2.0. Otherwise you should verify the previous step **Manifest change**
    - *ver*: should be 2.0. Otherwise you should verify the previous step **Manifest change**

  > If this command failed, try to log in to the [Azure portal](https://portal.azure.com/). You may have to enable 2FA and/or change the password for the first time.

# Deploy ODM on a container configured with Azure AD (Part 2)

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

### Create secrets to configure ODM with Azure AD

1. Create a secret with the Azure AD Server certificate.

    To allow ODM services to access the Azure AD Server, it is mandatory to provide the Azure AD Server certificate.
    You can create the secret as follows:

    ```shell
    keytool -printcert -sslserver login.microsoftonline.com -rfc > microsoft.crt
    kubectl create secret generic ms-secret --from-file=tls.crt=microsoft.crt
    ```

    Introspecting the Azure AD login.microsoftonline.com certificate, you can see it has been signed by the Digicert Root CA authorithy.

    So we will also add the DigiCert Global Root CA from [this page](https://www.digicert.com/kb/digicert-root-certificates.htm):

    ```shell
    curl --silent --remote-name https://cacerts.digicert.com/DigiCertGlobalRootCA.crt.pem
    kubectl create secret generic digicert-secret --from-file=tls.crt=DigiCertGlobalRootCA.crt.pem
    ```

2. Generate the ODM configuration file for Azure AD.

    If you have not yet done so, download the [azuread-odm-script.zip](azuread-odm-script.zip) file to your machine. This archive contains the [script](generateTemplate.sh) and the content of the [templates](templates) directory.

    The [script](generateTemplate.sh) allows you to generate the necessary configuration files.
    Generate the files with the following command:

    ```shell
    ./generateTemplate.sh -i <CLIENT_ID> -x <CLIENT_SECRET> -n <TENANT_ID> -g <GROUP_ID> [-a <SSO_DOMAIN>]
    ```

    Where:
    - *TENANT_ID* and *CLIENT_ID* have been obtained from [previous step](#retrieve-tenant-and-client-information)
    - *CLIENT_SECRET* is listed in your ODM Application, section **General** / **Client Credentials**
    - *GROUP_ID* is the ODM Admin group created in a [previous step](#manage-group-and-user) (*odm-admin*)
    - *SSO_DOMAIN* is the domain name of your SSO. If your AzureAD is connected to another SSO, you should add the SSO domain name in this parameter. If your user has been declared as explained in step **Create at least one user that belongs to this new group**, you can omit this parameter.

    The following four files are generated into the `output` directory:

    - webSecurity.xml contains the mapping between Liberty J2EE ODM roles and Azure AD groups and users:
      * All ODM roles are given to the GROUP_ID group
      * rtsAdministrators/resAdministrators/resExecutors ODM roles are given to the CLIENT_ID (which is seen as a user) to manage the client-credentials flow
    - openIdWebSecurity.xml contains two openIdConnectClient Liberty configurations:
      * For web access to the Decision Center an Decision Server consoles using userIdentifier="email" with the Authorization Code flow
      * For the rest-api call using userIdentifier="aud" with the client-credentials flow
    - openIdParameters.properties configures several features like allowed domains, logout, and some internal ODM OpenId features
    - OdmOidcProviders.json configures the client-credentials OpenId provider used by the Decision Center server configuration to connect Decision Center to the Decision Server console and Decision Center to the Decision Runner

3. Create the Azure AD authentication secret.

    ```shell
    kubectl create secret generic azuread-auth-secret \
        --from-file=OdmOidcProviders.json=./output/OdmOidcProviders.json \
        --from-file=openIdParameters.properties=./output/openIdParameters.properties \
        --from-file=openIdWebSecurity.xml=./output/openIdWebSecurity.xml \
        --from-file=webSecurity.xml=./output/webSecurity.xml
    ```

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
  ibm-helm/ibm-odm-prod	        23.1.0       	8.12.0.0   	IBM Operational Decision Manager
  ```

### Run the `helm install` command

You can now install the product. We will use the PostgreSQL internal database and disable the data persistence (`internalDatabase.persistence.enabled=false`) to avoid any platform complexity concerning persistent volume allocation.

#### a. Installation on OpenShift using Routes

  See the [Preparing to install](https://www.ibm.com/docs/en/odm/8.12.0?topic=production-preparing-install-operational-decision-manager) documentation for additional information.

  ```shell
  helm install my-odm-release ibm-helm/ibm-odm-prod \
          --set image.repository=cp.icr.io/cp/cp4a/odm --set image.pullSecrets=icregistry-secret \
          --set oidc.enabled=true \
          --set license=true \
          --set internalDatabase.persistence.enabled=false \
          --set customization.trustedCertificateList='{ms-secret,digicert-secret}' \
          --set customization.authSecretRef=azuread-auth-secret \
          --set internalDatabase.runAsUser='' --set customization.runAsUser='' --set service.enableRoute=true
  ```

#### b. Installation using Ingress

  Refer to the following documentation to install an NGINX Ingress Controller on:
  - [Microsoft Azure Kubernetes Service](../../platform/azure/README.md#create-a-nginx-ingress-controller)
  - [Amazon Elastic Kubernetes Service](../../platform/eks/README-NGINX.md)
  - [Google Kubernetes Engine](../../platform/gcloud/README_NGINX.md)

  When the NGINX Ingress Controller is ready, you can install the ODM release with:

  ```
  helm install my-odm-release ibm-helm/ibm-odm-prod \
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

## Complete post-deployment tasks

### Register the ODM redirect URLs

1. Get the ODM endpoints.

    Refer to the [documentation](https://www.ibm.com/docs/en/odm/8.12.0?topic=tasks-configuring-external-access) to retrieve the endpoints.
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

3. Register the redirect URIs into your Azure AD application.

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

    - Click`Add Redirect URIs link`
    - Click `Add Platform`
    - Select `Web`
    - `Redirect URIs` Add the Decision Center redirect URI that you got earlier (`https://<DC_HOST>/decisioncenter/openid/redirect/odm` -- don't forget to replace <DC_HOST> with your actual host name!)
    - Check Access Token and ID Token
    - Click Configure
    - Click Add URI Link
      - Repeat the previous steps for all other redirect URIs.

    - Click **Save** at the bottom of the page.
    ![Add URI](images/AddURI.png)

### Access the ODM services

Well done!  You can now connect to ODM using the endpoints you got [earlier](#register-the-odm-redirect-url) and log in as an ODM admin with the account you created in [the first step](#manage-group-and-user).

>Note:  Logout in ODM components using Azure AD authentication raises an error for the time being.  This is a known issue.  We recommend to use a private window in your browser to log in, so that logout is done just by closing this window.

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

For more information, refer to the [documentation](https://www.ibm.com/docs/en/odm/8.12.0?topic=designer-importing-security-certificate-in-rule).

### Getting Started with IBM Operational Decision Manager for Containers

Get hands-on experience with IBM Operational Decision Manager in a container environment by following this [Getting started tutorial](https://github.com/DecisionsDev/odm-for-container-getting-started/blob/master/README.md).

### Calling the ODM Runtime Service

To manage ODM runtime call on the next steps, we used the [Loan Validation Decision Service project](https://github.com/DecisionsDev/odm-for-container-getting-started/blob/master/Loan%20Validation%20Service.zip)

Import the **Loan Validation Service** in Decision Center connected using *myodmuser*@YOURDOMAIN created at step 2

![Import project](../Keycloak/images/import_project.png)

Deploy the **Loan Validation Service** production_deployment ruleapps using the **production deployment** deployment configuration in the Deployments>Configurations tab.

![Deploy project](../Keycloak/images/deploy_project.png)

You can retrieve the payload.json from the ODM Decision Server Console or use [the provided payload](payload.json).

As explained in the ODM on Certified Kubernetes documentation [Configuring user access with OpenID](https://www.ibm.com/docs/en/odm/8.12.0?topic=access-configuring-user-openid), we advise to use basic authentication for the ODM runtime call for performance reasons and to avoid the issue of token expiration and revocation.

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
