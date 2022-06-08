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
- [License](#license)
<!-- /TOC -->

# Introduction

In the context of the ODM on Certified Kubernetes offering, Operational Decision Manager for production can be configured with an external OpenID Connect server (OIDC provider) such as the Azure AD cloud service.

## What is Azure AD ?

Azure Active Directory ([Azure AD](https://azure.microsoft.com/en-us/services/active-directory/#overview)),  is an enterprise identity service that provides single sign-on, multifactor authentication, and conditional access. This is the service that we use in this article.

## About this task

You need to create a number of secrets before you can install an ODM instance with an external OIDC provider such as the Azure AD service and use web application single sign-on (SSO). The following diagram shows the ODM services with an external OIDC provider after a successful installation.

TODO 
![ODM web application SSO](/images/AzureAD/ClientCredential.png)

The following procedure describes how to manually configure ODM with an Azure AD service.

## ODM OpenID flows

OpenID Connect is an authentication standard built on top of OAuth 2.0. It adds a token called an ID token.

Terminology:

- The **OpenID provider** — The authorization server that issues the ID token. In this case, Azure AD is the OpenID provider.
- The **end user** — The end user whose information is contained in the ID token.
- The **relying party** — The client application that requests the ID token from Azure AD.
- The **ID token** — The token that is issued by the OpenID provider and contains information about the end user in the form of claims.
- A **claim** — A piece of information about the end user.

The Client Credentials flow is intended for server-side (AKA "confidential") client applications with no end user, which normally describes machine-to-machine communication. The application must be server-side because it must be trusted with the client secret, and since the credentials are hard-coded, it can't be used by an actual end user. It involves a single, authenticated request to the token endpoint, which returns an access token.

![Azure AD Client Credential Flow](/images/AzureAD/ClientCredential.png) (© Microsoft)

The Authorization Code flow is best used by server-side apps where the source code isn't publicly exposed. The apps must be server-side because the request that exchanges the authorization code for a token requires a client secret, which has to be stored in your client. However, the server-side app requires an end user because it relies on interactions with the end user's web browser, which redirects the user and then receives the authorization code.

Auth Code flow width:

![Authentication flow](/images/Okta/Authentication_flow.png) (© Okta) 

TODO  DO WE NEEDS TO KEEP IT.

## Prerequisites

First, install the following software on your machine:

- [Helm v3](https://helm.sh/docs/intro/install/)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl)
- Access to an Operational Decision Manager product
- A CNCF Kubernetes cluster
- An admin Azure AD account

### Create an Azure AD account

You can sign up for a [free Azure AD developer account](https://azure.microsoft.com/en-us/services/active-directory/) if you don't own an Azure AD account already.

# Configure an Azure AD instance for ODM (Part 1)

In this section, we explain how to:

- Manage groups and users
- Set up an application
- Configure the default Authorization server

## Log into the Azure AD instance
After activating your account by email, you should have access to your Aure AD instance. Sign in to Azure.

## Manage groups and users

1. Create a group for ODM administrators. It is referenced as *AZURE_ODM_GROUP* later in this article.

    In Menu **Directory** / **Groups**:
      * Click **New Group** button
        * Group Type: Security
        * Name: *odm-admin*
        * Group Description: *ODM Admin group*
        * Azure AD roles can be assigned to the group: No
        * Member Ship: Assgned
        * Click **Create**
  

    ![Add Group](/images/AzureAD/NewGroup.png)

2. Create at least one user that belongs to this new group.

    In Menu **Directory** / **Users**:
      * Click **New User** button
        * User name: *myodmuser*@YOURDOMAIN
        * Name: ``myodmuser``
        * Name: ``<YourEmailAddress>``
        * First name: ``<YourFirstName>``
        * Last name: ``<YourLastName>``
        * Password: ``My2ODMPassword?``
        * Groups (optional): ***odm-admin***
        * Click **Create**

    ![New User](/images/AzureAD/NewUser.png)

    Repeat this step for each user you want to add.

## Set up an application

1. Create the *ODM application*.

    In Menu **Directory** / **App Registration**, click **New Registration**:
       * Name: **ODM Application**
       * Who can use this application : 	Accounts in this organizational directory only (ibmodmdev only - Single tenant)
       * Click **Register** 

    ![New Web Application](/images/AzureAD/RegisterApp.png)

2. Generate an OpenID client Secrets
   
    In Menu **Directory** / **App Registration**, click **ODM Application**:
       * Click Client credentials : Add a certificate or secret (link)
       * Click +New Client Secret
          * Description: ``For ODM integration``
          * Click Add
        * Take a notes of the **Value**. This will be referenced as ``<Client Secret>`` in the next steps.
  
3. Add Claims 

TODO

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

1. Retrieve Azure AD Server information.

    From the Azure console, in **Directory** / **App Registrations** / **ODM Application**:
    - Click Overview 
    - Directory (tenant) ID: **Your Tenant ID**. This will be referenced as ``<YourTenantID>`` in the next steps.

    ![Tenant ID](/images/AzureAD/GetTenantID.png)

2. Create a secret with the Azure AD Server certificate.

    To allow ODM services to access the Azure AD Server, it is mandatory to provide the Azure AD Server certificate.
    You can create the secret as follows:

    ```
    keytool -printcert -sslserver login.microsoftonline.com -rfc > microsoft.crt
    kubectl create secret generic ms-secret --from-file=tls.crt=microsoft.crt
    ```

3. Generate the ODM configuration file for Azure AD.

    The [script](generateTemplate.sh) allows you to generate the necessary configuration files.
    You can download the [azuread-odm-script.zip](azuread-odm-script.zip) .zip file to your machine. This .zip file contains the [script](generateTemplate.sh) and the content of the [templates](templates) directory.

    Generate the files with the following command:
    ```
    ./generateTemplate.sh -i <CLIENT_ID> -x <CLIENT_SECRET> -n <TENANT_ID> -g <GROUP_GUID>
    ```

    Where:
    - *TENANT_ID* has been obtained from [previous step](#retrieve-azuread-server-information)
    - Both *CLIENT_ID* and *CLIENT_SECRET* are listed in your ODM Application, section **General** / **Client Credentials**
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

1. Add the public IBM Helm charts repository.

    ```
    helm repo add ibmcharts https://raw.githubusercontent.com/IBM/charts/master/repo/entitled
    helm repo update
    ```

2. Check that you can access the ODM chart.

    ```
    helm search repo ibm-odm-prod
    NAME                  	CHART VERSION	APP VERSION	DESCRIPTION                     
    ibmcharts/ibm-odm-prod	22.1.0       	8.11.0.1   	IBM Operational Decision Manager
    ```

3. Run the `helm install` command.

    You can now install the product. We will use the PostgreSQL internal database and disable the data persistence (`internalDatabase.persistence.enabled=false`) to avoid any platform complexity concerning persistent volume allocation.

    ```
    helm install my-odm-release ibmcharts/ibm-odm-prod \
          --set image.repository=cp.icr.io/cp/cp4a/odm --set image.pullSecrets=icregistry-secret \
          --set oidc.enabled=true \
          --set internalDatabase.persistence.enabled=false \
          --set customization.trustedCertificateList={"ms-secret"} \
          --set customization.authSecretRef=azuread-auth-secret
    ```

    > Note: On OpenShift, you have to add the following parameters due to security context constraints.
    > ```
    > --set internalDatabase.runAsUser='' --set customization.runAsUser='' --set service.enableRoute=true
    > ```
    > See [Preparing to install](https://www.ibm.com/docs/en/odm/8.11.0?topic=production-preparing-install-operational-decision-manager) documentation topic for additional information.

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

2. Register the redirect URIs into your Azure AD application.

    The redirect URIs are built the following way:

      - Decision Center redirect URI:  `https://<DC_HOST>/decisioncenter/openid/redirect/odm`
      - Decision Runner redirect URI:  `https://<DR_HOST>/DecisionRunner/openid/redirect/odm`
      - Decision Server Console redirect URI:  `https://<DS_CONSOLE_HOST>/res/openid/redirect/odm`
      - Decision Server Runtime redirect URI:  `https://<DS_RUNTIME_HOST>/DecisionService/openid/redirect/odm`
      - Rule Designer redirect URI: `https://127.0.0.1:9081/oidcCallback`

   From the Azure console, in **Directory** / **App Registrations** / **ODM Application**:
    - Click`Redirect URIs link`

    ![Redirect URI](/images/AzureAD/RedirectURL.png)

    - Click Add URI Link
      - click **+ Add URI** and add the Decision Center redirect URI you got earlier (`https://<DC_HOST>/decisioncenter/openid/redirect/odm` -- don't forget to replace <DC_HOST> by your actual host name!)
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

# License

[Apache 2.0](/LICENSE)
