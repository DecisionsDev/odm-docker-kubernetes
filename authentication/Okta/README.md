<!-- TOC titleSize:2 tabSpaces:2 depthFrom:1 depthTo:6 withLinks:1 updateOnSave:1 orderedList:0 skip:0 title:1 charForUnorderedList:- -->
## Table of Contents
- [Introduction](#introduction)
  - [What is Okta?](#what-is-okta)
  - [About this task](#about-this-task)
  - [ODM OpenID flows](#odm-openid-flows)
  - [Prerequisites](#prerequisites)
    - [Create an Okta account](#create-an-okta-account)
- [Configure Okta instance for ODM (Part 1)](#configure-okta-instance-for-odm-part-1)
  - [Login OKTA instance](#login-okta-instance)
  - [Manage group and user](#manage-group-and-user)
  - [Setup an application](#setup-an-application)
  - [Configure the default Authorization Server](#configure-the-default-authorization-server)
- [Deploy ODM on container configured with Okta Server (Part 2)](#deploy-odm-on-container-configured-with-okta-server-part-2)
  - [Prepare your environment for the ODM installation](#prepare-your-environment-for-the-odm-installation)
  - [Retrieve Okta Server information](#retrieve-okta-server-information)
  - [Create a secret with the Okta Server certificate](#create-a-secret-with-the-okta-server-certificate)
  - [Create a secret to configure ODM with Okta](#create-a-secret-to-configure-odm-with-okta)
    - [Generate the ODM configuration file for Okta](#generate-the-odm-configuration-file-for-okta)
    - [Create the ODM Okta secret:](#create-the-odm-okta-secret)
  - [Install your ODM Helm release](#install-your-odm-helm-release)
  - [Register the ODM redirect URL](#register-the-odm-redirect-url)
  - [Access the ODM services](#access-the-odm-services)
  - [Setup Rule Designer](#setup-rule-designer)
- [License](#license)
<!-- /TOC -->

# Introduction

In the context of the IBM Cloud Pak for Business Automation or ODM on Certified Kubernetes offering, Operational Decision Manager for production can be configured with an external OpenID Connect server (OIDC Provider) such as Okta service.

## What is Okta?

Okta is a secure identity cloud that links all your apps, logins and devices into a unified digital fabric. Okta sells centralized services, including a single sign-on service that allows users to log into a variety of systems. This is the service we'll use in this article.

## About this task

You need to create a number of secrets before you can install an ODM instance with an external OIDC provider such as Okta service and use web application single sign-on (SSO). The following diagram shows the ODM services with an external OIDC provider after a successful installation.

![ODM web application SSO](/images/Okta/diag_okta_interaction.jpg)

The following procedure describes how to manually configure ODM with an Okta service.

## ODM OpenID flows

OpenID Connect is an authentication standard built on top of OAuth 2.0. It adds an additional token called an ID token.

Terminology:

- The "OpenID provider" — The authorization server that issues the ID token. In this case Okta is the OpenID provider.
- The "end user" — Whose information is contained in the ID token
- The "relying party" — The client application that requests the ID token from Okta
- The "ID token" is issued by the OpenID Provider and contains information about the end user in the form of claims.
- A "claim" is a piece of information about the end user.

The Client Credentials flow is intended for server-side (AKA "confidential") client applications with no end user, which normally describes machine-to-machine communication. The application must be server-side because it must be trusted with the client secret, and since the credentials are hard-coded, it can't be used by an actual end user. It involves a single, authenticated request to the token endpoint, which returns an access token.

![Okta Client Credential Flow](/images/Okta/oauth_client_creds_flow.png) (© Okta)

The Authorization Code flow is best used by server-side apps where the source code isn't publicly exposed. The apps should be server-side because the request that exchanges the authorization code for a token requires a client secret, which has to be stored in your client. The server-side app requires an end user, however, because it relies on interaction with the end user's web browser, which redirects the user and then receives the authorization code.

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

First, sign up for [a free Okta developer account](https://www.okta.com/free-trial/customer-identity/). You can of course skip this section if you already have one. Beware, Okta enforces [rate limits](https://developer.okta.com/docs/reference/rate-limits/) that are obviously lower for free developer accounts than for paid accounts but they should not be a problem for a demo.

# Configure Okta instance for ODM (Part 1)

In this section we will explain how to:

- Manage group and users
- Setup an application
- Configure the default Authorization server

## Login OKTA instance
After activating your account by email, you should have access to your Okta instance. Sign in to Okta

## Manage group and user

First create a group which will contain ODM administrators. It will be referenced as OKTA_ODM_GROUP later in this article:

* Menu Directory / Groups
  * Click Add Group button
    * Name: odm-admin
    * Group Description: ODM Admin group

![Add Group](/images/Okta/AddGroup.png)

Then create at least one user belonging to this new group:

* Menu Directory / People
  * Click 'Add Person' button
    * User type: User
    * First name: ``<YourFirstName>``
    * Last name: ``<YourLastName>``
    * Username: ``<YourEmailAddress>``
    * Primary email: ``<YourEmailAddress>``
    * Groups (optional): **odm-admin**
    * Click Save button

![Add Person](/images/Okta/add_person.png)

Repeat for each user you want to add.

## Setup an application

* Menu Applications -> Applications
  * Click Create an App Integration
    * Select OIDC - OpenID Connect
    * Select Web Application
    * Next

![Add Application](/images/Okta/AddApplication.png)

* App integration name: ODM Application
  * Grant type:
    * Check Client Credentials
    * Check Refresh Token
    * Check Implicit (hybrid)
  * Assignments:
    * Controlled access:
      * Limit access to selected groups:
      * Selected group(s) : **odm-admin**    
  * Click Save button

![New Web Application](/images/Okta/NewWebAppIntegration.png)
![New Web Application Access](/images/Okta/NewWebAppIntegration1.png)

## Configure the default Authorization Server

In this step we will augment the token with meta-information required by the ODM OpenID configuration so ODM can manage both authentication and authorization mechanisms.

- Menu Security -> API
  - Click default link of authorization server

To be more secured we will use the client credential flow for the ODM Rest API call. This requires to create a specific restricted scope (named OKTA_API_SCOPE later in this article).

- Click Scopes tab
- Click 'Add Scope' Button
  - Name : odmapiusers
  - Click 'Create' Button

We need to augment the tokens by the user identifier and group properties that will be used for the ODM authentication (in ID tokens) and authorization (in access tokens) mechanisms.

* Select Claims tab

  * Click 'Add claim' button
    * Name: loginName
    * Include in token type: **Access Token**
    * Value: (appuser != null) ? appuser.userName : app.clientId
    * Click Create Button  

  * Click 'Add claim' button
    * Name: loginName
    * Include in token type: **Id Token**
    * Value: (appuser != null) ? appuser.userName : app.clientId
    * Click Create Button

  * Click 'Add claim' button
    * Name: groups
    * Include in token type: **Access Token**
    * Value type: Groups
    * Equals: odm-admin
    * Click Create Button

  * Click 'Add claim' button
    * Name: groups
    * Include in token type: **Id Token**
    * Value type: Groups
    * Equals: odm-admin
    * Click Create Button

![Add Claim Result](/images/Okta/ResultAddClaims.png)

You can verify the content of the token with the Token Preview panel.

You have to check that the login name and groups are available in the ID token using the authorization flow which the flow used by ODM.

   *  Click the Token Preview
      *  OAuth/OIDC client: ODM Application
      *  Grant type: Authorization Code
      *  User: ``<YourEmailAddress>``
      *  Scopes: odmapiusers
      * Click the Preview Token button

As result the id_token tab as well as in the token tab should contains:

```...
    "loginName": "<YourEmailAddress>",
    "groups": [
      "odm-admin"
    ]
```

![Token Preview](/images/Okta/TokenPreview.png)

>Note:  The discovery endpoint can be found in Security / API / default as Metadata URI.

# Deploy ODM on container configured with Okta Server (Part 2)

## Prepare your environment for the ODM installation

Log in to [MyIBM Container Software Library](https://myibm.ibm.com/products-services/containerlibrary) with the IBMid and password that are associated with the entitled software to get your entitlement key.

In the Container software library tile, verify your entitlement on the View library page, and then go to Get entitlement key to retrieve the key.

Create a pull secret by running a kubectl create secret command.

```
$ kubectl create secret docker-registry icregistry-secret \
    --docker-server=cp.icr.io \
    --docker-username=cp \
    --docker-password="<API_KEY_GENERATED>" \
    --docker-email=<USER_EMAIL>
```

where:

- API_KEY_GENERATED is the entitlement key from the previous step. Make sure you enclose the key in double-quotes.
- USER_EMAIL is the email address associated with your IBMid.

>Note: The cp.icr.io value for the docker-server parameter is the only registry domain name that contains the images. You must set the docker-username to cp to use an entitlement key as docker-password.

Make a note of the secret name so that you can set it for the image.pullSecrets parameter when you run a helm install of your containers. The image.repository parameter will later be set to cp.icr.io/cp/cp4a/odm.

## Retrieve Okta Server information

The following steps require to retrieve this informations from Okta console:

- Log into Okta console
- Go to Application / Application / ODM Application
- Note the following informations:
  - OKTA_SERVER_NAME which is the Okta domain in the General Settings of the application (it will be something like "\<shortname\>.okta.com").
  - OKTA_CLIENT_ID which is the identifier for the OpenID client
  - OKTA_CLIENT_SECRET which is the secret used by the client to exchange an authorization code for a token.

![Application Informations](/images/Okta/ApplicationInfo.png)

## Create a secret with the Okta Server certificate

To allow ODM services to access Okta Server, it is mandatory to provide the Okta Server certificate.
You can create the secret as follow:

```
keytool -printcert -sslserver <OKTA_SERVER_NAME> -rfc > okta.crt
kubectl create secret generic okta-secret --from-file=tls.crt=okta.crt
```

## Create a secret to configure ODM with Okta

To configure ODM with Okta, we need to provide 4 files:

- OdmOidcProviders.json to configure the Okta OpenId provider using the client_credentials flow (it’s used by the DC servers to connect to the Decision Server Console and the Decision Runner)
- openIdParameters.properties to configure ODM REST-API and web application (logout and allowed domains in web.xml)
- openIdWebSecurity.xml to configure the liberty OpenId connect client relying party
- webSecurity.xml to provide a mapping between liberty roles and Okta groups/users to manage authorization

### Generate the ODM configuration file for Okta

- Download the [okta-odm-script.zip](okta-odm-script.zip) zip file in your machine. This zip file contains the  [script](generateTemplate.sh) and the content of the [templates](templates) directory.
- Unzip the [okta-odm-script.zip](okta-odm-script.zip) zip file in your machine.
- Execute the generateTemplate.sh script file:

```
./generateTemplate.sh -i OKTA_CLIENT_ID -x OKTA_CLIENT_SECRET -n OKTA_SERVER_NAME -g OKTA_ODM_GROUP -s OKTA_API_SCOPE
```
Where:
- OKTA_SERVER_NAME has been obtained from [previous step](#retrieve-okta-server-information)
- Both OKTA_CLIENT_ID and OKTA_CLIENT_SECRET are listed in your ODM Application, section General / Client Credentials [previous step](#retrieve-okta-server-information)
- OKTA_API_SCOPE has been defined [above](#configure-the-default-authorization-server) (odmapiusers)
- OKTA_ODM_GROUP is the ODM Admin group we created in a [previous step](#manage-group-and-user) (odm-admin)

As result the script will generate these 4 files according to your OKTA_SERVER_NAME, OKTA_CLIENT_ID, OKTA_CLIENT_SECRET and OKTA_ODM_GROUP parameters in the output directory.

### Create the ODM Okta secret:

```
kubectl create secret generic okta-auth-secret \
    --from-file=OdmOidcProviders.json=./output/OdmOidcProviders.json \
    --from-file=openIdParameters.properties=./output/openIdParameters.properties \
    --from-file=openIdWebSecurity.xml=./output/openIdWebSecurity.xml \
    --from-file=webSecurity.xml=./output/webSecurity.xml
```

## Install your ODM Helm release

Add the public IBM Helm charts repository:

```
helm repo add ibmcharts https://raw.githubusercontent.com/IBM/charts/master/repo/entitled
helm repo update
```

Check you can access ODM's chart:

```
helm search repo ibm-odm-prod
NAME                  	CHART VERSION	APP VERSION	DESCRIPTION                     
ibmcharts/ibm-odm-prod	21.3.0       	8.11.0.0   	IBM Operational Decision Manager
```

You can now install the product. We will use the PostgreSQL internal database and disable the data persistence (internalDatabase.persistence.enabled=false) to avoid any platform complexity concerning persistent volume allocation.

```
helm install release ibmcharts/ibm-odm-prod \
        --set image.repository=cp.icr.io/cp/cp4a/odm --set image.pullSecrets=icregistry-secret \
        --set oidc.enabled=true \
        --set internalDatabase.persistence.enabled=false \
        --set customization.trustedCertificateList={"okta-secret"} \
        --set customization.authSecretRef=okta-auth-secret \
        --set service.enableRoute=true
```

Note: On OpenShift, you have to add the following parameters due to security context constraint:

```
--set internalDatabase.runAsUser='' --set customization.runAsUser=''
```

(See https://www.ibm.com/docs/en/odm/8.11.0?topic=production-preparing-install-operational-decision-manager for additional information.)

## Register the ODM redirect URL

Get the [endpoints](https://www.ibm.com/docs/en/odm/8.11.0?topic=production-configuring-external-access). On OpenShift, you can get the routes names and hosts with:

```
kubectl get routes --no-headers --output custom-columns=":metadata.name,:spec.host"
```

You should get something like :
```
release-odm-dc-route           release-odm-dc-route-odm1.apps.pylocp49.cp.fyre.ibm.com
release-odm-dr-route           release-odm-dr-route-odm1.apps.pylocp49.cp.fyre.ibm.com
release-odm-ds-console-route   release-odm-ds-console-route-odm1.apps.pylocp49.cp.fyre.ibm.com
release-odm-ds-runtime-route   release-odm-ds-runtime-route-odm1.apps.pylocp49.cp.fyre.ibm.com
```

The redirect URIs are built this way:

- Decision Center redirect URI:  https://<DC_HOST>/decisioncenter/openid/redirect/odm
- Decision Runner redirect URI:  https://<DR_HOST/DecisionRunner/openid/redirect/odm
- Decision Server Console redirect URI:  https://<DS_CONSOLE_HOST>/res/openid/redirect/odm
- Decision Server Runtime redirect URI:  https://<DS_RUNTIME_HOST>/DecisionService/openid/redirect/odm
- Rule Designer redirect URI: https://127.0.0.1:9081/oidcCallback

Where:
   - DC_HOST: The Decision Center endpoint
   - DR_HOST: The Decision Runner endpoint
   - DC_CONSOLE_HOST: The Decision Server Console endpoint
   - DS_RUNTIME_HOST: The Decision Server Runtime endpoint

You must register these endpoints into your Okta application:

- Menu Applications / Applications
  - Select ODM Application.
  - On the General tab, click Edit on the General Settings section.
  - In the LOGIN section, click on + Add URI in the Sign-in redirect URIs section and add the Decision Center redirect URI you got earlier (https://<DC_HOST>/decisioncenter/openid/redirect/odm -- don't forget to replace <DC_HOST> by your actual host name!)
  - Repeat the previous step for all other four redirect URIs.
  - Click Save at the bottom of the LOGIN section.

![Sign-in redirect URIs](/images/Okta/Sign-in_redirect_URIs.png)

## Access the ODM services

Well done!  You can now connect to ODM using the endpoints you got [earlier](#register-the-odm-redirect-url) and log in as an ODM admin with the account you created in [the first step](#manage-group-and-user).

>Note:  Logout in ODM components using Okta authentication raises an error for the time being.  This is a known issue.  We recommend to use a private window in your browser to log in, so that logout is done just by closing this window.

## Setup Rule Designer

To be able to securely connect your Rule Designer to the Decision Server and Decision Center services that are running in Certified Kubernetes, you need to establish a TLS connection through a security certificate as well as the OpenID configuration.

* Get the https://<DC_HOST>/decisioncenter/assets/truststore.jks file.
* Get the https://<DC_HOST>/odm/decisioncenter/assets/OdmOidcProvidersRD.json file.
where DC_HOST is the Decision Center endpoint.

* Copy the truststore.jks and OdmOidcProvidersRD.json files to your Rule Designer installation directory next to the eclipse.ini file.
* Add these properties settings at the end of your eclipse.ini file

Edit your eclipse.ini file and add this following lines at the end:

```
-Djavax.net.ssl.trustStore=<ECLIPSEINITDIR>/truststore.jks
-Djavax.net.ssl.trustStorePassword=changeit
-Dcom.ibm.rules.authentication.oidcconfig=<ECLIPSEINITDIR>/OdmOidcProvidersRD.json
```

where:
- changeit is the fixed password to be used for the default truststore.jks file.
- ECLIPSEINITDIR : The Rule Designer installation directory next to the eclipse.ini file

Restart Rule Designer.

https://www.ibm.com/docs/en/odm/8.11.0?topic=designer-importing-security-certificate-in-rule

# License

[Apache 2.0](/LICENSE)
