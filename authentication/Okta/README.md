# Configuration of ODM with Okta

<!-- TOC depthfrom:1 depthto:6 withlinks:false updateonsave:false orderedlist:false -->
## Table of Contents
- [Introduction](#introduction)
  - [What is Okta?](#what-is-okta)
  - [About this task](#about-this-task)
  - [ODM OpenID flows](#odm-openid-flows)
  - [Prerequisites](#prerequisites)
    - [Create an Okta account](#create-an-okta-account)
- [Configure an Okta instance for ODM (Part 1)](#configure-an-okta-instance-for-odm-part-1)
  - [Log into the OKTA instance](#log-into-the-okta-instance)
  - [Manage groups and users](#manage-groups-and-users)
  - [Set up an application](#set-up-an-application)
  - [Configure the *default* Authorization Server](#configure-the-default-authorization-server)
- [Deploy ODM on a container configured with Okta Server (Part 2)](#deploy-odm-on-a-container-configured-with-okta-server-part-2)
  - [Prepare your environment for the ODM installation](#prepare-your-environment-for-the-odm-installation)
    - [Create a secret to use the Entitled Registry](#create-a-secret-to-use-the-entitled-registry)
    - [Create secrets to configure ODM with Okta](#create-secrets-to-configure-odm-with-okta)
  - [Install your ODM Helm release](#install-your-odm-helm-release)
  - [Complete post-deployment tasks](#complete-post-deployment-tasks)
    - [Register the ODM redirect URLs](#register-the-odm-redirect-urls)
    - [Access the ODM services](#access-the-odm-services)
    - [Set up Rule Designer](#set-up-rule-designer)
    - [Getting Started with IBM Operational Decision Manager for Containers](#getting-started-with-ibm-operational-decision-manager-for-containers)
    - [Calling the ODM Runtime Service](#calling-the-odm-runtime-service)
- [Troubleshooting](#troubleshooting)
- [License](#license)

<!-- /TOC -->

# Introduction

In the context of the ODM on Certified Kubernetes offering, Operational Decision Manager for production can be configured with an external OpenID Connect server (OIDC provider) such as the Okta service.

## What is Okta?

[Okta](https://www.okta.com/) is a secure identity cloud that links all your apps, logins and devices into a unified digital fabric. Okta sells centralized services, including a single sign-on service that allows users to log into a variety of systems. This is the service that we use in this article.

## About this task

You need to create a number of secrets before you can install an ODM instance with an external OIDC provider such as the Okta service and use web application single sign-on (SSO). The following diagram shows the ODM services with an external OIDC provider after a successful installation.

![ODM web application SSO](/images/Okta/diag_okta_interaction.jpg)

The following procedure describes how to manually configure ODM with an Okta service.

## ODM OpenID flows

OpenID Connect is an authentication standard built on top of OAuth 2.0. It adds a token called an ID token.

Terminology:

- **OpenID provider** — The authorization server that issues the ID token. In this case, Okta is the OpenID provider.
- **end user** — The end user whose details are contained in the ID token.
- **relying party** — The client application that requests the ID token from Okta.
- **ID token** — The token that is issued by the OpenID provider and contains information about the end user in the form of claims.
- **claim** — A piece of information about the end user.

The Client Credentials flow is intended for server-side (AKA "confidential") client applications with no end user, which normally describes machine-to-machine communication. The application must be server-side because it must be trusted with the client secret, and since the credentials are hard coded, it cannot be used by an actual end user. It involves a single, authenticated request to the token endpoint, which returns an access token.

![Okta Client Credential Flow](/images/Okta/oauth_client_creds_flow.png) (© Okta)

The Authorization Code flow is best used by server-side apps where the source code is not publicly exposed. The apps must be server-side because the request that exchanges the authorization code for a token requires a client secret, which has to be stored in your client. However, the server-side app requires an end user because it relies on interactions with the end user's web browser, which redirects the user and then receives the authorization code.

Auth Code flow width:

![Authentication flow](/images/Okta/Authentication_flow.png) (© Okta)

## Prerequisites

First, install the following software on your machine:

- [Helm v3](https://helm.sh/docs/intro/install/)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl)
- Access to an Operational Decision Manager product
- A CNCF Kubernetes cluster
- An admin Okta account

### Create an Okta account

If you do not own an Okta account, you can sign up for a [free trial Okta account](https://www.okta.com/free-trial/). Be aware that Okta enforces [rate limits](https://developer.okta.com/docs/reference/rate-limits/) that are obviously lower for free developer accounts than for paid accounts but they should not be a problem for a demo.

# Configure an Okta instance for ODM (Part 1)

In this section, we explain how to:

- Manage groups and users
- Set up an application
- Configure the default Authorization server

## Log into the OKTA instance
After activating your account by email, you should have access to your Okta instance. Sign in to Okta.

## Manage groups and users

1. Create a group for ODM administrators. It is referenced as *OKTA_ODM_GROUP* later in this article.

    In Menu **Directory** / **Groups**:
      * Click **Add Group** button
        * Name: *odm-admin*
        * Group Description: *ODM Admin group*

    ![Add Group](/images/Okta/AddGroup.png)

2. Create at least one user that belongs to this new group.

    In Menu **Directory** / **People**:
      * Click **Add Person** button
        * User type: *User*
        * First name: ``<YourFirstName>``
        * Last name: ``<YourLastName>``
        * Username: ``<YourEmailAddress>``
        * Primary email: ``<YourEmailAddress>``
        * Groups (optional): ***odm-admin***
        * Click **Save**

    ![Add Person](/images/Okta/add_person.png)

    Repeat this step for each user you want to add.

## Set up an application

1. Create the *ODM application*.

    In Menu **Applications** / **Applications**, click **Create an App Integration**:
      * Select **OIDC - OpenID Connect**
      * Select **Web Application**
      * Click **Next**

    ![Add Application](/images/Okta/AddApplication.png)

2. Configure the new web app integration.

    * Fill the **App integration name**: *ODM Application*
    * In **Grant type**:
      * Check **Client Credentials**
      * Check **Refresh Token**
      * Check **Implicit (hybrid)**
    * Keep the default **Sign-in redirect URIs** and **Sign-out redirect URIs**, and leave the **Base URIs** blank
    * In **Assignments**:
      * Under **Controlled access**:
        * Check **Limit access to selected groups**
      * Fill the **Selected group(s)** : ***odm-admin***
    * Click **Save** 

    ![New Web Application](/images/Okta/NewWebAppIntegration.png)

## Configure the *default* Authorization Server

In this step, we augment the token with meta-information that is required by the ODM OpenID configuration so that ODM can manage both authentication and authorization mechanisms.

1. In Menu **Security** / **API**, select the **default** authorization server.

2. Add the *odmapiusers* scope.

    To be more secure, we will use the client credentials flow for the ODM REST API call. This requires to create a specific restricted scope (named *OKTA_API_SCOPE* later in this article).

    In the **Scopes** tab, click **Add Scope** 
      - Name : *odmapiusers*
      - Click **Create** 

3. Add the identifier and group claims.

    We need to augment the tokens with the user identifier and group properties that are used for the ODM authentication (in ID tokens) and authorization (in access tokens) mechanisms.

    In **Claims** tab, create the following claims:

    * Click **Add claim** 
    * *groups - Access Token* claim:
      * Name: *groups*
      * Include in token type: *Access Token*
      * Value type: *Groups*
      * Filter: **Equals**: *odm-admin*
    * *groups - Id Token* claim:
      * Name: *groups*
      * Include in token type: *Id Token*
      * Value type: *Groups*
      * Filter: **Equals**: odm-admin

    ![Add Claim Result](/images/Okta/ResultAddClaims.png)

4. Verify the content of the token.

    Check that the login name and groups meta-information are available in the ID token.

    In the **Token Preview** tab:
      * OAuth/OIDC client: *ODM Application*
      * Grant type: *Authorization Code*
      * User: ``<YourEmailAddress>``
      * Scopes: *openid* *email*
      * Click **Preview Token**
      * Select the *Token* tab 

    As a result, the payload should contain:

    ```
    ...
    "email": "<YourEmailAddress>",
    "groups": [
      "odm-admin"
    ]
    ```

    ![Token Preview](/images/Okta/TokenPreview.png)

>Note:  The discovery endpoint can be found in **Security** / **API** / **default** / **Settings** in **Metadata URI**.

# Deploy ODM on a container configured with Okta Server (Part 2)

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

### Create secrets to configure ODM with Okta

1. Retrieve Okta Server information.

    From the Okta console, in **Security** / **API** / **default** / **Settings** :
    - Note the *OKTA_SERVER_NAME* which is the **Okta domain** in the **Issuer** (similar to *\<shortname\>.okta.com*).

2. Create a secret with the Okta Server certificate.

    To allow ODM services to access the Okta Server, it is mandatory to provide the Okta Server certificate.
    You can create the secret as follows:

    ```
    keytool -printcert -sslserver <OKTA_SERVER_NAME> -rfc > okta.crt
    kubectl create secret generic okta-secret --from-file=tls.crt=okta.crt
    ```

3. Generate the ODM configuration file for Okta.

    The [script](generateTemplate.sh) allows you to generate the necessary configuration files.
    You can download the [okta-odm-script.zip](okta-odm-script.zip) .zip file to your machine. This .zip file contains the [script](generateTemplate.sh) and the content of the [templates](templates) directory.

    Generate the files with the following command:
    ```
    ./generateTemplate.sh -i <OKTA_CLIENT_ID> -x <OKTA_CLIENT_SECRET> -n <OKTA_SERVER_NAME> -g <OKTA_ODM_GROUP> -s <OKTA_API_SCOPE>
    ```

    Where:
    - *OKTA_API_SCOPE* has been defined [above](#configure-the-default-authorization-server) (*odmapiusers*)
    - *OKTA_SERVER_NAME* has been obtained from [previous step](#retrieve-okta-server-information)
    - Both *OKTA_CLIENT_ID* and *OKTA_CLIENT_SECRET* are listed in your ODM Application, section **Applications** / **Applications** / **ODM Application** / **General** / **Client Credentials**
    - *OKTA_ODM_GROUP* is the ODM Admin group we created in a [previous step](#manage-group-and-user) (*odm-admin*)

    The files are generated into the `output` directory.

4. Create the Okta authentication secret.

    ```
    kubectl create secret generic okta-auth-secret \
        --from-file=OdmOidcProviders.json=./output/OdmOidcProviders.json \
        --from-file=openIdParameters.properties=./output/openIdParameters.properties \
        --from-file=openIdWebSecurity.xml=./output/openIdWebSecurity.xml \
        --from-file=webSecurity.xml=./output/webSecurity.xml
    ```

## Install your ODM Helm release

1. Add the public IBM Helm charts repository.

    ```
    helm repo add ibmcharts https://raw.githubusercontent.com/IBM/charts/master/repo/ibm-helm
    helm repo update
    ```

2. Check that you can access the ODM chart.

    ```
    helm search repo ibm-odm-prod
    NAME                  	CHART VERSION	APP VERSION	DESCRIPTION                     
    ibmcharts/ibm-odm-prod	23.1.0       	8.12.0.0   	IBM Operational Decision Manager
    ```

3. Run the `helm install` command.

    You can now install the product. We will use the PostgreSQL internal database and disable the data persistence (`internalDatabase.persistence.enabled=false`) to avoid any platform complexity concerning persistent volume allocation.

    ```
    helm install my-odm-release ibmcharts/ibm-odm-prod \
          --set image.repository=cp.icr.io/cp/cp4a/odm --set image.pullSecrets=icregistry-secret \
          --set oidc.enabled=true \
          --set internalDatabase.persistence.enabled=false \
          --set customization.trustedCertificateList={"okta-secret"} \
          --set customization.authSecretRef=okta-auth-secret \
          --set license=true
    ```

    > Note: On OpenShift, you have to add the following parameters due to security context constraints.
    > ```
    > --set internalDatabase.runAsUser='' --set customization.runAsUser='' --set service.enableRoute=true
    > ```
    > See [Preparing to install](https://www.ibm.com/docs/en/odm/8.12.0?topic=production-preparing-install-operational-decision-manager) documentation for additional information.

## Complete post-deployment tasks

### Register the ODM redirect URLs

1. Get the ODM endpoints.
    You can refer to the [documentation](https://www.ibm.com/docs/en/odm/8.12.0?topic=tasks-configuring-external-access) to retrieve the ODM endpoints.
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

2. Register the redirect URIs into your Okta application.

    The redirect URIs are built in the following way:

      - Decision Center redirect URI:  `https://<DC_HOST>/decisioncenter/openid/redirect/odm`
      - Decision Runner redirect URI:  `https://<DR_HOST>/DecisionRunner/openid/redirect/odm`
      - Decision Server Console redirect URI:  `https://<DS_CONSOLE_HOST>/res/openid/redirect/odm`
      - Decision Server Runtime redirect URI:  `https://<DS_RUNTIME_HOST>/DecisionService/openid/redirect/odm`
      - Rule Designer redirect URI: `https://127.0.0.1:9081/oidcCallback`

    In **Applications** / **Applications**:
      - Select **ODM Application**.
      - In the **General** tab, click **Edit** on the **General Settings** section.
      - In the **LOGIN** section, click **+ Add URI** in the **Sign-in redirect URIs** section and add the Decision Center redirect URI you got earlier (`https://<DC_HOST>/decisioncenter/openid/redirect/odm` -- do not forget to replace <DC_HOST> by your actual host name!)
      - Repeat the previous step for all other redirect URIs.
      - Click **Save** at the bottom of the LOGIN section.

    ![Sign-in redirect URIs](/images/Okta/Sign-in_redirect_URIs.png)

### Access the ODM services

Well done!  You can now connect to ODM using the endpoints you got [earlier](#register-the-odm-redirect-url), and log in as an ODM admin with the account you created in [the first step](#manage-groups-and-users).

>Note:  Logout in ODM components using Okta authentication raises an error for the time being.  This is a known issue.  We recommend you to use a private window in your browser to log in, so that logout is done just by closing this window.

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
    -Djavax.net.ssl.trustStorePassword=changeme
    -Dcom.ibm.rules.authentication.oidcconfig=<ECLIPSEINITDIR>/OdmOidcProvidersRD.json
    ```
    Where:
    - *changeit* is the fixed password to be used for the default truststore.jks file.
    - *ECLIPSEINITDIR* is the Rule Designer installation directory next to the eclipse.ini file.

4. Restart Rule Designer.

For more information, refer to the [documentation](https://www.ibm.com/docs/en/odm/8.12.0?topic=designer-importing-security-certificate-in-rule).

### Getting Started with IBM Operational Decision Manager for Containers

Get hands-on experience with IBM Operational Decision Manager in a container environment by following this [Getting started tutorial](https://github.com/DecisionsDev/odm-for-container-getting-started/blob/master/README.md).


### Calling the ODM Runtime Service

To manage ODM runtime call on the next steps, we used the [Loan Validation Decision Service project](https://github.com/DecisionsDev/odm-for-container-getting-started/blob/master/Loan%20Validation%20Service.zip)

Import the **Loan Validation Service** in Decision Center connected as John Doe

![Import project](/images/Keycloak/import_project.png)

Deploy the **Loan Validation Service** production_deployment ruleapps using the **production deployment** deployment configuration in the Deployments>Configurations tab.

![Deploy project](/images/Keycloak/deploy_project.png)

You can retrieve the payload.json from the ODM Decision Server Console or use [the provided payload](payload.json)
  
As explained in the ODM on Certified Kubernetes documentation [Configuring user access with OpenID](https://www.ibm.com/docs/en/odm/8.12.0?topic=access-configuring-user-openid), we advise to use basic authentication for the ODM runtime call for performance reasons and to avoid the issue of token expiration and revocation.

You can realize a basic authentication ODM runtime call in the following way:
  
   ```
  $ curl -H "Content-Type: application/json" -k --data @payload.json \
         -H "Authorization: Basic b2RtQWRtaW46b2RtQWRtaW4=" \
        https://<DS_RUNTIME_HOST>/DecisionService/rest/production_deployment/1.0/loan_validation_production/1.0
  ```
  
  Where b2RtQWRtaW46b2RtQWRtaW4= is the base64 encoding of the current username:password odmAdmin:odmAdmin

But if you want to execute a bearer authentication ODM runtime call using the Client Credentials flow, you have to get a bearer access token:
  
  ```
  $ curl -k -X POST -H "Content-Type: application/x-www-form-urlencoded" \
      -d 'client_id=<CLIENT_ID>&scope=<OKTA_API_SCOPE>&client_secret=<CLIENT_SECRET>&grant_type=client_credentials' \
      ' https://<OKTA_SERVER_NAME>/default/v1/token'
  ```
  
 And use the retrieved access token in the following way:
  
   ```
  $ curl -H "Content-Type: application/json" -k --data @payload.json \
         -H "Authorization: Bearer <ACCESS_TOKEN>" \
         https://<DS_RUNTIME_HOST>/DecisionService/rest/production_deployment/1.0/loan_validation_production/1.0
  ```

# Troubleshooting

If you encounter any issue, have a look at the [common troubleshooting explanation](../README.md#Troubleshooting)

# License

[Apache 2.0](/LICENSE)
