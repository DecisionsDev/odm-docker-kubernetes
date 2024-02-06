# Configuration of ODM with Amazon Cognito

<!-- TOC -->

- [Configuration of ODM with Amazon Cognito](#configuration-of-odm-with-amazon-cognito)
- [Introduction](#introduction)
    - [What is Amazon Cognito?](#what-is-amazon-cognito)
    - [About this task](#about-this-task)
    - [ODM OpenID flows](#odm-openid-flows)
    - [Prerequisites](#prerequisites)
- [Create a Cognito User Pool](#create-a-cognito-user-pool)
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

# Create a Cognito User Pool

The first step to integrate ODM with Cognito is to create a [Cognito User Pool](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-identity-pools.html) which will behaves as the OpenID Connect (OIDC) identity provider (IdP), also named OP for OpenId Provider.

![The Cognito User Pool](images/CognitoUserPool.png) (© Amazon)

## Initiate the creation of the Cognito User Pool

To create the Cognito User Pool dedicated to ODM, we followed the [getting started](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pool-as-user-directory.html) by applying the following settings. It doesn't mean that with your production or demo application, you cannot apply different settings. When a setting is compulsory, we will emphasize it with the  

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
        * Enter your application client name, for example **odm**
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

    
# License

[Apache 2.0](/LICENSE)

