# Configuration of ODM with PingFederate

<!-- TOC depthfrom:1 depthto:6 withlinks:false updateonsave:false orderedlist:false -->

- [Introduction](#introduction)
    - [What is PingFederate?](#what-is-pingfederate)
    - [About this task](#about-this-task)
    - [ODM OpenID flows](#odm-openid-flows)
    - [Prerequisites](#prerequisites)
        - [Install a PingFederate instance](#install-a-pingfederate-instance)
- [Configure a PingFederate instance for ODM (Part 1)](#configure-a-pingfederate-instance-for-odm-part-1)
    - [Log into the PingFederate Admin Console](#log-into-the-pingfederate-admin-console)
    - [Create some users and groups](#create-some-users-and-groups)
    - [Create an ODM Resource and dedicated scope](#create-an-odm-resource-and-dedicated-scope)
    - [Create an ODM Application](#create-an-odm-application)
    - [Check the configuration](#check-the-configuration)
- [Deploy ODM on a container configured with PingFederate (Part 2)](#deploy-odm-on-a-container-configured-with-pingfederate-part-2)
    - [Prepare your environment for the ODM installation](#prepare-your-environment-for-the-odm-installation)
        - [Create a secret to use the Entitled Registry](#create-a-secret-to-use-the-entitled-registry)
        - [Create secrets to configure ODM with PingFederate](#create-secrets-to-configure-odm-with-pingfederate)
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

In the context of the Operational Decision Manager (ODM) on Certified Kubernetes offering, ODM for production can be configured with an external OpenID Connect server (OIDC provider), such as the PingFederate cloud service.

This tutorial shows how to integrate ODM with PingFederate to manage classic authentication and authorization.

## What is PingFederate?

[PingFederate](https://www.pingidentity.com/en/product/pingfederate.html) is an enterprise identity and access management (IAM) software product made by [Ping Identity](https://www.pingidentity.com/en.html). It is mainly used for federated authentication and single sign-on (SSO) across different systems and organizations.

## About this task

You need to create a number of secrets before you can install an ODM instance with an external OIDC provider such as the PingFederate service, and use web application single sign-on (SSO). The following diagram shows the ODM services with an external OIDC provider after a successful installation.

![ODM web application SSO](images/diag_pingfederate_interaction.jpg)


The following procedure describes how to manually configure ODM with a PingFederate service.

## ODM OpenID flows

[OpenID Connect](https://www.PingFederate.org/docs/latest/server_admin/index.html#con-oidc_server_administration_guide) is an authentication standard built on top of OAuth 2.0. It adds a token called an ID token.

Terminology:

- The **OpenID provider** — The authorization server that issues the ID token. In this case, PingFederate is the OpenID provider.
- The **end user** — The end user whose information is contained in the ID token.
- The **relying party** — The client application that requests the ID token from PingFederate.
- The **ID token** — The token that is issued by the OpenID provider and contains information about the end user in the form of claims.
- A **claim** — A piece of information about the end user.

The [Authorization Code flow](https://docs.pingidentity.com/pingfederate/13.0/introduction_to_pingfederate/pf_grant_types.html#primary-grant-types) is best used by server-side apps where the source code is not publicly exposed. The apps must be server-side because the request that exchanges the authorization code for a token requires a client secret, which has to be stored in your client. However, the server-side app requires an end user because it relies on interactions with the end user's web browser, which redirects the user and then receives the authorization code.

![Authorization Code Flow](images/authorization_code_flow.svg)

The [Client Credentials flow](https://docs.pingidentity.com/pingfederate/13.0/introduction_to_pingfederate/pf_grant_types.html#primary-grant-types) is intended for server-side (AKA "confidential") client applications with no end user, which normally describes machine-to-machine communication. The application must be server-side because it must be trusted with the client secret, and since the credentials are hard-coded, it cannot be used by an actual end user. It involves a single, authenticated request to the token endpoint, which returns an access token.

![Client Credentials Flow](images/client_credentials_flow.svg)

## Prerequisites

You need the following elements:

- [Helm v3](https://helm.sh/docs/intro/install/)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl)
- Access to an Operational Decision Manager product
- Access to a CNCF Kubernetes cluster
- A PingFederate Saas trial Instance

### Install a PingFederate instance

This tutorial has been tested with a [PingFederate Saas trial instance](https://www.pingidentity.com/en/try-ping.html). You have to request it if you don't have one.


# Configure a PingFederate instance for ODM (Part 1)

In this section, you will:

- Log into the PingFederate Admin Console
- Create some users and groups
- Create an ODM Resource and dedicated scope
- Create an ODM Application
- Check the configuration

## Log into the PingFederate Admin Console

When the trial is available, you have a link to the PingFederate Admin Console in the email you received. Use it to connect to the PingFederate Admin Console.

## Create some users and groups 

At the first connection, a predefined user that was used to log into the PingFederate Admin Console is already present in the Directory > Users tab.
You can use the + button to add new users.

We will use the Directory>Groups tab to create a group named `ODM-Admin` and add the prefdefined user to it.

Select Directory > Groups and click the + button to create a new group.
  * Group Name: *ODM-Admin*
  * Description: *ODM Admin Group*
  * Click **Save**

Using the three dot button on the ODM-Admin group, you can add the predefined user to the group using the **Add/remove Users** menu.

![Admin Group](images/admin_group.png)


## Create an ODM Resource and dedicated scope

The resource is a way to create a dedicated scope that will be used in the client_credentials flow, as openid scope acconot be used.

Select **Applications** > **Resources** tab and click the + button to create a new resource.
  * Resource Name: *ODM CC*
  * Description: *ODM Resource for Client Crededentials*
  * Click **Next**

  * Click **+ Add** Attributes button
  * Attribute Name: *identity* and **PingOne Mappings Value** *#root.context.appConfig.clientId* using the **Advanced Expression** button
  * Check *Required* checkbox
  * Click **Next**

![Resource Attributes](images/resource_attributes.png)

  * Click **+ Add** Scope button
  * Scope Name: *odm_cc*
  * Click **Save**

![Resource Scope](images/resource_scope.png)

## Create an ODM Application

Select Applications > Applications tab and click the + button to create a new application.
  * Application Name: *ODM Application*
  * Application Type: *OIDC Web App*
  * Click **Save**

Select **Configuration** and edit using the **Edit** button.
  * Response Type: *Code,Token and ID Token*
  * Grant Type: *Authorization Code, Implicit, Client Credentials*
  * Token Endpoint Authentication Method: *Client Secret Post*
  * Click **Save**

![Application Configuration](images/application_configuration.png)

Select **Resources** and edit using the **Edit** button.
  * Add the *odm_cc* scope to the **Selected Scopes** list
  * Click **Save**

![Application Resources](images/application_resources.png)

[Optional] Set MFA to login to ODM UI
Select **Policies** and edit using the **Edit** button.
  * Check **Multi_factor** policy
  * Click **Save**

![Application Policies](images/application_policies.png)

Select **Attribute Mappings** and edit using the **Edit** button.
Add new attribute using the **+Add** button
  * Attribute Name: *groups* and **PingOne Mappings Value** *ODM-Admin*
  * Attribute Name: *identity* and **PingOne Mappings Value** *user.name.given + ' ' + user.name.family* using the **Advanced Expression** button
  * Click **Save**

![Application Attributes](images/application_attributes.png)

Select **Access** and edit using the **Edit** button.
  * Select **ODM-Admin** group from the **Groups** dropdown
  * Click **Save**

![Application Access](images/application_access.png)

## Check the configuration

  Download the [pingfederate-odm-script.zip](pingfederate-odm-script.zip) file to your machine and unzip it in your working directory.
  This .zip file contains scripts and templates to verify and set up ODM.

  You can request an access token using the Client-Credentials flow to verify the format of the token.
  This token is used for the deployment of rulesets from the Business Console:

  ```shell
  ./get-client-credential-token.sh -i $CLIENT_ID -x $CLIENT_SECRET -n $PING_FEDERATE_SERVER_URL
  ```

  Where:
  - *CLIENT_ID* is your ODM Application (`odm` if you followed the instructions). You can find it in the **Manage** / **Clients** menu.
  - *CLIENT_SECRET* is the secret for your ODM Application. You can find it in the **Credentials** tab.
  - *PING_FEDERATE_SERVER_URL* is the issuer ID that can be retrieved in the Connection Details of the Overview tab of the **ODM Application** 

  If you decode the *access_token* value with a JWT decoder tool, you should get:
  ```json
  {
    ..
    "iss": "<PING_FEDERATE_SERVER_URL>",
  ....
    "identity": "<CLIENT_ID>",
    ...
  }
  ```


# Deploy ODM on a container configured with PingFederate (Part 2)

## Prepare your environment for the ODM installation

### Create a secret to use the Entitled Registry

1. To get your entitlement key, log in to [MyIBM Container Software Library](https://myibm.ibm.com/products-services/containerlibrary) with the IBMid and password that are associated with the entitled software.

    In the **Container software library** tile, verify your entitlement on the **View library** page, and then go to **Get entitlement key**  to retrieve the key.

2. Create a pull secret by running a `kubectl create secret` command.

    ```shell
    kubectl create secret docker-registry ibm-entitlement-key \
        --docker-server=cp.icr.io \
        --docker-username=cp \
        --docker-password="<API_KEY_GENERATED>"
    ```

    Where:

    - *API_KEY_GENERATED* is the entitlement key from the previous step. Make sure you enclose the key in double-quotes.

    > Note: 
    > 1. The **cp.icr.io** value for the docker-server parameter is the only registry domain name that contains the images. You MUST set the *docker-username* to **cp** to use an entitlement key as *docker-password*.
    > 2. The `ibm-entitlement-key` secret name will be used for the `image.pullSecrets` parameter when you run a Helm install of your containers. The `image.repository` parameter is also set by default to `cp.icr.io/cp/cp4a/odm`.

### Create secrets to configure ODM with PingFederate

1. Create a secret to configure ODM with PingFederate.

   If you have not done it yet, download the [pingfederate-odm-script.zip](pingfederate-odm-script.zip) file to your machine. This .zip file contains the [script](generateTemplate.sh) and the content of the [templates](templates) directory.
   The [script](generateTemplate.sh) allows you to generate the necessary configuration files.
   
   Generate the files with the following command:
    ```shell
    ./generateTemplate.sh -i $CLIENT_ID -x $CLIENT_SECRET -n $PING_FEDERATE_SERVER_URL
    ```

   Where:
    - *CLIENT_ID* can be found in the **overview** of the ODM Application, section **Applications** / **Applications**    
    - *CLIENT_SECRET* can be found in the **overview** of the ODM Application, section **Applications** / **Applications**
    - *PING_FEDERATE_SERVER_URL* can be found as the Issuer ID in the **overview** / **Connection Details** of the ODM Application, section **Applications** / **Applications**

   The following files are generated into the `output` directory:

    - `webSecurity.xml` contains the mapping between Liberty J2EE ODM roles and the PingFederate ODM-Admin group
    - `openIdWebSecurity.xml` contains two openIdConnectClient Liberty configurations:
      * the first for web access to Decision Center and Decision Server consoles with the Authorization Code flow
      * the second for the rest-api calls with the client-credentials flow
    - `openIdParameters.properties` configures several features like allowed domains, logout, and some internal ODM openid features

3. Create the PingFederate authentication secret using `webSecurity.xml`, `openIdWebSecurity.xml` and `openIdParameters.properties` files. 

    ```shell
    kubectl create secret generic pingfederate-auth-secret \
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
  NAME                      CHART VERSION  APP VERSION  DESCRIPTION
  ibm-helm/ibm-odm-prod     26.0.0         9.6.0.0      IBM Operational Decision Manager
  ```

### 3. Run the `helm install` command

You can now install the product. We will use the PostgreSQL internal database and disable data persistence (`internalDatabase.persistence.enabled=false`) to avoid any platform complexity with persistent volume allocation.

> **Note:**  
> The following command installs the **latest available version** of the chart.  
> If you want to install a **specific version**, add the `--version` option:
>
> ```bash
> helm install my-odm-release ibm-helm/ibm-odm-prod --version <version> -f pingfederate-values.yaml
> ```
>
> You can list all available versions using:
>
> ```bash
> helm search repo ibm-helm/ibm-odm-prod -l
> ```

#### a. Installation on OpenShift using Routes

  See the [Preparing to install](https://www.ibm.com/docs/en/odm/9.6.0?topic=production-preparing-install-operational-decision-manager) documentation for more information. Inspect [pingfederate-values.yaml](pingfederate-values.yaml) for the parameters that have been defined for this installation.

  ```shell
  helm install my-odm-release ibm-helm/ibm-odm-prod -f pingfederate-values.yaml
  ```

#### b. Installation using Ingress

  Refer to the following documentation to install an NGINX Ingress Controller on:
  - [Microsoft Azure Kubernetes Service](../../platform/azure/README-NGINX.md)
  - [Amazon Elastic Kubernetes Service](../../platform/eks/README-NGINX.md)
  - [Google Kubernetes Engine](../../platform/gcloud/README_NGINX.md)

  When the NGINX Ingress Controller is ready, you can install the ODM release using [pingfederate-nginx-values.yaml](pingfederate-nginx-values.yaml). Take note of the `service.ingress.annotations` values that have been defined in this file.

  ```shell
  helm install my-odm-release ibm-helm/ibm-odm-prod -f pingfederate-nginx-values.yaml
  ```

## Complete post-deployment tasks

### Register the ODM redirect URL


1. Get the ODM endpoints.
    Refer to [this documentation](https://www.ibm.com/docs/en/odm/9.6.0?topic=tasks-configuring-external-access) to retrieve the endpoints.
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
    my-odm-release-odm-ingress <none>   *       <INGRESS_ADDRESS>   80    1d
    ```

2. Register the redirect URIs into your PingFederate application.

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

   From the PingFederate admin console, in **Applications** / **Applications**
    - Edit the `ODM Application`
    - In the tab **Configuration**
    	* Add the redirect URIs in the **Redirect URIs** field for each component.

      For example, add the Decision Center redirect URI that you got earlier (`https://<DC_HOST>/decisioncenter/openid/redirect/odm` -- do not forget to replace <DC_HOST> with your actual host name!)
    - Click **Save** at the bottom of the page.

    ![Add URI](images/application_redirect_uris.png)


### Access the ODM services

Well done!  You can now connect to ODM using the endpoints you got [earlier](#register-the-odm-redirect-url) and log in as an ODM admin with your account.

### Set up Rule Designer

First set up Rule Designer following [these instructions](https://www.ibm.com/docs/en/odm/9.6.0?topic=designer-installing-rule-online).

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

For more information, refer to [this documentation](https://www.ibm.com/docs/en/odm/9.6.0?topic=designer-importing-security-certificate-in-rule).

### Getting Started with IBM Operational Decision Manager for Containers

Get hands-on experience with IBM Operational Decision Manager in a container environment by following this [Getting started tutorial](https://github.com/DecisionsDev/odm-for-container-getting-started/blob/master/README.md).

### Calling the ODM Runtime Service

Log in the Business Console.

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
       -d "client_id=${CLIENT_ID}&scope=odm_cc&client_secret=${CLIENT_SECRET}&grant_type=client_credentials" \
       "${PING_FEDERATE_SERVER_URL}/token"
  ```

 And use the retrieved access token in the following way:

  ```
  curl -H "Content-Type: application/json" -k --data @payload.json \
       -H "Authorization: Bearer <ACCESS_TOKEN>" \
       https://<DS_RUNTIME_HOST>/DecisionService/rest/production_deployment/1.0/loan_validation_production/1.0
  ```

# Troubleshooting

If you encounter any issue, have a look at the [OpenID Connect troubleshooting Tips](/troubleshooting/OpenID/README.md)

# License

[Apache 2.0](/LICENSE)
