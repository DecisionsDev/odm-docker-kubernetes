# Configuration of ODM with Microsoft Entra ID

<!-- TOC -->

- [Configuration of ODM with Microsoft Entra ID](#configuration-of-odm-with-microsoft-entra-id)
- [Introduction](#introduction)
    - [What is Microsoft Entra ID?](#what-is-microsoft-entra-id)
    - [About this task](#about-this-task)
    - [ODM OpenID flows](#odm-openid-flows)
    - [Prerequisites](#prerequisites)
        - [Create a Microsoft Entra ID account](#create-a-microsoft-entra-id-account)
- [Configure a Microsoft Entra ID instance for ODM Part 1](#configure-a-microsoft-entra-id-instance-for-odm-part-1)
    - [Log into the Microsoft Entra ID instance](#log-into-the-microsoft-entra-id-instance)
    - [Manage groups and users](#manage-groups-and-users)
    - [Choose the way to set up your application](#choose-the-way-to-set-up-your-application)
- [License](#license)

<!-- /TOC -->

# Introduction

In the context of the Operational Decision Manager (ODM) on Certified Kubernetes offering, ODM for production can be configured with an external OpenID Connect server (OIDC provider), such as the Microsoft Entra ID cloud service.

## What is Microsoft Entra ID?

Microsoft Entra ID is the [new name for Azure AD](https://learn.microsoft.com/en-us/azure/active-directory/fundamentals/new-name).

[Microsoft Entra ID](https://www.microsoft.com/en-us/security/business/identity-access/microsoft-entra-id#overview),  is an enterprise identity service that provides single sign-on, multifactor authentication, and conditional access. This is the service that we use in this article.


## About this task

You need to create a number of secrets before you can install an ODM instance with an external OIDC provider such as the Microsoft Entra ID service, and use web application single sign-on (SSO). The following diagram shows the ODM services with an external OIDC provider after a successful installation.

![ODM web application SSO](/images/AzureAD/diag_azuread_interaction.jpg)

The following procedure describes how to manually configure ODM with an Microsoft Entra ID service.

## ODM OpenID flows

OpenID Connect is an authentication standard built on top of OAuth 2.0. It adds a token called an ID token.

Terminology:

- **OpenID provider** — The authorization server that issues the ID token. In this case, Microsoft Entra ID is the OpenID provider.
- **end user** — The end user whose details are contained in the ID token.
- **relying party** — The client application that requests the ID token from Microsoft Entra ID.
- **ID token** — The token that is issued by the OpenID provider and contains information about the end user in the form of claims.
- **claim** — A piece of information about the end user.

The Authorization Code flow is best used by server-side apps in which the source code is not publicly exposed. The apps must be server-side because the request that exchanges the authorization code for a token requires a client secret, which has to be stored in your client. However, the server-side app requires an end user because it relies on interactions with the end user's web browser which redirects the user and then receives the authorization code.

![Authentication flow](/images/AzureAD/AuthenticationFlow.png) (© Microsoft)

The Client Credentials flow is intended for server-side (AKA "confidential") client applications with no end user, which normally describes machine-to-machine communication. The application must be server-side because it must be trusted with the client secret, and since the credentials are hard-coded, it cannot be used by an actual end user. It involves a single, authenticated request to the token endpoint which returns an access token.

![Microsoft Entra ID Client Credential Flow](/images/AzureAD/ClientCredential.png) (© Microsoft)

The Microsoft identity platform supports the OAuth 2.0 Resource Owner Password Credentials (ROPC) grant, which allows an application to sign in the user by directly handling their password. Microsoft recommends you do not use the ROPC flow. In most scenarios, more secure alternatives are available and recommended. This flow requires a very high degree of trust in the application, and carries risks which are not present in other flows. You should only use this flow when other more secure flows cannot be used.

![Microsoft Entra ID Password Flow](/images/AzureAD/PasswordFlow.png) (© Microsoft)

## Prerequisites

You need the following elements:

- [Helm v3](https://helm.sh/docs/intro/install/)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl)
- Access to an Operational Decision Manager product
- Access to a CNCF Kubernetes cluster
- An admin Azure AD account

### Create an Microsoft Entra ID account

If you do not own an Microsoft Entra ID account, you can sign up for a [free Microsoft Entra ID developer account](https://www.microsoft.com/en-us/security/business/identity-access/microsoft-entra-id)

# Configure a Microsoft Entra ID instance for ODM (Part 1)

In this section, we explain how to:

- Manage groups and users
- Set up an application
- Configure the default Authorization server

## Log into the Microsoft Entra ID instance

After activating your account by email, you should have access to your Microsoft Entra ID instance. [Sign in to Azure](https://portal.azure.com/#home).

## Manage groups and users

1. Create a group for ODM administrators.

    In **Azure Active Directory** / **Groups**:
      * Click **New Group**
        * Group type: Security
        * Group name: *odm-admin*
        * Group description: *ODM Admin group*
        * Membership type: Assigned
        * Click **Create**

    ![Add Group](/images/AzureAD/NewGroup.png)

    In **Azure Active Directory** / **Groups** take note of the Object ID. It will be referenced as ``GROUP_ID`` later in this tutorial.

    ![GroupID](/images/AzureAD/GroupID.png)

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

      ![New User Basics](/images/AzureAD/NewUserBasics.png)
      ![New User Assignments](/images/AzureAD/NewUserAssignments.png)

      * Click the **myodmuser** user previously created
        * Edit properties
        * Fill the email field with *myodmuser*@YOURDOMAIN

      * Try to log in to the [Azure portal](https://portal.azure.com/) with the user principal name.
       This may require to enable 2FA and/or change the password for the first time.

    Repeat this step for each user that you want to add.

## Choose the way to set up your application

With Microsoft Entra ID, there is several way to set up an openId application : 
    
- the classic way is using a [client secret](README_WITH_CLIENT_SECRET.md)
- a new and more secure way since [liberty 23.0.0.9](https://openliberty.io/blog/2023/09/19/23.0.0.9.html#jwt) is using [private key JWT](README_WITH_PRIVATE_KEY_JWT.md)

If you don't know why to choose one way or the other, take the time to read [this article explaining the comparison](https://www.ubisecure.com/access-management/private_key_jwt-or-client_secret) 
Anyway the conclusion is if you have the choice, private_key_jwt is the way to go !

# License

[Apache 2.0](/LICENSE)
  
