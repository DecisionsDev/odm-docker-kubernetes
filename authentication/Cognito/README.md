# Configuration of ODM with Amazon Cognito

<!-- TOC -->

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
    - [Create A custom claim](#create-a-custom-claim)
- [Deploy ODM on a container configured with Cognito Part 2](#deploy-odm-on-a-container-configured-with-cognito-part-2)
    - [Create a secret to use the Entitled Registry](#create-a-secret-to-use-the-entitled-registry)
    - [Create secrets to configure ODM with Cognito](#create-secrets-to-configure-odm-with-cognito)
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

1. Configure sign-in experience

    In **Authentication providers**:
      * **Provider types**:
        * Select **Cognito user pool**
      * **Cognito user pool sign-in options**: 
        * Select **Email**

2. Configure security requirements

    In **Password policy**:
      * **Password policy mode**:
        * Select **Cognito defaults**

    In **Multi-factor authentication**:
      * **MFA enforcement**:
          * Select **Require MFA-Recommended**
      * **MFA methods**:
          * Select **Authenticator apps**

    In **User account recovery**:
      * **Self-service account recovery**
          * Select **Enable self-service account recovery - Recommended**

3. Configure sign-up experience

    In **Self-service sign-up**:
      * **Self-registration**:
        * Select **Enable self-registration**
        
    In **Attribute verification and user account confirmation**:
      * **Cognito-assisted verification and confirmation**:
        * Select *Allow cognito to automatically send messages to verify and confirm - Recommended*
      * **Attributes to verify**:
          * Select *Send SMS message, verify phone number*
      * **Verifying attribute changes**:
        * Select *Keep original attribute value active when an update is pending - Recommended*
      * **Active attribute values when an update is pending**:
          * Select *Phone number*

4. Configure message delivery

    In **Email**:
      * **Email provider**:
        * Select *Send email with Cognito*
      * **SES Region**:
        * Select your region
      * **FROM email address**:
        * Keep default **no-reply@verificationemail.com**

    In **SMS**:
      * **IAM role**:
        * Select *Create a new IAM role*
      * **IAM role name**:
        * Enter **odmsmsrole**
      * **SNS Region**:
        * Select your region

    We are not using SMS in this tutorial. So, there is no need to  "Configure AWS service dependencies to complete your SMS message setup" section.

5. Integrate your app

    In **User pool name**:
      * **User pool name**:
        * Enter **odmuserpool**

    In **Hosted authentication pages**:
      * Select **Use the Cognito Hosted UI**

    In **Domain**:
      * **Domain type**:
        * Select **Use a Cognito Domain**
      * **Cognito domain**:
        * Enter your cognito domain name, for example **https://odm**

    In **Initial app client**:
      * **App type**:
        * Select **Confidential client**
      * **App client name**:
        * Enter **odm**
      * **Client secret**:
        * Select **Generate a client secret**
      * **Allowed callbacks URLs**:
        * We will fill this section later when the ODM on k8s helm application will be instanciated as currently we don't know these URLs. As at least one is requested, you can put **https://dummyUrl** for example

    In **Advanced app client settings**, let all the default values as it is.

    In **Attribute read and write permissions**, let all the default values as it is. 

6. Review and create

   If you are satisfied with all the values, then click on **Create user pool**

## Create A User

* Select the **odmuserpool** User Pool:
  * Select the **Users** tab:
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
  * Select the **Groups** tab:
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

With Cognito, it's not possible to create an application client that is managing both the Authorization code grant flow and the Client-Credentials flow.
So, we will create a dedicated client application for the client-credentials flow inside the same Cognito User Pool.
The client-credentials flow will be used for M2M (Machine to Machine) communication. 
It will enable communication between Decision Center and the Decision Server Console for ruleapp deployment. 
It will also enable the communication between Decision Center and Decision Runner for tests and simulation.

Usage of client-credentials flow needs custom scopes that will be hosted by a Resource Server. A scope is a level of access that an app can request to a resource.
To get more details about scope and resource server, you can read [OAuth 2.0 scopes and API authorization with resource servers](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-define-resource-servers.html?icmpid=docs_cognito_console_help_panel)


1. Create an **ODMClientCredentialsServer** Resource Server

Select the **odmuserpool** User Pool:
  * Select the **App Integration** tab:
    * On **Resource servers** section:
      * Click on **create resource server** button

    In **Resource server**:
      * **Resource server name**:
        * Enter the **ODMClientCredentialsServer** name
      * **Resource server identifier**:
        * Enter **odmcc**

    In **Custom scopes**:
      * Click the **Add custom scopes** button

    Create the 2 following scopes:
      * Enter the **Scope name** : read
        with **Description**: for GET requests
        Click the **Add another** button
      * Enter the **Scope name** : write
        with **Description**: for POST requests

    Click the **create resource server** button 

![Create Resource Server](images/CreateResourceServer.png)

2. Create an **odmclientcredentials** client application

Select the **odmuserpool** User Pool:
  * Select the **App Integration** tab:
    * On **App clients and analytics**:
      * Click on the **Create app client** button

    In **App client**:
      * App type:
        * Select **Confidential client**

      * For **App client name**:
        * Enter **odmclientcredentials**

    In **Hosted UI settings**:
      * For **URL**
        * Enter a dummy URL: https://localhost
      * For **OAuth 2.0 grant types**:
        * Select **Client credentials**
      * For **Custom scopes**:
        * Select : odmcc/read and odmcc/write

    Click on **Create app client** button 

![Client-Credentials App](images/ClientCredentialsApp.png)
    
## Create a custom claim

To be able to correctly manage the authorization from the ODM client application hosted on liberty by using an id_token for using the authorization flow and with an access_token for the client-credentials flow, we need a common claim inside the id_token and the access_token. We could use the **sub** claim. But, if we use **sub**, it will display inside ODM UI a unique identifier as a UUID which is not convenient as we prefer a name or an email. We would like to manage it the same way we do it with Azure AD creating an [**identity** custom claim](https://github.com/DecisionsDev/odm-docker-kubernetes/blob/master/authentication/AzureAD/README_WITH_CLIENT_SECRET.md#set-up-an-microsoft-entra-id-application-using-a-client-secret). Unfortunately, even if Cognito recently added a support for [custom claim in access token](https://aws.amazon.com/about-aws/whats-new/2023/12/amazon-cognito-user-pools-customize-access-tokens/), it is still [not supported for access_token dealing with the client-credentials flow](https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-lambda-pre-token-generation.html).
So, the following way to manage this is a workaround until this feature is available.

As we cannot add a custom claim inside the client-credentials access_token, we will add a claim inside the id_token that is already present inside the access_token.       
There is a **client_id** claim inside the access_token, that is not present by default inside the id_token.
We will use the [pre token generation lambda trigger](https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-lambda-pre-token-generation.html) to add the **client_id** claim inside the id_token that will take the **email** value.

1. Add a Pre token generation Lambda trigger

We will use the pre token generation lambda trigger feature to the **client_id** claim in in id_token by pushing the user email value.

Select the **odmuserpool** User Pool:
  * Select the **User pool properties** tab:
    * On the **Lambda triggers** section:
      * Click the **Add Lambda trigger** button

In **Lambda triggers**:
  * Select **Authentication**
    In **Authentication**:
      * Select **Pre token generation trigger** (Modify claims in ID and access tokens.)
    In **Trigger event version**
      * Select **Basic features** (due to the previously explained Cognito limitation about client-credentials access-token customization)

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
const handler = async (event) => {
  // Allow to get debug information in the Amazon CloudWatch Logs.
  console.debug(event.request.userAttributes);
  // Get User email value
  var user_email = event.request.userAttributes.email;
  console.debug(user_email);
  event.response = {
    claimsOverrideDetails: {
      claimsToAddOrOverride: {
        // Add a client_id claim with email value
        client_id: user_email,
      },
    },
  };

  return event;
};

export { handler };
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

    keytool -printcert -sslserver <COGNITO_DOMAIN_NAME>.auth.<COGNITO_REGION>.amazoncognito.com -rfc > cognito-auth.crt
    kubectl create secret generic cognito-domain-cert-secret --from-file=tls.crt=cognito-auth.crt
    ```
    Where:
    - *COGNITO_REGION* is the region where the COGNITO User Pool is deployed
    - *COGNITO_DOMAIN_NAME* is the prefix name of the COGNITO User Pool Domain that you can retrieve at Amazon Cognito > User pools > odmuserpool > App integration > Domain (odm in our tutorial)
  
3. Generate the ODM configuration file for Cognito

    If everything is well configured, the Cognito End-Points must be accessible at :
    https://cognito-idp.COGNITO_REGION.amazonaws.com/COGNITO_USER_POOL_ID/.well-known/openid-configuration  

    Where:
    - *COGNITO_REGION* is the region where the COGNITO User Pool is deployed
    - *COGNITO_USER_POOL_ID* is the COGNITO User Pool ID retrieved at Amazon Cognito > User pools > odmuserpool > User pool overview > User pool ID
    

    The script [generateTemplate.sh](generateTemplate.sh) allows you to generate the necessary configuration files.
    
    This script is available in the present project and requires some companion files in the project as well. So please clone/download the project at this point if you have not done this already.

    Generate the files with the following command:
    ```
    ./generateTemplate.sh -u COGNITO_USER_POOL_ID -d COGNITO_DOMAIN_NAME -r COGNITO_REGION -i COGNITO_APP_CLIENT_ID -s COGNITO_APP_CLIENT_SECRET -c COGNITO_CC_CLIENT_ID -x COGNITO_CC_CLIENT_SECRET
    ```

    Where:
    - *COGNITO_USER_POOL_ID* is the COGNITO User Pool ID retrieved at Amazon Cognito > User pools > odmuserpool > User pool overview > User pool ID
    - *COGNITO_DOMAIN_NAME* is the prefix name of the COGNITO User Pool Domain retrieved at Amazon Cognito > User pools > odmuserpool > App integration > Domain
    > [!WARNING]
    > only copy the prefix (odm in our tutorial) and not the entire value
    - *COGNITO_REGION* is the region where the COGNITO User Pool is deployed
    - *COGNITO_APP_CLIENT_ID* is the COGNITO ODM App Client ID retrieved at Amazon Cognito > User pools > odmuserpool > App integration > App clients and analytics > odm > Client ID
    - *COGNITO_APP_CLIENT_SECRET* is the COGNITO ODM App Client Secret retrieved at Amazon Cognito > User pools > odmuserpool > App integration > App clients and analytics > odm > Client Secret
    - *COGNITO_CC_CLIENT_ID* is the COGNITO ODM Client-Credentials App Client ID retrieved at Amazon Cognito > User pools > odmuserpool > App integration > App clients and analytics > odmclientcredentials > Client ID
    - *COGNITO_CC_CLIENT_SECRET* is the COGNITO ODM Client-Credentials App Client Secret retrieved at Amazon Cognito > User pools > odmuserpool > App integration > App clients and analytics > odmclientcredentials > Client Secret

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

    The four files below are generated into the [output](output) directory:

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
  ibm-helm/ibm-odm-prod         23.2.0          8.12.0.1        IBM Operational Decision Manager
  ```

### 3. Run the `helm install` command


#### a. Installation on OpenShift using Routes

  See the [Preparing to install](https://www.ibm.com/docs/en/odm/8.12.0?topic=production-preparing-install-operational-decision-manager) documentation for more information.

  ```shell
  helm install my-odm-release ibm-helm/ibm-odm-prod \
          --set image.repository=cp.icr.io/cp/cp4a/odm --set image.pullSecrets=icregistry-secret \
          --set oidc.enabled=true \
          --set license=true \
          --set internalDatabase.persistence.enabled=false \
          --set customization.trustedCertificateList='{cognito-idp-cert-secret,cognito-domain-cert-secret}' \
          --set customization.authSecretRef=cognito-auth-secret \
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
          --set customization.trustedCertificateList='{cognito-idp-cert-secret,cognito-domain-cert-secret}' \
          --set customization.authSecretRef=cognito-auth-secret \
          --set service.ingress.enabled=true \
          --set service.ingress.annotations={"kubernetes.io/ingress.class: nginx"\,"nginx.ingress.kubernetes.io/backend-protocol: HTTPS"\,"nginx.ingress.kubernetes.io/affinity: cookie"}
  ```

## Complete post-deployment tasks

### Register the ODM redirect URL


1. Get the ODM endpoints.
    Refer to [this documentation](https://www.ibm.com/docs/en/odm/8.12.0?topic=tasks-configuring-external-access) to retrieve the endpoints.
    For example, on OpenShift you can get the route names and hosts with:

    ```

    You get the following hosts:
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

   From the Cognito admin console, in **ODM User Pool** / **App integration** / **App clients and analytics** / **odm**
    - In **Hosted UI**, click the **Edit** button
        * Add the redirect URIs in the **Allowed callback URLs** field for all components.

      For example, add the Decision Center redirect URI that you got earlier (`https://<DC_HOST>/decisioncenter/openid/redirect/odm` 
> [!WARNING]
> Please replace <DC_HOST> with your actual host name!)

    - Click **Save changes** at the bottom of the page.


### Access the ODM services


### Set up Rule Designer


1. Get the following configuration files.
    * `https://<DC_HOST>/decisioncenter/assets/truststore.jks`
    * `https://<DC_HOST>/odm/decisioncenter/assets/OdmOidcProvidersRD.json`
      where *DC_HOST* is the Decision Center endpoint.

2. Copy the `truststore.jks` and `OdmOidcProvidersRD.json` files to your Rule Designer installation directory next to the `eclipse.ini` file.

3. Edit your `eclipse.ini` file and add the following lines at the end.
    ```
    -Djavax.net.ssl.trustStore=truststore.jks
    -Djavax.net.ssl.trustStorePassword=changeme
    -Dcom.ibm.rules.authentication.oidcconfig=OdmOidcProvidersRD.json
    ```
    Where:
    - *changeme* is the fixed password to be used for the default truststore.jks file.

4. Restart Rule Designer.

For more information, refer to [this documentation](https://www.ibm.com/docs/en/odm/8.12.0?topic=designer-importing-security-certificate-in-rule).

### Getting Started with IBM Operational Decision Manager for Containers

Get hands-on experience with IBM Operational Decision Manager in a container environment by following this [Getting started tutorial](https://github.com/DecisionsDev/odm-for-container-getting-started/blob/master/README.md).

### Calling the ODM Runtime Service

To manage ODM runtime calls, we use the [Loan Validation Decision Service project](https://github.com/DecisionsDev/odm-for-container-getting-started/blob/master/Loan%20Validation%20Service.zip)

Import the **Loan Validation Service** in Decision Center connected as John Doe.

![Import project](images/import_project.png)

Deploy the **Loan Validation Service** production_deployment ruleapps using the **production deployment** deployment configuration in the Deployments>Configurations tab.

![Deploy project](images/deploy_project.png)

You can retrieve the payload.json from the ODM Decision Server Console or use [the provided payload](payload.json).

As explained in the ODM on Certified Kubernetes documentation [Configuring user access with OpenID](https://www.ibm.com/docs/en/odm/8.12.0?topic=access-configuring-user-openid), we advise you to use basic authentication for the ODM runtime call for better performance and to avoid token expiration and revocation.

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

If you encounter any issue, have a look at the [common troubleshooting explanation](../README.md#Troubleshooting)


# License

[Apache 2.0](/LICENSE)

