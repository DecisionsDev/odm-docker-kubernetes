<!-- TOC titleSize:2 tabSpaces:2 depthFrom:1 depthTo:6 withLinks:1 updateOnSave:1 orderedList:0 skip:0 title:1 charForUnorderedList:- -->
## Table of Contents
- [Introduction](#introduction)
  - [What is Azure AD ?](#what-is-azure-ad-)
  - [About this task](#about-this-task)
  - [ODM OpenID flows](#odm-openid-flows)
  - [Prerequisites](#prerequisites)
    - [Create an Azure AD account](#create-an-azure-ad-account)
- [Configure an Azure AD instance for ODM (Part 1)](#configure-an-azure-ad-instance-for-odm-part-1)
  - [Log into the Azure AD instance](#log-into-the-azure-ad-instance)
  - [Manage groups and users](#manage-groups-and-users)
  - [Set up an application](#set-up-an-application)
- [Deploy ODM on a container configured with Azure AD (Part 2)](#deploy-odm-on-a-container-configured-with-azure-ad-part-2)
  - [Prepare your environment for the ODM installation](#prepare-your-environment-for-the-odm-installation)
    - [Create a secret to use the Entitled Registry](#create-a-secret-to-use-the-entitled-registry)
    - [Create secrets to configure ODM with Azure AD](#create-secrets-to-configure-odm-with-azure-ad)
  - [Install your ODM Helm release](#install-your-odm-helm-release)
  - [Complete post-deployment tasks](#complete-post-deployment-tasks)
    - [Register the ODM redirect URL](#register-the-odm-redirect-url)
    - [Access the ODM services](#access-the-odm-services)
    - [Set up Rule Designer](#set-up-rule-designer)
    - [Calling the ODM Runtime Service](#calling-the-odm-runtime-service)
- [License](#license)
<!-- /TOC -->

# Introduction

In the context of the Operational Decision Manager (ODM) on Certified Kubernetes offering, ODM for production can be configured with an external OpenID Connect server (OIDC provider) such as the Azure AD cloud service.

## What is Azure AD ?

Azure Active Directory ([Azure AD](https://azure.microsoft.com/en-us/services/active-directory/#overview)),  is an enterprise identity service that provides single sign-on, multifactor authentication, and conditional access. This is the service that we use in this article.

## About this task

You need to create a number of secrets before you can install an ODM instance with an external OIDC provider such as the Azure AD service and use web application single sign-on (SSO). The following diagram (missing??) shows the ODM services with an external OIDC provider after a successful installation.

The following procedure describes how to manually configure ODM with an Azure AD service.

## ODM OpenID flows

OpenID Connect is an authentication standard built on top of OAuth 2.0. It adds a token called an ID token.

Terminology:

- The **OpenID provider** — The authorization server that issues the ID token. In this case, Azure AD is the OpenID provider.
- The **end user** — The end user whose information is contained in the ID token.
- The **relying party** — The client application that requests the ID token from Azure AD.
- The **ID token** — The token that is issued by the OpenID provider and contains information about the end user in the form of claims.
- A **claim** — A piece of information about the end user.

The Authorization Code flow is best used by server-side apps where the source code is not publicly exposed. The apps must be server-side because the request that exchanges the authorization code for a token requires a client secret, which has to be stored in your client. However, the server-side app requires an end user because it relies on interactions with the end user's web browser, which redirects the user and then receives the authorization code.

Auth Code flow width??:

![Authentication flow](/images/AzureAD/AuthenticationFlow.png) (© Microsoft) 

The Client Credentials flow is intended for server-side (AKA "confidential") client applications with no end user, which normally describes machine-to-machine communication. The application must be server-side because it must be trusted with the client secret, and since the credentials are hard-coded, it cannot be used by an actual end user. It involves a single, authenticated request to the token endpoint, which returns an access token.

![Azure AD Client Credential Flow](/images/AzureAD/ClientCredential.png) (© Microsoft)

The Microsoft identity platform supports the OAuth 2.0 Resource Owner Password Credentials (ROPC) grant, which allows an application to sign in the user by directly handling their password. Microsoft recommends you do not use the ROPC flow. In most scenarios, more secure alternatives are available and recommended. This flow requires a very high degree of trust in the application, and carries risks which are not present in other flows. You should only use this flow when other more secure flows cannot be used.

![Azure AD Password Flow](/images/AzureAD/PasswordFlow.png) (© Microsoft)




## Prerequisites

First, install the following software on your machine:

- [Helm v3](https://helm.sh/docs/intro/install/)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl)
- Access to an Operational Decision Manager product (on the user's machine??)
- A CNCF Kubernetes cluster (on the user's machine??)
- An admin Azure AD account

### Create an Azure AD account

If you do not own an Azure AD account, you can sign up for a [free Azure AD developer account](https://azure.microsoft.com/en-us/services/active-directory/) 

# Configure an Azure AD instance for ODM (Part 1)

In this section, we explain how to:

- Manage groups and users
- Set up an application
- Configure the default Authorization server

## Log into the Azure AD instance
After activating your account by email, you should have access to your Aure AD instance. Sign in to Azure.

## Manage groups and users

1. Create a group for ODM administrators.

    In Menu **Azure Active Directory** / **Groups**:
      * Click **New Group** 
        * Group type: Security
        * Group name: *odm-admin*
        * Group description: *ODM Admin group*
        * Azure AD roles can be assigned to the group: No
        * Membership type: Assigned
        * Click **Create**
  

    ![Add Group](/images/AzureAD/NewGroup.png)

    In Menu **Azure Active Directory** / **Groups** take a note of the Object ID. It will be referenced as ``GROUP_GUID`` later in this tutorial.

    ![GroupID](/images/AzureAD/GroupGUID.png)

2. Create at least one user that belongs to this new group.

    In Menu **Azure Active Directory** / **Users**:
      * Click **New User** 
        * User name: *myodmuser*@YOURDOMAIN
        * Name: ``myodmuser``
        * Name??: ``<YourEmailAddress>``
        * First name: ``<YourFirstName>``
        * Last name: ``<YourLastName>``
        * Password: ``My2ODMPassword?``
        * Groups (optional): ***odm-admin***
        * Click **Create**

    ![New User](/images/AzureAD/NewUser.png)

    Repeat this step for each user you want to add.

## Set up an application

1. Create the *ODM application*.

    In Menu **Azure Active Directory** / **App Registration**, click **New Registration**:
    * Name: **ODM Application**
    * Who can use this application or access this API: 	Accounts in this organizational directory only (ibmodmdev only - Single tenant)
    * Click **Register** 

    ![New Web Application](/images/AzureAD/RegisterApp.png)


2. Generate an OpenID client secret
   
    In Menu **Azure Active Directory** / **App Registration**, click **ODM Application**:
    * Click Client credentials: Add a certificate or secret (link)
    * Click +New Client Secret
      * Description: ``For ODM integration``
      * Click Add
   * Take a note of the **Value**. It will be referenced as ``CLIENT_SECRET`` in the next steps.
  
3. Add Claims 

    In Menu **Azure Active Directory** / **App Registration**, click **ODM Application**, click **Token Configuration**:

    * Click +Add optional claim 
    * Select ID
    * Check Email
    * Click Add
    * Check Turn on the Microsoft Graph email permission 
    * Click Add

    * Click +Add groups claim
    * Check Security Groups
    * Click Save
  
4. API Permissions

    In Menu **Azure Active Directory** / **App Registration**, click **ODM Application**, click **API Permissions**.
    * Click Grant Admin Consent for <YourOrg>
  
5. Manifest change
  
    In Menu **Azure Active Directory** / **App Registration**, click **ODM Application**, click **Manifest**.
    
    As explained in [accessTokenAcceptedVersion attribute explanation](  https://docs.microsoft.com/en-us/azure/active-directory/develop/reference-app-manifest#accesstokenacceptedversion-attribute
), change the value to 2 and click Save.
  ODM OpenID Liberty configuration needs version 2.0 for the issuerIdentifier. See the [openIdWebSecurity.xml](templates/openIdWebSecurity.xml) file.
  
    To check that it has been correctly taken into account, you can request an access token using the Client-Credentials flow:
  
    ```
    $ curl -X POST -H "Content-Type: application/x-www-form-urlencoded" \
      -d 'client_id=<CLIENT_ID>&scope=<CLIENT_ID>%2F.default&client_secret=<CLIENT_SECRET>&grant_type=client_credentials' \
      'https://login.microsoftonline.com/<TENANT_ID>/oauth2/v2.0/token'
    ```
  
    Where:
  
    - *TENANT_ID* and *CLIENT_ID* have been obtained from [step](#retrieve-tenant-and-client-informations)
    - *CLIENT_SECRET* is listed in your ODM Application, section **General** / **Client Credentials**
  
    and introspect it?? with [https://jwt.ms](https://jwt.ms). You should get:
    
    ```
    {
    "typ": "JWT",
    "alg": "RS256",
    "kid": "jS1Xo1OWDj_52vbwGNgvQO2VzMc"
    }.{
    "aud": "<CLIENT_ID",
    "iss": "https://login.microsoftonline.com/<TENANT_ID>/v2.0",
    ...
    "ver": "2.0"
    }
    ```
  
# Deploy ODM on a container configured with Azure AD (Part 2)

## Prepare your environment for the ODM installation

### Create a secret to use the Entitled Registry

1. Log in to [MyIBM Container Software Library](https://myibm.ibm.com/products-services/containerlibrary) with the IBMid and password that are associated with the entitled software to get your entitlement key.

    In the **Container software library** tile, verify your entitlement on the **View library** page, and then go to **Get entitlement** key to retrieve the key.

2. Create a pull secret by running a `kubectl create secret` command.

    ```
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

3. Make a note of the secret name so that you can set it for the **image.pullSecrets** parameter when you run a helm install of your containers. The image.repository parameter is later set to *cp.icr.io/cp/cp4a/odm*.

### Create secrets to configure ODM with Azure AD



1. Create a secret with the Azure AD Server certificate.

    To allow ODM services to access the Azure AD Server, it is mandatory to provide the Azure AD Server certificate.
    You can create the secret as follows:

    ```
    keytool -printcert -sslserver login.microsoftonline.com -rfc > microsoft.crt
    kubectl create secret generic ms-secret --from-file=tls.crt=microsoft.crt
    ```
2. Retrieve Tenant and Client informations.

    From the Azure console, in **Azure Active Directory** / **App Registrations** / **ODM Application**:
    - Click Overview 
    - Directory (tenant) ID: **Your Tenant ID**. This will be referenced as `TENANT_ID`` in the next steps.
    - Application (client) ID: **Client ID**. This will be referenced as `CLIENT_ID`` in the next steps.

    ![Tenant ID](/images/AzureAD/GetTenantID.png)
3. Generate the ODM configuration file for Azure AD.

    The [script](generateTemplate.sh) allows you to generate the necessary configuration files.
    You can download the [azuread-odm-script.zip](azuread-odm-script.zip) .zip file to your machine. This .zip file contains the [script](generateTemplate.sh) and the content of the [templates](templates) directory.

    Generate the files with the following command:
    ```
    ./generateTemplate.sh -i <CLIENT_ID> -x <CLIENT_SECRET> -n <TENANT_ID> -g <GROUP_GUID>
    ```

    Where:
    - Both *TENANT_ID* and *CLIENT_ID* has been obtained from [previous step](#retrieve-tenant-and-client-informations)
    - *CLIENT_SECRET* are listed in your ODM Application, section **General** / **Client Credentials**
    - *GROUP_GUID* is the ODM Admin group we created in a [previous step](#manage-group-and-user) (*odm-admin*)

    The files are generated into the `output` directory.

4. Create the Azure AD authentication secret.

    ```
    kubectl create secret generic azuread-auth-secret \
        --from-file=OdmOidcProviders.json=./output/OdmOidcProviders.json \
        --from-file=openIdParameters.properties=./output/openIdParameters.properties \
        --from-file=openIdWebSecurity.xml=./output/openIdWebSecurity.xml \
        --from-file=webSecurity.xml=./output/webSecurity.xml
    ```

## Install your ODM Helm release

### 1. Add the public IBM Helm charts repository.

    ```
    helm repo add ibmcharts https://raw.githubusercontent.com/IBM/charts/master/repo/entitled
    helm repo update
    ```

### 2. Check that you can access the ODM chart.

    ```
    helm search repo ibm-odm-prod
    NAME                  	CHART VERSION	APP VERSION	DESCRIPTION                     
    ibmcharts/ibm-odm-prod	22.1.0       	8.11.0.1   	IBM Operational Decision Manager
    ```

### 3. Run the `helm install` command.

    You can now install the product. We will use the PostgreSQL internal database and disable the data persistence (`internalDatabase.persistence.enabled=false`) to avoid any platform complexity concerning persistent volume allocation.

#### a. Installation on OpenShift using Routes
  
  See [Preparing to install](https://www.ibm.com/docs/en/odm/8.11.0?topic=production-preparing-install-operational-decision-manager) documentation topic for additional information.
  
  ```
  helm install my-odm-release ibmcharts/ibm-odm-prod \
          --set image.repository=cp.icr.io/cp/cp4a/odm --set image.pullSecrets=icregistry-secret \
          --set oidc.enabled=true \
          --set internalDatabase.persistence.enabled=false \
          --set customization.trustedCertificateList={"ms-secret"} \
          --set customization.authSecretRef=azuread-auth-secret \
          --set internalDatabase.runAsUser='' --set customization.runAsUser='' --set service.enableRoute=true
  ```

#### b. Installation using Ingress
  
  You can refer to our existing documentation explaining how to install an NGINX Ingress Controller on :
  - [Microsoft Azure Kubernetes Service](../../platform/azure/README.md#create-a-nginx-ingress-controller)
  - [Amazon Elastic Kubernetes Service](../../platform/eks/README-NGINX.md)
  - [Google Kubernetes Engine](../../platform/gcloud/README_NGINX.md)
  
  When the NGINX Ingress Controller is ready, you can install the ODM release with:
  
  ```
  helm install my-odm-release ibmcharts/ibm-odm-prod \
          --set image.repository=cp.icr.io/cp/cp4a/odm --set image.pullSecrets=icregistry-secret \
          --set oidc.enabled=true \
          --set internalDatabase.persistence.enabled=false \
          --set customization.trustedCertificateList={"ms-secret"} \
          --set customization.authSecretRef=azuread-auth-secret \
          --set service.ingress.enabled=true \
          --set service.ingress.annotations={"kubernetes.io/ingress.class: nginx"\,"nginx.ingress.kubernetes.io/backend-protocol: HTTPS"\,"nginx.ingress.kubernetes.io/affinity: cookie"}
  ```

## Complete post-deployment tasks

### Register the ODM redirect URL

    
1. Get the ODM endpoints.
    You can refer to the [documentation](https://www.ibm.com/docs/en/odm/8.11.0?topic=production-configuring-external-access) to retrieve the ODM endpoints.
    For example, on OpenShift you can get the route names and hosts with:

    ```
    kubectl get routes --no-headers --output custom-columns=":metadata.name,:spec.host"
    ```

    You get the following hosts:
    ```
    my-odm-release-odm-dc-route           <DC_HOST>
    my-odm-release-odm-dr-route           <DR_HOST>
    my-odm-release-odm-ds-console-route   <DS_CONSOLE_HOST>
    my-odm-release-odm-ds-runtime-route   <DS_RUNTIME_HOST>
    ```
   
    Using an Ingress, the endpoint is the address of the ODM ingress and is the same for all components, you can get it with:
  
    ```
    kubectl get ingress my-odm-release-odm-ingress
    ```
  
   You get the following ingress address:
    ```
    NAME                       CLASS    HOSTS   ADDRESS          PORTS   AGE
    my-odm-release-odm-ingress <none>   *       <INGRESS_ADDRESS>   80      14d
    ```

2. Register the redirect URIs into your Azure AD application.

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
    - `Redirect URIs` Add the Decision Center redirect URI you got earlier (`https://<DC_HOST>/decisioncenter/openid/redirect/odm` -- don't forget to replace <DC_HOST> by your actual host name!)
    - Check Access Token and ID Token 
    - Click Configure


    - Click Add URI Link
      - Repeat the previous step for all other redirect URIs.

    - Click **Save** at the bottom of the page.
    ![Add URI](/images/AzureAD/AddURI.png)
    

### Access the ODM services

Well done!  You can now connect to ODM using the endpoints you got [earlier](#register-the-odm-redirect-url) and log in as an ODM admin with the account you created in [the first step](#manage-group-and-user).

>Note:  Logout in ODM components using Azure AD authentication raises an error for the time being.  This is a known issue.  We recommend to use a private window in your browser to log in, so that logout is done just by closing this window.

### Set up Rule Designer

To be able to securely connect your Rule Designer to the Decision Server and Decision Center services that are running in Certified Kubernetes, you need to establish a TLS connection through a security certificate in addition to the OpenID configuration.

1. Get the following configuration files.
    * `https://<DC_HOST>/decisioncenter/assets/truststore.jks`
    * `https://<DC_HOST>/odm/decisioncenter/assets/OdmOidcProvidersRD.json`
      Where *DC_HOST* is the Decision Center endpoint.

2. Copy the `truststore.jks` and `OdmOidcProvidersRD.json` files to your Rule Designer installation directory next to the `eclipse.ini` file.

3. Edit your `eclipse.ini` file and add the following lines at the end.
    ```
    -Djavax.net.ssl.trustStore=<ECLIPSEINITDIR>/truststore.jks
    -Djavax.net.ssl.trustStorePassword=changeit
    -Dcom.ibm.rules.authentication.oidcconfig=<ECLIPSEINITDIR>/OdmOidcProvidersRD.json
    ```
    Where:
    - *changeit* is the fixed password to be used for the default truststore.jks file.
    - *ECLIPSEINITDIR* is the Rule Designer installation directory next to the eclipse.ini file.

4. Restart Rule Designer.

For more information, refer to the [documentation](https://www.ibm.com/docs/en/odm/8.11.0?topic=designer-importing-security-certificate-in-rule).
  
### Calling the ODM Runtime Service
  
As explained in the ODM on K8s documentation [Configuring user access with OpenID](https://www.ibm.com/docs/en/odm/8.11.0?topic=access-configuring-user-openid), we advise to use basic authentication for ODM runtime call for performance reason and to avoid issue on token expiration and revokation.

You can realize a basic authentication ODM runtime call this way :
  
   ```
  $ curl -H "Content-Type: application/json" -k --data @payload.json \
         -H "Authorization: Basic b2RtQWRtaW46b2RtQWRtaW4=" \
        https://<DS_RUNTIME_HOST>/DecisionService/rest/LoanValidationDS/1.0/loan_validation_with_score_and_grade/1.0
  ```
  
  Where b2RtQWRtaW46b2RtQWRtaW4= is the base64 encoding of the current username:password odmAdmin:odmAdmin

But, if you want to execute a bearer authentication ODM runtime call using the Client Credentials flow, you have to get a bearer access token :
  
  ```
  $ curl -X POST -H "Content-Type: application/x-www-form-urlencoded" \
      -d 'client_id=<CLIENT_ID>&scope=<CLIENT_ID>%2F.default&client_secret=<CLIENT_SECRET>&grant_type=client_credentials' \
      'https://login.microsoftonline.com/<TENANT_ID>/oauth2/v2.0/token'
  ```
  
 And use the retrieved access token this way:
  
   ```
  $ curl -H "Content-Type: application/json" -k --data @payload.json \
         -H "Authorization: Bearer <ACCESS_TOKEN>" \
         https://<DS_RUNTIME_HOST>/DecisionService/rest/LoanValidationDS/1.0/loan_validation_with_score_and_grade/1.0
  ```
  
# License

[Apache 2.0](/LICENSE)
