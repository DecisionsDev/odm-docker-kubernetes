# Configuration of ODM with Keycloak

<!-- TOC depthfrom:1 depthto:6 withlinks:false updateonsave:false orderedlist:false -->

- [Introduction](#introduction)
    - [What is Keycloak?](#what-is-keycloak)
    - [About this task](#about-this-task)
    - [ODM OpenID flows](#odm-openid-flows)
    - [Prerequisites](#prerequisites)
        - [Install a Keycloak instance](#install-a-keycloak-instance)
- [Configure a Keycloak instance for ODM (Part 1)](#configure-a-keycloak-instance-for-odm-part-1)
    - [Log into the Keycloak Admin Console](#log-into-the-keycloak-admin-console)
    - [Create a dedicated odm realm](#create-a-dedicated-odm-realm)
    - [Manage roles, groups, and users](#manage-roles-groups-and-users)
    - [Set up the client](#set-up-the-client)
- [Deploy ODM on a container configured with Keycloak (Part 2)](#deploy-odm-on-a-container-configured-with-keycloak-part-2)
    - [Prepare your environment for the ODM installation](#prepare-your-environment-for-the-odm-installation)
        - [Create a secret to use the Entitled Registry](#create-a-secret-to-use-the-entitled-registry)
        - [Create secrets to configure ODM with Keycloak](#create-secrets-to-configure-odm-with-keycloak)
    - [Install your ODM Helm release](#install-your-odm-helm-release)
        - [Add the public IBM Helm charts repository](#1-add-the-public-ibm-helm-charts-repository)
        - [Check that you can access the ODM chart](#2-check-that-you-can-access-the-odm-chart)
        - [Run the `helm install` command](#3-run-the-helm-install-command)
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

In the context of the Operational Decision Manager (ODM) on Certified Kubernetes offering, ODM for production can be configured with an external OpenID Connect server (OIDC provider), such as the Keycloak cloud service.

This tutorial shows how to integrate ODM with Keycloak to manage classic authentication and authorization.
Another tutorial explains how to manage [fine grain permission with Decision Center by using a Keycloak SCIM Server](README_FINE_GRAIN_PERMISSION.md).


## What is Keycloak?

[Keycloak](https://www.keycloak.org/) is an open source enterprise identity service that provides single sign-on, user federation, identity brokering and social login. The Keycloak SSO [OpenID Connect](https://www.keycloak.org/docs/latest/server_admin/index.html#con-oidc_server_administration_guide) capability is the service that we use in this article.


## About this task

You need to create a number of secrets before you can install an ODM instance with an external OIDC provider such as the Keycloak service, and use web application single sign-on (SSO). The following diagram shows the ODM services with an external OIDC provider after a successful installation.

![ODM web application SSO](images/diag_keycloak_interaction.jpg)


The following procedure describes how to manually configure ODM with a Keycloak service.

## ODM OpenID flows

[OpenID Connect](https://www.keycloak.org/docs/latest/server_admin/index.html#con-oidc_server_administration_guide) is an authentication standard built on top of OAuth 2.0. It adds a token called an ID token.

Terminology:

- The **OpenID provider** — The authorization server that issues the ID token. In this case, Keycloak is the OpenID provider.
- The **end user** — The end user whose information is contained in the ID token.
- The **relying party** — The client application that requests the ID token from Keycloak.
- The **ID token** — The token that is issued by the OpenID provider and contains information about the end user in the form of claims.
- A **claim** — A piece of information about the end user.

The [Authorization Code flow](https://www.keycloak.org/docs/latest/server_admin/index.html#_oidc-auth-flows-authorization) is best used by server-side apps where the source code is not publicly exposed. The apps must be server-side because the request that exchanges the authorization code for a token requires a client secret, which has to be stored in your client. However, the server-side app requires an end user because it relies on interactions with the end user's web browser, which redirects the user and then receives the authorization code.

![Authentication flow](../Okta/images/Authentication_flow.png) (© Okta)

The [Client Credentials flow](https://www.keycloak.org/docs/latest/server_admin/index.html#_client_credentials_grant) is intended for server-side (AKA "confidential") client applications with no end user, which normally describes machine-to-machine communication. The application must be server-side because it must be trusted with the client secret, and since the credentials are hard-coded, it cannot be used by an actual end user. It involves a single, authenticated request to the token endpoint, which returns an access token.

![Client Credential Flow](../Okta/images/oauth_client_creds_flow.png) (© Okta)

The resource owner password flow allows an application to sign in a user by directly handling their password. It is not recommended to use this flow. In most scenarios, more secure alternatives are available and recommended. This flow requires a very high degree of trust in the application, and carries risks which are not present in other flows. You should only use this flow when other more secure flows cannot be used.

![Password Flow](../Okta/images/password_flow.png) (© Okta)

## Prerequisites

You need the following elements:

- [Helm v3](https://helm.sh/docs/intro/install/)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl)
- Access to an Operational Decision Manager product
- Access to a CNCF Kubernetes cluster
- A Keycloak Instance

### Install a Keycloak instance

This tutorial has been tested with a Keycloak instance version 26.0.5 installed on Openshift. The installation procedure can be found at [Get started with Keycloak on Openshift](https://www.keycloak.org/getting-started/getting-started-openshift).
If you already have an Openshift cluster, you can skip the section [Before you start](https://www.keycloak.org/getting-started/getting-started-openshift#_before_you_start) and use the following steps:

- oc login to your cluster
- Create a namespace "keycloak":
  ```shell
  oc new-project keycloak
  ```
- Continue from the section [Start Keycloak](https://www.keycloak.org/getting-started/getting-started-openshift#_start_keycloak) using the file [keycloak.yaml](keycloak.yaml) instead of the one online as suggested at the first step (which may prevent from accessing the console behind a proxy), ie.:
  ```shell
  oc process -f keycloak.yaml \
      -p KEYCLOAK_ADMIN=admin \
      -p KEYCLOAK_ADMIN_PASSWORD=admin \
      -p NAMESPACE=keycloak \
  | oc create -f -
  ```

If you want to install on another Kubernetes platform, follow these instructions: [Get started with Keycloak on Kubernetes](https://www.keycloak.org/getting-started/getting-started-kube).

# Configure a Keycloak instance for ODM (Part 1)

In this section, we explain how to:

- Log into the Keycloak Admin Console
- Create a dedicated odm realm
- Manage roles, groups, and users
- Set up an application
- Configure the default Authorization server

## Log into the Keycloak Admin Console

Using OpenShift routes, you should be able to access the Keycloak Admin Console through the following URL with the **admin** username and **admin** password:

```shell
KEYCLOAK_URL=https://$(oc get route keycloak --template='{{ .spec.host }}') &&
echo "" &&
echo "Keycloak Admin Console:   $KEYCLOAK_URL/admin" &&
echo ""
```

The following configuration takes place in this Admin Console.

## Create a dedicated odm realm
This step is not compulsory as you can perform the following tasks in the default master realm.
But to avoid getting mixing up with existing configurations, it is preferable to create a dedicated odm realm.

1. Create an odm realm

   On the Main page, click **Master**:
     * Click **Create Realm**
       * Realm Name: *odm*
       * Enabled: On
       * Click **Create**

    ![Create Realm](images/create_realm.png)

## Manage roles, groups, and users

As explained in [Keycloak documentation](https://www.keycloak.org/docs/latest/server_admin/index.html#assigning-permissions-using-roles-and-groups), groups and roles enables to give users access and permissions to use applications. Groups are collections of users to which you apply roles and attributes. Roles define specific application permissions and access control.
To manage permissions inside the ODM application, the ID token and access token contain a property (aka claim) named 'groups' listing all the roles granted to the identified user.
You can create roles and grant these roles directly to an individual user, or even better to a group. This way, all the users of the group are granted the roles of the group.

1. Create a role for ODM administrators.

    In Menu **Manage** / **Realm roles**:
      * Click **Create role**
        * Role name: *rtsAdministrators*
        * Click **Save**

    ![Create Roles](images/create_roles.png)

    Do the same for the other ODM J2EE roles:
      * rtsConfigManagers
      * rtsInstallers
      * rtsUsers
      * resAdministrators
      * resMonitors
      * resDeployers
      * resExecutors

    For more information about ODM groups and roles, refer to the [ODM on Kubernetes documentation](https://www.ibm.com/docs/en/odm/9.5.0?topic=access-user-roles-groups).


2. Create a group for ODM administrators.

    In Menu **Manage** / **Groups**:
      * Click **Create group**
        * Name: *odm-admin*

    ![Create Group](images/create_group.png)

    In Menu **Manage** / **Groups**:
      * Click **odm-admin** to edit the new group
      * Click the **Role mapping** tab
        * Click **Assign role**
          * Select "Filter by realm roles"
          * Select all previously created ODM roles
          * Click **Assign**

    ![Assign Roles](images/assign_roles.png)

3. Create at least one user that belongs to this new group.

    In Menu **Manage** / **Users**:
      * Click **Add user**
        * Email verified: On
        * Username: ``johndoe@mynicecompany.com``
        * Email: ``johndoe@mynicecompany.com``
        * First name: ``John``
        * Last name: ``Doe``
        * Required user actions: nothing
        * Groups : Click **Join Groups** , select ***odm-admin***, and click **Join**
        * Click **Create**

      ![Create User](images/create_user.png)

      * In User Details, select the **Credentials** tab
      * Click **Set password**
        * Fill the Password and Password confirmation  fields with **johndoe**
        * Temporary: Off
        * Click **Save**
      * Click the **Details** tab
      * Click **Save** 
      * Click **Save password** to confirm

    (Optional) Every user is created with a predefined role named **default-roles-<CLIENT_ID>**.
    This role has no interest. So, here is the way to unassign this role.

      * In User Details, select the **Role mapping** tab
        * Select **default-roles-<CLIENT_ID>**
        * Click **Unassign**
        * Click **Remove** to confirm

      ![Unassign default role](images/unassign_default_role.png)

      * Click the **Details** tab
      * Make sure the toggle **Enabled** is On
      * Click **Save**

    Repeat those steps for each user you want to add.

## Set up the client

1. Create the *ODM client*.

    In Menu **Manage** / **Clients**, click **Create client**:
    * Client type: **OpenID Connect**
    * Client ID: **odm**
    * Name: **ODM Application**
    * Always display in UI: On
    * Click **Next**

    ![Create Client 1](images/create_client_1.png)

    * Client Authentication: On
    * Authorization: On
    * Click **Next** or **Save**

    ![Create Client 2](images/create_client_2.png)

    * Newer versions of Keycloak display the additional *Login settings* page below. If you can see it, just click **Save**.
   
    ![Create Client 3](images/create_client_3.png)

    * Click the **Credentials** tab
    * Take a note of the **Client secret** value. It will be referenced as ``CLIENT_SECRET`` in the next steps.

    ![Get Client Secret](images/client_secret.png)

    * Click the **Service accounts roles** tab
    * Click the **Assign role** button. 
    * Select **Filter by realm roles** 
    * Select all res* and rts* roles in the list and click the **Assign** button.

    ![Set Service Account Roles](images/assign_service_account_roles.png)


2. Add the GROUPS predefined mapper on the ROLES client scope

    * Select the **Manage** / **Client scopes** menu
      * Search for the scope : **roles**
      * click the **roles** scope
    * Select the **Mappers** tab
    * Click **Add mapper>From predefined mappers**
      * Search for mapper : **groups**
      * Select **groups**
      * Click **Add**

    ![Add group mapper](images/add_group_mapper_to_role_scope.png)

3. Retrieve the Keycloak Server URL

    In Menu **Configure**/**Realm settings**, in the **General** tab, click the **OpenID Endpoint Configuration** link.
    Take note of the issuer URL.
    It will be referenced as ``KEYCLOAK_SERVER_URL`` in the next steps.

4. Check the configuration

     Download the [keycloak-odm-script.zip](keycloak-odm-script.zip) file to your machine and unzip it in your working directory.
     This .zip file contains scripts and templates to verify and set up ODM.

    4.1 Verify the Client Credentials Token

     You can request an access token using the Client-Credentials flow to verify the format of the token.
     This token is used for the deployment of rulesets from the Business Console:

    ```shell
    ./get-client-credential-token.sh -i $CLIENT_ID -x $CLIENT_SECRET -n $KEYCLOAK_SERVER_URL
    ```

    Where:

    - *CLIENT_ID* is your ODM Application, default is **odm**, can be retrieved in the **Manage** / **Clients** menu
    - *CLIENT_SECRET* is listed in your ODM Application, in the **Credentials** tab
    - *KEYCLOAK_SERVER_URL* is the issuer that can be retrieved using the **OpenID Endpoint Configuration** link of the **General** tab in the **Configure**/**Realm settings** menu

     By introspecting the access_token value with a JWT decoder tool, you should get:

    ```
    {
      ..
      "iss": "<KEYCLOAK_SERVER_URL>",
     ....
      "preferred_username": "service-account-<CLIENT_ID>",
      ...
   }
    ```

    4.2 Verify the Client Password Token


   To check that it has been correctly taken into account, you can request an access token using the Client password flow.
   This token is used for the invocation of the ODM components like the Decision Center, Decision Server console, and the invocation of the Decision Server Runtime REST API.

   ```shell
   ./get-user-password-token.sh -i $CLIENT_ID -x $CLIENT_SECRET -n $KEYCLOAK_SERVER_URL -u johndoe@mynicecompany.com -p johndoe
   ```

   Where:
    - *CLIENT_ID* is your ODM Application, default is odm, can be retrieved in the **Manage** / **Clients** menu
    - *CLIENT_SECRET* is listed in your ODM Application, in the **Credentials** tab
    - *KEYCLOAK_SERVER_URL* is the issuer that can be retrieved using the **OpenID Endpoint Configuration** link of the **General** tab in the **Configure**/**Realm settings** menu
    - The credentials used are from 'Create at least one user that belongs to this new group.' section.

   By introspecting the id_token value with a JWT decoder tool, you should get:

    ```
    {
      ..
      "iss": "<KEYCLOAK_SERVER_URL>",
     ....
      "preferred_username": "<USERNAME>",
      "groups": [
        "rtsAdministrators",
        "rtsInstallers",
        "rtsConfigManagers",
        "rtsUsers",
        "resAdministrators",
        "resDeployers",
        "resMonitors",
        "resExecutors"
      ],
      ...
   }
    ```

# Deploy ODM on a container configured with Keycloak (Part 2)

## Prepare your environment for the ODM installation

### Create a secret to use the Entitled Registry

1. To get your entitlement key, log in to [MyIBM Container Software Library](https://myibm.ibm.com/products-services/containerlibrary) with the IBMid and password that are associated with the entitled software.

    In the **Container software library** tile, verify your entitlement on the **View library** page, and then go to **Get entitlement key**  to retrieve the key.

2. Create a pull secret by running a `kubectl create secret` command.

    ```shell
    kubectl create secret docker-registry ibm-entitlement-key \
        --docker-server=cp.icr.io \
        --docker-username=cp \
        --docker-password="<API_KEY_GENERATED>" \
        --docker-email=<USER_EMAIL>
    ```

    Where:

    - *API_KEY_GENERATED* is the entitlement key from the previous step. Make sure you enclose the key in double-quotes.
    - *USER_EMAIL* is the email address associated with your IBMid.

    > Note: 
    > 1. The **cp.icr.io** value for the docker-server parameter is the only registry domain name that contains the images. You must set the *docker-username* to **cp** to use an entitlement key as *docker-password*.
    > 2. The `ibm-entitlement-key` secret name will be used for the `image.pullSecrets` parameter when you run a Helm install of your containers. The `image.repository` parameter is also set by default to `cp.icr.io/cp/cp4a/odm`.

### Create secrets to configure ODM with Keycloak


1. Create a secret with the Keycloak Server certificate.

    To allow ODM services to access the Keycloak Server, it is mandatory to provide the Keycloak Server certificate.
    You can create the secret as follows:

    ```shell
    keytool -printcert -sslserver <KEYCLOAK_SERVER_URL_WITHOUT_HTTPS> -rfc > keycloak.crt
    kubectl create secret generic keycloak-secret --from-file=tls.crt=keycloak.crt
    ```
    Where:
    - KEYCLOAK_SERVER_URL_WITHOUT_HTTPS is KEYCLOAK_SERVER_URL without the leading `https://`

2. Generate the ODM configuration file for Keycloak.

   If you have not done it yet, download the [keycloak-odm-script.zip](keycloak-odm-script.zip) file to your machine. This .zip file contains the [script](generateTemplate.sh) and the content of the [templates](templates) directory.
   The [script](generateTemplate.sh) allows you to generate the necessary configuration files.
   
   Generate the files with the following command:
    ```shell
    ./generateTemplate.sh -i $CLIENT_ID -x $CLIENT_SECRET -n $KEYCLOAK_SERVER_URL [-r $REALM_NAME -u $USERID_CLAIM]
    ```

   Where:
    - *CLIENT_SECRET* is listed in your ODM Application, section **General** / **Client Credentials**
    - *REALM_NAME* is optional (**odm** by default)
    - *USERID_CLAIM* is optional (**preferred_username** by default). This is the name of the claim (ie. parameter) in the token that holds the name of the user.

    The following files are generated into the `output` directory:

    - `webSecurity.xml` contains the mapping between Liberty J2EE ODM roles and Keycloak groups and users:
      * rtsAdministrators/resAdministrators/resExecutors ODM roles are given to the CLIENT_ID (which is seen as a user) to manage the client-credentials flow
    - `openIdWebSecurity.xml` contains two openIdConnectClient Liberty configurations:
      * the first for web access to Decision Center and Decision Server consoles with the Authorization Code flow
      * the second for the rest-api calls with the client-credentials flow
    - `openIdParameters.properties` configures several features like allowed domains, logout, and some internal ODM openid features
    - `ldap-configurations.xml` contains LDAP configuration for [How to import Keycloak Groups and Users using SCIM](README_FINE_GRAIN_PERMISSION.md)

3. Create the Keycloak authentication secret using `webSecurity.xml`, `openIdWebSecurity.xml` and `openIdParameters.properties` files. 

    ```shell
    kubectl create secret generic keycloak-auth-secret \
        --from-file=openIdParameters.properties=./output/openIdParameters.properties \
        --from-file=openIdWebSecurity.xml=./output/openIdWebSecurity.xml \
        --from-file=webSecurity.xml=./output/webSecurity.xml
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
  ```
  The output should look like:
  ```shell
  NAME                  	CHART VERSION	APP VERSION	DESCRIPTION
  ibm-helm/ibm-odm-prod	     25.0.0       	9.5.0.0   	IBM Operational Decision Manager
  ```

### 3. Run the `helm install` command

You can now install the product. We will use the PostgreSQL internal database and disable data persistence (`internalDatabase.persistence.enabled=false`) to avoid any platform complexity with persistent volume allocation.

> **Note:**  
> The following command installs the **latest available version** of the chart.  
> If you want to install a **specific version**, add the `--version` option:
>
> ```bash
> helm install my-odm-release ibm-helm/ibm-odm-prod --version <version> \
>     --set image.repository=cp.icr.io/cp/cp4a/odm --set image.pullSecrets=ibm-entitlement-key ...
> ```
>
> You can list all available versions using:
>
> ```bash
> helm search repo ibm-helm/ibm-odm-prod -l
> ```

#### a. Installation on OpenShift using Routes

  See the [Preparing to install](https://www.ibm.com/docs/en/odm/9.5.0?topic=production-preparing-install-operational-decision-manager) documentation for more information. Inspect [keycloak-values.yaml](keycloak-values.yaml) for the parameters that have been defined for this installation.

  ```shell
  helm install my-odm-release ibm-helm/ibm-odm-prod -f keycloak-values.yaml
  ```

#### b. Installation using Ingress

  Refer to the following documentation to install an NGINX Ingress Controller on:
  - [Microsoft Azure Kubernetes Service](../../platform/azure/README-NGINX.md)
  - [Amazon Elastic Kubernetes Service](../../platform/eks/README-NGINX.md)
  - [Google Kubernetes Engine](../../platform/gcloud/README_NGINX.md)

  When the NGINX Ingress Controller is ready, you can install the ODM release using [keycloak-nginx-values.yaml](keycloak-nginx-values.yaml). Take note of the `service.ingress.annotations` values that have been defined in this file.

  ```shell
  helm install my-odm-release ibm-helm/ibm-odm-prod -f keycloak-nginx-values.yaml
  ```

## Complete post-deployment tasks

### Register the ODM redirect URL


1. Get the ODM endpoints.
    Refer to [this documentation](https://www.ibm.com/docs/en/odm/9.5.0?topic=tasks-configuring-external-access) to retrieve the endpoints.
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

2. Register the redirect URIs into your Keycloak application.

    The redirect URIs are built in the following way:

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

   From the Keycloak admin console, in **Manage** / **Clients** / **odm**
    - In the tab **Settings**
    	* Add the redirect URIs in the **Valid redirect URIs** field for each components.

      For example, add the Decision Center redirect URI that you got earlier (`https://<DC_HOST>/decisioncenter/openid/redirect/odm` -- do not forget to replace <DC_HOST> with your actual host name!)
    - Click **Save** at the bottom of the page.

    ![Add URI](images/redirect_uris.png)


### Access the ODM services

Well done!  You can now connect to ODM using the endpoints you got [earlier](#register-the-odm-redirect-url) and log in as an ODM admin with the account you created in [the first step](#create-a-dedicated-odm-realm) (e.g. `johndoe@mynicecompany.com` / `johndoe`).

### Set up Rule Designer

First set up Rule Designer following [these instructions](https://www.ibm.com/docs/en/odm/9.5.0?topic=designer-installing-rule-online).

To be able to securely connect your Rule Designer to the Decision Server and Decision Center services that are running in Certified Kubernetes, you need to establish a TLS connection through a security certificate in addition to the OpenID configuration.

1. Get the following configuration files.
    * `https://<DC_HOST>/decisioncenter/assets/truststore.jks`
    * `https://<DC_HOST>/decisioncenter/assets/OdmOidcProvidersRD.json`
      where *DC_HOST* is the Decision Center endpoint.

2. Copy the `truststore.jks` and `OdmOidcProvidersRD.json` files to your Rule Designer installation directory next to the `eclipse.ini` file.

3. Edit your `eclipse.ini` file and add the following lines at the end.
    ```
    -Djavax.net.ssl.trustStore=<ECLIPSEINITDIR>/truststore.jks
    -Djavax.net.ssl.trustStorePassword=changeme
    -Dcom.ibm.rules.authentication.oidcconfig=<ECLIPSEINITDIR>/OdmOidcProvidersRD.json
    ```
    Where:
    - *changeme* is the fixed password to be used for the default truststore.jks file.
    - *ECLIPSEINITDIR* is the Rule Designer installation directory where the eclipse.ini file is.

4. Restart Rule Designer.

For more information, refer to [this documentation](https://www.ibm.com/docs/en/odm/9.5.0?topic=designer-importing-security-certificate-in-rule).

### Getting Started with IBM Operational Decision Manager for Containers

Get hands-on experience with IBM Operational Decision Manager in a container environment by following this [Getting started tutorial](https://github.com/DecisionsDev/odm-for-container-getting-started/blob/master/README.md).

### Calling the ODM Runtime Service

Log in the Business Console as John Doe (`johndoe@mynicecompany.com` / `johndoe`).

Import the Decision Service named [Loan Validation Service](https://github.com/DecisionsDev/odm-for-container-getting-started/blob/master/Loan%20Validation%20Service.zip) if it is not already there.

![Import project](images/import_project.png)

Deploy the **Loan Validation Service** production_deployment ruleapp using the **production deployment** deployment configuration in the Deployments>Configurations tab.

![Deploy project](images/deploy_project.png)

You can retrieve the payload.json from the ODM Decision Server Console or use [the provided payload](payload.json).

As explained in the ODM on Certified Kubernetes documentation [Configuring user access with OpenID](https://www.ibm.com/docs/en/odm/9.5.0?topic=access-configuring-user-openid), we advise you to use basic authentication for the ODM runtime call for better performance and to avoid token expiration and revocation.

You perform a basic authentication ODM runtime call in the following way:

   ```
  curl -H "Content-Type: application/json" -k --data @payload.json \
         -H "Authorization: Basic b2RtQWRtaW46b2RtQWRtaW4=" \
        https://<DS_RUNTIME_HOST>/DecisionService/rest/production_deployment/1.0/loan_validation_production/1.0
  ```

  Where `b2RtQWRtaW46b2RtQWRtaW4=` is the base64 encoding of the current username:password odmAdmin:odmAdmin

If you want to perform a bearer authentication ODM runtime call using the Client Credentials flow, you must get a bearer access token:

  ```
  curl -k -X POST -H "Content-Type: application/x-www-form-urlencoded" \
       -d "client_id=${CLIENT_ID}&scope=openid&client_secret=${CLIENT_SECRET}&grant_type=client_credentials" \
       "${KEYCLOAK_SERVER_URL}/protocol/openid-connect/token"
  ```

 And use the retrieved access token in the following way:

  ```
  curl -H "Content-Type: application/json" -k --data @payload.json \
       -H "Authorization: Bearer <ACCESS_TOKEN>" \
       https://<DS_RUNTIME_HOST>/DecisionService/rest/production_deployment/1.0/loan_validation_production/1.0
  ```

# Troubleshooting

If you encounter any issue, have a look at the [common troubleshooting explanation](../README.md#troubleshooting)

# License

[Apache 2.0](/LICENSE)
