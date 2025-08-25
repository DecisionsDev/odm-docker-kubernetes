# Configuration of ODM with Amazon Cognito

<!-- TOC -->

- [Configuration of ODM with Amazon Cognito](#configuration-of-odm-with-amazon-cognito)
- [Introduction](#introduction)
    - [What is Amazon Cognito?](#what-is-amazon-cognito)
    - [About this task](#about-this-task)
    - [ODM OpenID flows](#odm-openid-flows)
    - [Prerequisites](#prerequisites)
- [Create a Cognito User Pool Part 1](#create-a-cognito-user-pool-part-1)
    - [Initiate the creation of the Cognito User Pool](#initiate-the-creation-of-the-cognito-user-pool)
    - [Create A User](#create-a-user)
    - [Create an ODM Admin Group](#create-an-odm-admin-group)
    - [Add the created user to the odm-admin group](#add-the-created-user-to-the-odm-admin-group)
    - [Create a dedicated App client for the client-credentials flow](#create-a-dedicated-app-client-for-the-client-credentials-flow)
    - [Create a custom claim](#create-a-custom-claim)
- [Deploy ODM on a container configured with Cognito Part 2](#deploy-odm-on-a-container-configured-with-cognito-part-2)
    - [Prepare your environment for the ODM installation](#prepare-your-environment-for-the-odm-installation)
        - [Create a secret to use the Entitled Registry](#create-a-secret-to-use-the-entitled-registry)
        - [Create secrets to configure ODM with Cognito](#create-secrets-to-configure-odm-with-cognito)
    - [Install your ODM Helm release](#install-your-odm-helm-release)
        - [Add the public IBM Helm charts repository](#1-add-the-public-ibm-helm-charts-repository)
        - [Check that you can access the ODM chart](#2-check-that-you-can-access-the-odm-chart)
        - [Run the helm install command](#3-run-the-helm-install-command)
            - [a. Installation on OpenShift using Routes](#a-installation-on-openshift-using-routes)
            - [b. Installation using Ingress](#b-installation-using-ingress)
    - [Complete post-deployment tasks](#complete-post-deployment-tasks)
        - [Register the ODM redirect URL](#register-the-odm-redirect-url)
        - [Access the ODM services](#access-the-odm-services)
        - [Set up Rule Designer](#set-up-rule-designer)
        - [Getting Started with IBM Operational Decision Manager for Containers](#getting-started-with-ibm-operational-decision-manager-for-containers)
        - [Calling the ODM Runtime Service](#calling-the-odm-runtime-service)
- [Troubleshooting](#troubleshooting)
- [License](#license)

<!-- /TOC -->

# Introduction

In the context of the Operational Decision Manager (ODM) on Certified Kubernetes offering, ODM for production can be configured with an external OpenID Connect server (OIDC provider), such as Amazon Cognito .

## What is Amazon Cognito?

[Amazon Cognito](https://docs.aws.amazon.com/cognito/latest/developerguide/what-is-amazon-cognito.html) is an identity platform for web and mobile apps. It’s a user directory, an authentication server, and an authorization service for OAuth 2.0 access tokens and AWS credentials. With Amazon Cognito, you can authenticate and authorize users from the built-in user directory, from your enterprise directory, and from consumer identity providers like Google and Facebook.

## About this task

You need to create a number of secrets before you can install an ODM instance with an external OIDC provider such as Amazon Cognito, and use web application single sign-on (SSO). The following diagram shows the ODM services with an external OIDC provider after a successful installation.

![ODM web application SSO](images/diag_azuread_interaction.jpg)

The following procedure describes how to manually configure ODM with an Amazon Cognito User Pool.

## ODM OpenID flows

OpenID Connect is an authentication standard built on top of OAuth 2.0. It adds a token called an ID token.

Terminology:

- **OpenID provider** — The authorization server that issues the ID token. In this case, Microsoft Entra ID is the OpenID provider.
- **end user** — The end user whose details are contained in the ID token.
- **relying party** — The client application that requests the ID token from Amazon Cognito.
- **ID token** — The token that is issued by the OpenID provider and contains information about the end user in the form of claims.
- **claim** — A piece of information about the end user.

The Authorization Code flow is best used by server-side apps in which the source code is not publicly exposed. The apps must be server-side because the request that exchanges the authorization code for a token requires a client secret, which has to be stored in your client. However, the server-side app requires an end user because it relies on interactions with the end user's web browser which redirects the user and then receives the authorization code.

![Authentication flow](images/AuthenticationFlow.png) (© Microsoft)

The Client Credentials flow is intended for server-side (AKA "confidential") client applications with no end user, which normally describes machine-to-machine communication. The application must be server-side because it must be trusted with the client secret, and since the credentials are hard-coded, it cannot be used by an actual end user. It involves a single, authenticated request to the token endpoint which returns an access token.

![Microsoft Entra ID Client Credential Flow](images/ClientCredential.png) (© Microsoft)

The OAuth 2.0 Resource Owner Password Credentials (ROPC) grant flow, also named password flow is not supported by Amazon Cognito because not considered as enough secured.
  

## Prerequisites

You need the following elements:

- [Helm v3](https://helm.sh/docs/intro/install/)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl)
- Access to an Operational Decision Manager product
- Access to a CNCF Kubernetes cluster
- An [AWS Account](https://aws.amazon.com/getting-started/)

# Create a Cognito User Pool (Part 1)

The first step to integrate ODM with Cognito is to create a [Cognito User Pool](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-identity-pools.html) which will behaves as the OpenID Connect (OIDC) identity provider (IdP), also named OP for OpenId Provider.

![The Cognito User Pool](images/CognitoUserPool.png) (© Amazon)

## Initiate the creation of the Cognito User Pool

To create the Cognito User Pool dedicated to ODM, we followed the [getting started](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pool-as-user-directory.html) by applying the following settings. It doesn't mean that with your production or demo application, you cannot apply different settings. But, for this tutorial, it's preferable to keep the name that we propose.

1. Create an Amazon Cognito User pool

    * In **All services**, click the **Cognito** link (under the section "Security, Identity, & Compliance")
    * In the new page, Select the **User pools** tab, then click the **Create user pool** button
      * Select *Applicaton Type* = **Traditional web application**
      * Set *Name your application* = **odm**
      * Select *Options for sign-in identifiers* = **Email**
      * Click the **Create user directory** button
    * Scroll down the new page and click the **Go to overview** button

2. Rename the new Cognito user pool

    * Click the **Rename** button
    * Enter *User pool name* = **odmuserpool**

3. Authentication > Authentication methods

    * Select **Authentication methods** under **Authentication** in the left pane

    ![Authentication methods](images/authentication-methods.png)

    * Click **Edit** in the **Email** pane

      * Select *Email provider* = **Send email with Cognito**
      * In *FROM email address*, keep default **no-reply@verificationemail.com**
      * Click the **Save changes** button

    * (optionally) Click **Edit** in the **SMS** pane

      * Select *IAM role* = **Create a new IAM role**
      * Enter *IAM role name* = **odmsmsrole**
      * Click the **Save changes** button

    We are not using SMS in this tutorial. So, there is no need to  "Configure AWS service dependencies to complete your SMS message setup" section.

    * Click **Edit** in the **Password policy** pane

      * Select *Password policy mode* = **Cognito defaults**

4. Authentication > Sign-in

    * Select **Sign-in** under **Authentication** in the left pane

    ![Sign-in](images/sign-in.png)

    * Click **Edit** in the **Multi-factor authentication** pane

      * Select *MFA enforcement* = **No MFA**
      * Click the **Save changes** button

    * Click **Edit** in the **User account recovery** pane

      * Select **Enable self-service account recovery - Recommended**
      * Click the **Save changes** button

5. Authentication > Sign-up

    * Select **Sign-up** under **Authentication** in the left pane

    ![Sign-up](images/sign-up.png)

    * Click **Edit** in the **Attribute verification and user account confirmation** pane

      * Select *Automatically send* = **Allow cognito to automatically send messages to verify and confirm - Recommended** under *Cognito-assisted verification and confirmation*
      * Select *Attributes to verify* = **Send email message, verify email address**
      * Enable **Keep original attribute value active when an update is pending - Recommended** under *Verifying attribute changes*
      * Select *Active attribute values when an update is pending* = **Email address**
      * Click the **Save changes** button

    * Click **Edit** in the **Self-service sign-up** pane

      * Select **Enable self-registration**
        
6. Applications > App clients

    * Select **App clients** under **Applications** in the left pane

      * Under *App clients*, click **odm**

        * in the *App client information* pane
          * take a note of the **Client ID** and **Client secret**
          * click **Edit**
            * Select the following *Authentication flows*:
              * **Sign in with username and password: ALLOW_USER_PASSWORD_AUTH**
              * **Sign in with secure remote password (SRP): ALLOW_USER_SRP_AUTH**
              * **Get new user tokens from existing authenticated sessions: ALLOW_REFRESH_TOKEN_AUTH**
            * Click the **Save changes** button
        
        * Under the **Login pages** tab

          * click **Edit** in the *Managed login pages configuration* pane
            * *Allowed callback URLs* : to be filled up once ODM is deployed and the redirect URIs are known
            * *Identity providers* = **Cognito user pool**
            * *OAuth 2.0 grant types* = **Authorization code grant**
            * *OpenID Connect Scopes* = **Email**, **OpenID**, **Phone**

        * Under the **Attribute permissions** tab
          * leave the default read and write permissions 

## Create A User

* Select the **odmuserpool** User Pool:
  * Select **Users** under *User Management* in the left-hand pane:
    * Click on **Create user**

    In **User information**:
       * **Invitation message**:
         * Select **Send an email invitation**
       * **Email address**:
         * Enter the wanted email address
       * **Temporary password**:
         * Select **Generate a password**
       * Click on **Create user**
    
## Create an ODM Admin Group

* Select the **odmuserpool** User Pool:
  * Select **Groups** under *User Management* in the left-hand pane:
    * Click on **Create group**      

   In **Group information**:
     * **Group name**:
       * Enter the **odm-admin** name
> [!WARNING]
> Please do not use a different name than **odm-admin** 

 * Click on **Create group**

## Add the created user to the **odm-admin** group

* Select the **odmuserpool** User Pool:
  * Select the **Groups** tab:
    * Click on the **odm-admin** group
   
   In the **Group members** part:
     * Click on **Add user to group**

   In the **User selection** part:
     * Select the previously created user
     * Click on **Add**

## Create a dedicated App client for the client-credentials flow

Cognito does not currently enable an application client to provide both the Authorization code grant flow and the Client-credentials flow.
So an additional application client must be created (within the same Cognito User Pool) to provide the Client-credentials flow.
The Client-credentials flow will be used for M2M (Machine to Machine) communication. 
It will enable communication between Decision Center and the Decision Server Console for ruleapp deployment. 
It will also enable the communication between Decision Center and Decision Runner for tests and simulation.

A Resource Server needs to be created to use the client-credentials flow and some custom scopes need to be configured. A scope is a level of access that an app can request to a resource.
To get more details about scopes and resource server, you can read [OAuth 2.0 scopes and API authorization with resource servers](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-define-resource-servers.html?icmpid=docs_cognito_console_help_panel)


1. Create a Resource Server

  * Select the **odmuserpool** User Pool
  * Click **Domain** under *Branding* in the left-hand pane
  * Click the **Create resource server** button in the **Resource servers** pane
    * In **Resource server**:
      * Set *Resource server name* = **ODMClientCredentialsServer**
      * Set *Resource server identifier* = **odmcc**
    * In **Custom scopes**, create 2 scopes:
      * Click the **Add custom scope** button
      * Set *Scope name* = **read**
      * Set *Description* = **for GET requests**
      * Click the **Add another** button
      * Set *Scope name* = **write**
      * Set *Description* = **for POST requests**
    * Click the **create resource server** button 

![Create Resource Server](images/CreateResourceServer.png)

2. Create a new client application

  * Select the **odmuserpool** User Pool
  * Click **App clients** under *Application* in the left-hand pane
    * Click the **Create app client** button in the *App clients* pane
      * Select *Application type* = **Machine-to-machine application**
      * Enter *App client name* = **odmclientcredentials**
      * Click the **Create app client** button

    <!-- IS THE 'ALLOW_USER_SRP_AUTH' REALLY NECESSARY ?-->
    * Click the **Edit** button in the *App client information* pane
      * Enable the *Authentication flows* = **Sign in with secure remote password (SRP): ALLOW_USER_SRP_AUTH**

    * Click the **Login pages** tab and then the **Edit** button in the *Managed login pages configuration* pane
      * Keep *Identity providers* = **Cognito user pool**
      * Keep *OAuth 2.0 grant types* = **Client credentials**
      * Select *Custom scopes* = **odmcc/read** and **odmcc/write**
      * Click the **Save changes** button

![Client-Credentials App](images/ClientCredentialsApp.png)
    
## Create a custom claim

A custom claim needs to be added to both:
* the id_token (issued during the authorization flow), and
* the access_token (issued for the client-credentials flow). 

Indeed, the existing **sub** claim is not be suitable because its value is an automatically generated unique identifier and we would rather have the user's name or email address displayed in ODM consoles UI instead. 

We will manage it the same way we do it with Azure AD creating an [**identity** custom claim](https://github.com/DecisionsDev/odm-docker-kubernetes/blob/master/authentication/AzureAD/README_WITH_CLIENT_SECRET.md#set-up-an-microsoft-entra-id-application-using-a-client-secret).

[Since 2025](https://aws.amazon.com/blogs/security/how-to-customize-access-tokens-in-amazon-cognito-user-pools/), it is now possible to add custom claims to the Cognito access_token using the client-credentials flow.

We will use the [pre token generation lambda trigger](https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-lambda-pre-token-generation.html) to add the **identity** claim inside the id_token that will take the **email** value when a user is connecting to an UI (Decision Center or RES Console)  using the authentication flow, and inside the access_token using the client-credentials flow.
Here are the details about the [Pre token generation Lambda trigger flow](https://aws.amazon.com/blogs/security/how-to-customize-access-tokens-in-amazon-cognito-user-pools/).

![Pre Token Generation](images/pre-token-generation.png)

> [!WARNING]
> The customization of the access token claims is not possible with the Lite plan. It's possible to manage it with the Essentials or Plus plan.
> You can change of plan using the Settings tab

![Cognito Plan](images/CognitoPlan.png) 


1. Add a Pre token generation Lambda trigger

We will use the pre token generation lambda trigger feature to the **identity** claim in in id_token by pushing the user email value.

Select the **odmuserpool** User Pool:
  * Select the **User pool properties** tab:
    * On the **Lambda triggers** section:
      * Click the **Add Lambda trigger** button

In **Lambda triggers**:
  * Select **Authentication**
    In **Authentication**:
      * Select **Pre token generation trigger** (Modify claims in ID and access tokens.)
    In **Trigger event version**
      * Select **Basic features + access token customization for user and machine identities - Recommended** (Your user pool sends a version 3 event to your Lambda function. You can customize access tokens for M2M.
)

In **Lambda function**:
    * Click on the **Create Lambda function** button

2. Create a Lambda Function

Now, you are in the **AWS Lambda** service dashboard.

Select **Functions** in the left menu:
  * Click on the **Create function** button
  
In the **Create function** section:
  * choose **Author from scratch**

In **Basic information**:
  * In **function name**
    * Enter **odmLambdaFunction**

Click on the **Create function** button

In the **Code>Code source** section:
  * Replace the default index.jms code with the code below

```
export const handler = function(event, context) {
  console.debug("enter in ODM lambda");
  // Allow to get debug information in the Watcher
  console.debug("context");
  console.debug(context);
  
  console.debug("event");
  console.debug(event);
  console.debug("clientId");
  console.debug(event.callerContext.clientId);

  console.debug("userAttributes");
  console.debug(event.request.userAttributes);

  var identity_for_access_token = event.callerContext.clientId;
  if (event.request.userAttributes.email != undefined) {
    console.debug("user email is defined. Use user email as claim identity for the access_token - Rule Designer Context");
    identity_for_access_token = event.request.userAttributes.email
  } else {
    console.debug("user email is undefined. Use clienId as claim identity for the access_token - M2M Context with client-credentials");
  }
  console.debug(identity_for_access_token);
  event.response = {
    "claimsAndScopeOverrideDetails": {
      "idTokenGeneration": {
        "claimsToAddOrOverride": {
          "identity": event.request.userAttributes.email
    }
      },
      "accessTokenGeneration": {
        "claimsToAddOrOverride": {
          "identity": identity_for_access_token
    }
      },
    }
  };
  // Return to Amazon Cognito
  context.done(null, event);
};
```
> [!WARNING]
> Do not forget to click on the **Deploy** button !

3. Associate the Lamda function to the Pre token generation Lambda trigger

Back to the **Pre token generation Lambda trigger** creation dashboard
   * Click on the **Assign Lambda function** Refresh button
   * Select **odmLambdaFunction**
   * Click on the **Add Lambda trigger** button

![Add Lambda Trigger](images/AddLambdaTrigger.png)



# Deploy ODM on a container configured with Cognito (Part 2)

## Prepare your environment for the ODM installation

### Create a secret to use the Entitled Registry


In the **Container software library** tile, verify your entitlement on the **View library** page, and then go to **Get entitlement key**  to retrieve the key.

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



### Create secrets to configure ODM with Cognito



1. Create a secret with the Cognito Server certificate

    To allow ODM services to access the Cognito Server, it is mandatory to provide the Cognito Server certificates.
    With Cognito, we need to access :
    * cognito-idp.<COGNITO_REGION>.amazonaws.com
    * <COGNITO_DOMAIN_NAME>.auth.<COGNITO_REGION>.amazoncognito.com
   
    You can create the secret as follows:

    ```
    keytool -printcert -sslserver cognito-idp.<COGNITO_REGION>.amazonaws.com -rfc > cognito-idp.crt
    kubectl create secret generic cognito-idp-cert-secret --from-file=tls.crt=cognito-idp.crt

    keytool -printcert -sslserver <COGNITO_DOMAIN_NAME_PREFIX>.auth.<COGNITO_REGION>.amazoncognito.com -rfc > cognito-auth.crt
    kubectl create secret generic cognito-domain-cert-secret --from-file=tls.crt=cognito-auth.crt
    ```
    Where:
    - *COGNITO_REGION* is the region where the COGNITO User Pool is deployed
    - *COGNITO_DOMAIN_NAME_PREFIX* is the prefix name of the COGNITO User Pool Domain that you can retrieve at Amazon Cognito > User pools > odmuserpool > Domain (odm in our tutorial)
  
3. Generate the ODM configuration file for Cognito

    If everything is well configured, the Cognito End-Points must be accessible at :
    https://cognito-idp.COGNITO_REGION.amazonaws.com/COGNITO_USER_POOL_ID/.well-known/openid-configuration  <!-- markdown-link-check-disable-line -->

    Where:
    - *COGNITO_REGION* is the region where the COGNITO User Pool is deployed
    - *COGNITO_USER_POOL_ID* is the COGNITO User Pool ID retrieved at Amazon Cognito > User pools > odmuserpool > Overview > User pool ID
    

    The script [generateTemplate.sh](generateTemplate.sh) allows you to generate the necessary configuration files.
    
    This script is available in the present project and requires some companion files in the project as well. So please clone/download the project at this point if you have not done this already.

    Generate the files with the following command:
    ```
    ./generateTemplate.sh -u COGNITO_USER_POOL_ID -d COGNITO_DOMAIN_NAME_PREFIX -r COGNITO_REGION -i COGNITO_APP_CLIENT_ID -s COGNITO_APP_CLIENT_SECRET -c COGNITO_CC_CLIENT_ID -x COGNITO_CC_CLIENT_SECRET
    ```

  - *COGNITO_USER_POOL_ID* is the COGNITO User Pool ID retrieved at Amazon Cognito > User pools > odmuserpool > Overview > User pool ID
  - *COGNITO_DOMAIN_NAME_PREFIX* is the prefix name of the COGNITO User Pool Domain that you can retrieve at Amazon Cognito > User pools > odmuserpool > Domain (odm in our tutorial)
> [!WARNING]
> only the prefix of the domain ('odm' in our tutorial) should be provided and not the entire value <COGNITO_DOMAIN_NAME_PREFIX>.auth.<COGNITO_REGION>.amazoncognito.com

  - *COGNITO_REGION* is the region where the COGNITO User Pool is deployed
  - *COGNITO_APP_CLIENT_ID* is the COGNITO ODM App Client ID retrieved at Amazon Cognito > User pools > odmuserpool > App integration > odm > Client ID
  - *COGNITO_APP_CLIENT_SECRET* is the COGNITO ODM App Client Secret retrieved at Amazon Cognito > User pools > odmuserpool > App integration > odm > Client Secret
  - *COGNITO_CC_CLIENT_ID* is the COGNITO ODM Client-Credentials App Client ID retrieved at Amazon Cognito > User pools > odmuserpool > App integration > odmclientcredentials > Client ID
  - *COGNITO_CC_CLIENT_SECRET* is the COGNITO ODM Client-Credentials App Client Secret retrieved at Amazon Cognito > User pools > odmuserpool > App integration > odmclientcredentials > Client Secret

    Here is an example of the command line:
    ```
    ./generateTemplate.sh \
        -u odmuserpool \
        -d odm \
        -r eu-west-3 \
        -i 7qo....................... \
        -s rrt................................................ \
        -c 6io....................... \
        -x c5b................................................
    ```

    The four files below are generated into a directory named `output` (generated by the script):

    - webSecurity.xml contains the mapping between Liberty J2EE ODM roles and Cognito User Pool groups and users:
      * rtsAdministrators/resAdministrators/resExecutors ODM roles are given to the CLIENT_ID (which is seen as a user) to manage the client-credentials flow
    - openIdWebSecurity.xml contains two openIdConnectClient Liberty configurations:
      * for web access to Decision Center an Decision Server consoles using userIdentifier="client_id" with the Authorization Code flow
      * for the rest-api call using userIdentifier="client_id" with the client-credentials flow
    - openIdParameters.properties configures several features like allowed domains, logout, and some internal ODM openid features
    - OdmOidcProviders.json configures the connection to the RES Console using the Client Credentials grant type

4. Create the Cognito authentication secret

    ```
    kubectl create secret generic cognito-auth-secret \
        --from-file=openIdParameters.properties=./output/openIdParameters.properties \
        --from-file=openIdWebSecurity.xml=./output/openIdWebSecurity.xml \
        --from-file=webSecurity.xml=./output/webSecurity.xml \
        --from-file=OdmOidcProviders.json=./output/OdmOidcProviders.json
    ```


## Install your ODM Helm release
### 1. Add the public IBM Helm charts repository

  ```shell
  helm repo add ibm-helm https://raw.githubusercontent.com/IBM/charts/master/repo/ibm-helm
  helm repo update
  ```

### 2. Check that you can access the ODM chart

  ```shell
  helm search repo ibm-odm-prod
  NAME                          CHART VERSION   APP VERSION     DESCRIPTION
  ibm-helm/ibm-odm-prod         25.0.0          9.5.0.0        IBM Operational Decision Manager
  ```

### 3. Run the `helm install` command


#### a. Installation on OpenShift using Routes

  See the [Preparing to install](https://www.ibm.com/docs/en/odm/9.5.0?topic=production-preparing-install-operational-decision-manager) documentation for more information. Inspect [cognito-values.yaml](cognito-values.yaml) for the parameters that have been defined for this installation.

  ```shell
  helm install my-odm-release ibm-helm/ibm-odm-prod -f cognito-values.yaml
  ```

> **Note:**  
> This command installs the **latest available version** of the chart.  
> If you want to install a **specific version**, add the `--version <CHART_VERSION>` option, eg. `--version 25.0.0`
>

#### b. Installation using Ingress

  Refer to the following documentation to install an NGINX Ingress Controller on:
  - [Microsoft Azure Kubernetes Service](../../platform/azure/README-NGINX.md)
  - [Amazon Elastic Kubernetes Service](../../platform/eks/README-NGINX.md)
  - [Google Kubernetes Engine](../../platform/gcloud/README_NGINX.md)

  When the NGINX Ingress Controller is ready, you can install the ODM release using [cognito-nginx-values.yaml](cognito-nginx-values.yaml). Take note of the `service.ingress.annotations` values that have been defined in this file.:

  ```
  helm install my-odm-release ibm-helm/ibm-odm-prod -f cognito-nginx-values.yaml
  ```

## Complete post-deployment tasks

### Register the ODM redirect URL


1. Get the ODM endpoints.
    Refer to [this documentation](https://www.ibm.com/docs/en/odm/9.5.0?topic=tasks-configuring-external-access) to retrieve the endpoints.
    For example, on OpenShift you can get the route names and hosts by running `oc get routes`:

    ```
    NAME                                  HOST/PORT
    my-odm-release-odm-dc-route           <DC_HOST>
    my-odm-release-odm-dr-route           <DR_HOST>
    my-odm-release-odm-ds-console-route   <DS_CONSOLE_HOST>
    my-odm-release-odm-ds-runtime-route   <DS_RUNTIME_HOST>
    ```

    Using an Ingress, the endpoint is the address of the ODM ingress and is the same for all components. You can get it with:

    ```
    kubectl get ingress my-odm-release-odm-ingress
    ```

   You get the following ingress address:
    ```
    NAME                       CLASS    HOSTS   ADDRESS          PORTS   AGE
    my-odm-release-odm-ingress <none>   *       <INGRESS_ADDRESS>   80      14d
    ```

2. Register the redirect URIs into your Cognito App Client.

    The redirect URIs are built in the following way:

      Using Routes:
      - Decision Center redirect URI:  `https://<DC_HOST>/decisioncenter/openid/redirect/odm`
      - Decision Runner redirect URI:  `https://<DR_HOST>/DecisionRunner/openid/redirect/odm`
      - Decision Server Console redirect URI:  `https://<DSC_HOST>/res/openid/redirect/odm`
      - Decision Server runtime redirect URI:  `https://<DSR_HOST>/DecisionService/openid/redirect/odm`
      - Rule Designer redirect URI: `https://127.0.0.1:9081/oidcCallback`

      Using Ingress:
      - Decision Center redirect URI:  `https://<INGRESS_ADDRESS>/decisioncenter/openid/redirect/odm`
      - Decision Runner redirect URI:  `https://<INGRESS_ADDRESS>/DecisionRunner/openid/redirect/odm`
      - Decision Server Console redirect URI:  `https://<INGRESS_ADDRESS>/res/openid/redirect/odm`
      - Decision Server Runtime redirect URI:  `https://<INGRESS_ADDRESS>/DecisionService/openid/redirect/odm`
      - Rule Designer redirect URI: `https://127.0.0.1:9081/oidcCallback`

   From the Cognito admin console, in **odmuserpool** / **App clients** / **odm** 
    - Select the **Login pages** tab
    - Click the **Edit** button in the *Managed login pages configuration*
      - Add all five redirect URIs in the **Allowed callback URLs** field for all components.
          eg. `https://<DC_HOST>/decisioncenter/openid/redirect/odm` for Decision Center
      - Click **Save changes** at the bottom of the page.
> [!WARNING]
> Do not forget to replace <DC_HOST> with your actual host name


### Access the ODM services


### Set up Rule Designer


1. Get the following configuration files.
    * `https://<DC_HOST>/decisioncenter/assets/truststore.jks`
      where *DC_HOST* is the Decision Center endpoint.
    * ./output/OdmOidcProvidersRD.json
      generated previously by the [generateTemplate.sh](generateTemplate.sh) script

2. Copy the `truststore.jks` and `OdmOidcProvidersRD.json` files to your Rule Designer installation directory next to the `eclipse.ini` file.

3. Edit your `eclipse.ini` file and add the following lines at the end.
    ```
    -Djavax.net.ssl.trustStore=<ABSOLUTE_PATH>/truststore.jks
    -Djavax.net.ssl.trustStorePassword=changeme
    -Dcom.ibm.rules.authentication.oidcconfig=<ABSOLUTE_PATH>/OdmOidcProvidersRD.json
    ```
    Where:
    - *changeme* is the fixed password to be used for the default truststore.jks file
    - replace with your <ABSOLUTE_PATH> to access the `eclipse.ini` file.

4. Restart Rule Designer.

For more information, refer to [this documentation](https://www.ibm.com/docs/en/odm/9.5.0?topic=designer-importing-security-certificate-in-rule).

### Getting Started with IBM Operational Decision Manager for Containers

Get hands-on experience with IBM Operational Decision Manager in a container environment by following this [Getting started tutorial](https://github.com/DecisionsDev/odm-for-container-getting-started/blob/master/README.md).

### Calling the ODM Runtime Service

To manage ODM runtime calls, we use the [Loan Validation Decision Service project](https://github.com/DecisionsDev/odm-for-container-getting-started/blob/master/Loan%20Validation%20Service.zip)

Import the **Loan Validation Service** in Decision Center connected as John Doe.

![Import project](images/import_project.png)

Deploy the **Loan Validation Service** production_deployment ruleapps using the **production deployment** deployment configuration in the Deployments>Configurations tab.

![Deploy project](images/deploy_project.png)

You can retrieve the payload.json from the ODM Decision Server Console or use [the provided payload](payload.json).

As explained in the ODM on Certified Kubernetes documentation [Configuring user access with OpenID](https://www.ibm.com/docs/en/odm/9.5.0?topic=access-configuring-user-openid), we advise you to use basic authentication for the ODM runtime call for better performance and to avoid token expiration and revocation.

You perform a basic authentication ODM runtime call in the following way:

   ```
  $ curl -H "Content-Type: application/json" -k --data @payload.json \
         -H "Authorization: Basic b2RtQWRtaW46b2RtQWRtaW4=" \
        https://<DS_RUNTIME_HOST>/DecisionService/rest/production_deployment/1.0/loan_validation_production/1.0
  ```

  Where:
  - `b2RtQWRtaW46b2RtQWRtaW4=` is the base64 encoding of the current username:password odmAdmin:odmAdmin

If you want to perform a bearer authentication ODM runtime call using the Client Credentials flow, you need to get a bearer access token before invoking the execution of the ruleset as follows (You need to set up `jq` beforehand and set the four environment variables):

  ``` 
# /bin/bash

export DS_RUNTIME_HOST=<HOSTNAME eg. k8s-default-odm2302o-ed3c5eee99-301488862.eu-west-3.elb.amazonaws.com>
export COGNITO_SERVER_URL=<URL eg. https://odm.auth.eu-west-3.amazoncognito.com>
export CC_CLIENT_ID=<odmclientcredentials client ID>
export CC_CLIENT_SECRET=<odmclientcredentials client secret>

curl -k -X POST -H "Content-Type: application/x-www-form-urlencoded" \
      -d "client_id=$CC_CLIENT_ID&scope=odmcc/write&client_secret=$CC_CLIENT_SECRET&grant_type=client_credentials" \
      "$COGNITO_SERVER_URL/oauth2/token" > response.json

export ACCESS_TOKEN=$(jq -r .access_token response.json)

curl -k --data @payload.json \
       -H "Content-Type: application/json" \
       -H "Authorization: Bearer ${ACCESS_TOKEN}" \
       https://$DS_RUNTIME_HOST/DecisionService/rest/production_deployment/1.0/loan_validation_production/1.0
  ```

# Troubleshooting

If you encounter any issue, have a look at the [common troubleshooting explanation](/troubleshooting/OpenID/README.md)


# License

[Apache 2.0](/LICENSE)

