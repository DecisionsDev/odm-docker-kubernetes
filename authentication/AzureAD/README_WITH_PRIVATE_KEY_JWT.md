
# Introduction
OpenID Client Credentials with a private key is a robust and secure way for client applications to authenticate themselves when interacting with OpenID Connect providers. This method involves the use of a public-private key pair, similar to SSL/TLS certificates, to verify the client's identity. The private key is securely held by the client, while the public key is registered with the authorization server.

For additional information regarding the implement in Liberty, please refer to this [link](https://openliberty.io/blog/2023/09/19/23.0.0.9.html#jwt).

# Set up a Microsoft Entra ID application using a private key JWT

<!-- TOC -->

- [Set up a Microsoft Entra ID application using a private key JWT](#set-up-a-microsoft-entra-id-application-using-a-private-key-jwt)
- [Deploy ODM on a container configured with Microsoft Entra ID Part 2](#deploy-odm-on-a-container-configured-with-microsoft-entra-id-part-2)
    - [Prepare your environment for the ODM installation](#prepare-your-environment-for-the-odm-installation)
        - [Create a secret to use the Entitled Registry](#create-a-secret-to-use-the-entitled-registry)
        - [Create secrets to configure ODM with Microsoft Entra ID](#create-secrets-to-configure-odm-with-microsoft-entra-id)
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

## 1. Create the *ODM application*.

In **Microsoft Entra Id** / **Manage** / **App registration**, click **New Registration**:

* Name: **ODM Application**
* Supported account types / Who can use this application or access this API?: select `Accounts in this organizational directory only (Default Directory only - Single tenant)`
* Click **Register**

![New Web Application](images/RegisterApp.png)

## 2. Retrieve Tenant and Client information

In **Microsoft Entra Id** / **Manage** / **App Registration**, select **ODM Application** and click **Overview**:

* Application (client) ID: **Client ID**. It will be referenced as `CLIENT_ID` in the next steps.
* Directory (tenant) ID: **Your Tenant ID**. It will be referenced as `TENANT_ID` in the next steps.

![Tenant ID](images/GetTenantID.png)

## 3. Register a public certificate.

To manage private key JWT authentication, you need a private certificate (.key file) and a public certificate (.crt file), which should be registered on the ODM client side (RP) application. On the Microsoft Entra ID (OP) side, you are required to register the public certificate.

If you don't have a trusted certificate, you can utilize OpenSSL and other cryptography and certificate management libraries to generate a certificate file and a private key, define the domain name, and set the expiration date. The following command will create a self-signed certificate (.crt file) and a private key (.key file) that will accept the domain name myodmcompany.com.
The expiration is set to 1000 days:

```shell
    openssl req -x509 -nodes -days 1000 -newkey rsa:2048 -keyout myodmcompany.key \
    -out myodmcompany.crt -subj "/CN=myodmcompany.com/OU=it/O=myodmcompany/L=Paris/C=FR" \
    -addext "subjectAltName = DNS:myodmcompany.com"
```

In **Microsoft Entra Id** / **Manage** / **App registrations**, select **ODM Application**:

* From the Overview page, click on the link Client credentials: **Add a certificate or secret** or on the **Manage / Certificates & secrets** tab
* Select the **Certificates** tab
* Click **Upload certificate**
  * Select the `myodmcompany.crt` or your own public file
  * Description: `For ODM integration`
  * Click **Add**

## 4. Add Claims.

In **Microsoft Entra Id** / **Manage** / **App registrations**, select **ODM Application**, and in **Manage / Token Configuration**:

* Add Optional **email** ID Claim
  * Click **+ Add optional claim**
  * Select **ID**
  * Check **email**
  * Click **Add**

  * Turn on Microsoft Graph email permission
    * Check **Turn on the Microsoft Graph email permission**
    * Click **Add**

* Add Optional **email** Access Claim
  * Click **+ Add optional claim**
  * Select **Access**
  * Check **email**
  * Click **Add**

* Add Group Claim
  * Click **+ Add groups claim**
  * Check **Security Groups**
  * Click **Add**

## 5. Create a custom claim named "identity"

To enable the ODM REST API to use both the 'Password Credentials' flow with email as the user identifier and the 'Client Credentials' flow with client_id as the user identifier, we must establish a new claim named "identity" that will dynamically capture the appropriate value based on the chosen flow:
In **Microsoft Entra Id** / **Manage** / **Enterprise applications**, select **ODM Application**, and in **Manage / Single sign-on**:

* Click on Edit of the "Attributes & Claims" section
  * Click **+ Add new claim**
    * Name: `identity`
    * Fill 2 Claim conditions in the exact following order:
      1. User Type: Any / Scoped Groups: 0 / Source: Attribute / Value: <CLIENT_ID>
      2. User Type: Members / Scoped Groups: 0 / Source: Attribute / Value: user.mail

## 6. API Permissions.

In **Microsoft Entra Id** / **Manage** / **App Registration**, select **ODM Application**, and then click **API Permissions**.

* Click **Grant Admin Consent for <Directory name>**

![Permissions](images/Permissions.png)

## 7. Manifest change.

In **Microsoft Entra Id** / **Manage** / **App Registration**, select **ODM Application**, and then click **Manifest**.

The Manifest feature (a JSON representation of an app registration) is currently in transition.
[**AAD Graph app manifest**](https://learn.microsoft.com/en-us/entra/identity-platform/azure-active-directory-graph-app-manifest-deprecation) will be deprecated soon and not editable anymore starting 12/2/2024. It will be replaced by the **Microsoft Graph App Manifest**

As explained in [accessTokenAcceptedVersion attribute explanation](https://docs.microsoft.com/en-us/azure/active-directory/develop/reference-app-manifest#accesstokenacceptedversion-attribute), change the value to 2.

ODM OpenID Liberty configuration needs version 2.0 for the issuerIdentifier. See the [openIdWebSecurity.xml](templates/openIdWebSecurity.xml) file.

It is also necessary to set **acceptMappedClaims** to true to manage claims. Without this setting, you get the exception **AADSTS50146: This application is required to be configured with an application-specific signing key. It is either not configured with one, or the key has expired or is not yet valid.** when requesting a token.

With **Microsoft Graph App Manifest**:
  *  **acceptMappedClaims** is relocated as a property of the **api** attribute
  *  **accessTokenAcceptedVersion** is relocated as a property of the **api** attribute and renamed **requestedAccessTokenVersion**

Then, click Save.

![Manifest](images/Manifest.png)

# Deploy ODM on a container configured with Microsoft Entra ID (Part 2)

## Prepare your environment for the ODM installation

### Create a secret to use the Entitled Registry

1. To get your entitlement key, log in to [MyIBM Container Software Library](https://myibm.ibm.com/products-services/containerlibrary) with the IBMid and password that are associated with the entitled software.

    In the **Container software library** tile, verify your entitlement on the **View library** page, and then go to **Get entitlement key**  to retrieve the key.

2. Create a pull secret by running a `kubectl create secret` command.

    ```shell
    $ kubectl create secret docker-registry ibm-entitlement-key \
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

### Create secrets to configure ODM with Microsoft Entra ID

1. Create a secret with the Microsoft Entra ID Server certificate.

    To allow ODM services to access the Microsoft Entra ID Server, it is mandatory to provide the Microsoft Entra ID Server certificate.
    You can create the secret as follows:

    ```shell
    keytool -printcert -sslserver login.microsoftonline.com -rfc > microsoft.crt
    kubectl create secret generic ms-secret --from-file=tls.crt=microsoft.crt
    ```

    Introspecting the Microsoft Entra ID login.microsoftonline.com certificate, you can see it has been signed by the Digicert Root CA authorithy.

    So we will also add the DigiCert Global Root CA from [this page](https://www.digicert.com/kb/digicert-root-certificates.htm):

    ```shell
    curl --silent --remote-name https://cacerts.digicert.com/DigiCertGlobalRootCA.crt.pem
    kubectl create secret generic digicert-secret --from-file=tls.crt=DigiCertGlobalRootCA.crt.pem
    ```

2. Create a secret to provide the private and public certificate to manage the private_key_jwt authentication

   To allow ODM containers to generate a client_assertion, you have to provide them the private and public certificates with the following **myodmcompany** secret. Don't change this name with this tutorial as this name is linked to the openidConnectClient **keyAliasName="myodmcompany"**  parameter of the private_key_jwt liberty configuration.

    ```shell
    kubectl create secret generic myodmcompany --from-file=tls.key=myodmcompany.key --from-file=tls.crt=myodmcompany.crt
    ```

3. Generate the ODM configuration file for Microsoft Entra ID.

    If you have not yet done so, download the [azuread-odm-script.zip](azuread-odm-script.zip) file to your machine. This archive contains the [script](generateTemplateForPrivateKeyJWT.sh) and the content of the [templates_for_privatekeyjwt](templates_for_privatekeyjwt) directory.

    The [script](generateTemplateForPrivateKeyJWT.sh) allows you to generate the necessary configuration files.
    Generate the files with the following command:

    ```shell
    ./generateTemplateForPrivateKeyJWT.sh -i <CLIENT_ID> -n <TENANT_ID> -g <GROUP_ID> [-a <SSO_DOMAIN>]
    ```

    Where:
    - *TENANT_ID* and *CLIENT_ID* have been obtained from [previous step](#2-retrieve-tenant-and-client-information)
    - *GROUP_ID* is the identifier of the ODM Admin group created in [Manage groups and users](README.md#manage-groups-and-users) (*ID of `odm-admin`*)
    - *SSO_DOMAIN* is the domain name of your SSO. If your AzureAD is connected to another SSO, you should add the SSO domain name in this parameter. If your user has been declared as explained in step **Create at least one user that belongs to this new group**, you can omit this parameter.

    The following four files are generated into the `outputPKeyJWT` directory:

    - webSecurity.xml contains the mapping between Liberty J2EE ODM roles and Microsoft Entra ID groups and users:
      * All ODM roles are given to the GROUP_ID group
      * rtsAdministrators/resAdministrators/resExecutors ODM roles are given to the CLIENT_ID (which is seen as a user) to manage the client-credentials flow
    - openIdWebSecurity.xml contains two openIdConnectClient Liberty configurations:
      * For web access to the Decision Center an Decision Server consoles using userIdentifier="email" with the Authorization Code flow
      * For the rest-api call using userIdentifier="aud" with the client-credentials flow
    - openIdParameters.properties configures several features like allowed domains, logout, and some internal ODM OpenId features
    - OdmOidcProviders.json configures the client-credentials OpenId provider used by the Decision Center server configuration to connect Decision Center to the Decision Server console and Decision Center to the Decision Runner

4. Create the Microsoft Entra ID authentication secret.

    ```shell
    kubectl create secret generic azuread-auth-secret \
        --from-file=OdmOidcProviders.json=./outputPKeyJWT/OdmOidcProviders.json \
        --from-file=openIdParameters.properties=./outputPKeyJWT/openIdParameters.properties \
        --from-file=openIdWebSecurity.xml=./outputPKeyJWT/openIdWebSecurity.xml \
        --from-file=webSecurity.xml=./outputPKeyJWT/webSecurity.xml
    ```

## Install your ODM Helm release

### Add the public IBM Helm charts repository

  ```shell
  helm repo add ibm-helm https://raw.githubusercontent.com/IBM/charts/master/repo/ibm-helm
  helm repo update
  ```

### Check that you can access the ODM chart

  ```shell
  helm search repo ibm-odm-prod
  NAME                  	CHART VERSION	APP VERSION	DESCRIPTION
  ibm-helm/ibm-odm-prod	25.0.0       	9.5.0.0   	IBM Operational Decision Manager
  ```

### Run the `helm install` command

You can now install the product. We will use the PostgreSQL internal database and disable the data persistence (`internalDatabase.persistence.enabled=false`) to avoid any platform complexity concerning persistent volume allocation.

#### a. Installation on OpenShift using Routes

  See the [Preparing to install](https://www.ibm.com/docs/en/odm/9.5.0?topic=production-preparing-install-operational-decision-manager) documentation for additional information.
  Get the [entraid-pkjwt-ocp-values.yaml](./entraid-pkjwt-ocp-values.yaml) file and run the command:

  ```shell
  helm install my-odm-release ibm-helm/ibm-odm-prod -f entraid-pkjwt-ocp-values.yaml
  ```
> **Note**
> This command installs the **latest available version** of the chart.  
> If you want to install a **specific version**, add the `--version` option:
>
> ```bash
> helm install my-odm-release ibm-helm/ibm-odm-prod --version <version> -f entraid-pkjwt-ocp-values.yaml
> ```
>
> You can list all available versions using:
>
> ```bash
> helm search repo ibm-helm/ibm-odm-prod -l
> ```

#### b. Installation using Ingress

  Refer to the following documentation to install an NGINX Ingress Controller on:
  - [Microsoft Azure Kubernetes Service](../../platform/azure/README-NGINX.md)
  - [Amazon Elastic Kubernetes Service](../../platform/eks/README-NGINX.md)
  - [Google Kubernetes Engine](../../platform/gcloud/README_NGINX.md)

  When the NGINX Ingress Controller is ready, get the [entraid-pkjwt-nginx-values.yaml](./entraid-pkjwt-nginx-values.yaml) file and run the command:

  ```
  helm install my-odm-release ibm-helm/ibm-odm-prod -f entraid-pkjwt-nginx-values.yaml
  ```

> **Note**
> By default, NGINX does not enable sticky session. If you want to use sticky session to connect to DC, refer to [Using sticky session for Decision Center connection](../../contrib/sticky-session/README.md)

> **Note**
> This command installs the **latest available version** of the chart.
> If you want to install a **specific version**, add the `--version` option:
>
> ```bash
> helm install my-odm-release ibm-helm/ibm-odm-prod --version <version> -f entraid-pkjwt-nginx-values.yaml
> ```
>
> You can list all available versions using:
>
> ```bash
> helm search repo ibm-helm/ibm-odm-prod -l
> ```

## Complete post-deployment tasks

### Register the ODM redirect URLs

1. Get the ODM endpoints.

    Refer to the [documentation](https://www.ibm.com/docs/en/odm/9.5.0?topic=tasks-configuring-external-access) to retrieve the endpoints.
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

3. Register the redirect URIs into your Microsoft Entra ID application.

    The redirect URIs are built the following way:

      Using Routes:
      - Decision Center redirect URI:  `https://<DC_HOST>/decisioncenter/openid/redirect/odm`
      - Decision Runner redirect URI:  `https://<DR_HOST>/DecisionRunner/openid/redirect/odm`
      - Decision Server Console redirect URI:  `https://<DS_CONSOLE_HOST>/res/openid/redirect/odm`
      - Decision Server Runtime redirect URI:  `https://<DS_RUNTIME_HOST>/DecisionService/openid/redirect/odm`

      Using Ingress:
      - Decision Center redirect URI:  `https://<INGRESS_ADDRESS>/decisioncenter/openid/redirect/odm`
      - Decision Runner redirect URI:  `https://<INGRESS_ADDRESS>/DecisionRunner/openid/redirect/odm`
      - Decision Server Console redirect URI:  `https://<INGRESS_ADDRESS>/res/openid/redirect/odm`
      - Decision Server Runtime redirect URI:  `https://<INGRESS_ADDRESS>/DecisionService/openid/redirect/odm`

   From the Azure console, in **Microsoft Entra Id** / **Manage** / **App Registrations** / **ODM Application**:

    - Click`Add Redirect URIs link`
    - Click `Add Platform`
    - Select `Web`
    - `Redirect URIs` Add the Decision Center redirect URI that you got earlier (`https://<DC_HOST>/decisioncenter/openid/redirect/odm` -- don't forget to replace <DC_HOST> with your actual host name!)
    - Check `Access Token` and `ID Token`
    - Click `Configure`
    - Click `Add URI Link` and enter another redirect URI
      - Repeat the previous step until all the redirect URIs have been entered

    - Click **Save** at the bottom of the page.
    ![Add URI](images/AddURI.png)

4. Register the Rule Designer callback into your Microsoft Entra ID application.

   The ODM Rule Designer will use the [PKCE authorization code flow](https://oauth.net/2/pkce/) to connect to Decision Center and Decision Server Console.

   From the Azure console, in **Microsoft Entra Id** / **Manage** / **App Registrations** / **ODM Application**:

    - Click`Add Redirect URIs link`
    - Click `Add Platform`
    - Select `Mobile and desktop applications`
    - `Custom redirect URIs` Add the Rule Designer callback `https://127.0.0.1:9081/oidcCallback`

    - Click **Configure** at the bottom of the page.
    ![Add URI](images/AddRDCallback.png)

### Access the ODM services

Well done!  You can now connect to ODM using the endpoints you got [earlier](#register-the-odm-redirect-urls) and log in as an ODM admin with the account you created in ['manage groups and users' in the first article](README.md#manage-groups-and-users).

### Set up Rule Designer

To be able to securely connect your Rule Designer to the Decision Server and Decision Center services that are running in Certified Kubernetes, you need to establish a TLS connection through a security certificate in addition to the OpenID configuration.

1. Get the following configuration files:

    * `https://<DC_HOST>/decisioncenter/assets/truststore.jks`
    * `https://<DC_HOST>/decisioncenter/assets/OdmOidcProvidersRD.json`
      Where *DC_HOST* is the Decision Center endpoint.

2. Copy the `truststore.jks` and `OdmOidcProvidersRD.json` files to your Rule Designer installation directory next to the `eclipse.ini` file.

3. Edit your `eclipse.ini` file and add the following lines at the end:

    ```
    -Dcom.ibm.rules.studio.oidc.synchro.scopes=<CLIENT_ID>/.default
    -Dcom.ibm.rules.studio.oidc.res.scopes=<CLIENT_ID>/.default
    -Djavax.net.ssl.trustStore=<ECLIPSEINITDIR>/truststore.jks
    -Djavax.net.ssl.trustStorePassword=changeme
    -Dcom.ibm.rules.authentication.oidcconfig=<ECLIPSEINITDIR>/OdmOidcProvidersRD.json
    ```

    Where:
    - *changeme* is the fixed password to be used for the default truststore.jks file.
    - *ECLIPSEINITDIR* is the Rule Designer installation directory next to the eclipse.ini file.

4. Restart Rule Designer.

For more information, refer to the [documentation](https://www.ibm.com/docs/en/odm/9.5.0?topic=designer-importing-security-certificate-in-rule).

### Getting Started with IBM Operational Decision Manager for Containers

Get hands-on experience with IBM Operational Decision Manager in a container environment by following this [Getting started tutorial](https://github.com/DecisionsDev/odm-for-container-getting-started/blob/master/README.md).

### Calling the ODM Runtime Service

To manage ODM runtime call on the next steps, we used the [Loan Validation Decision Service project](https://github.com/DecisionsDev/odm-for-container-getting-started/blob/master/Loan%20Validation%20Service.zip)

Import the **Loan Validation Service** in Decision Center connected using *myodmuser*@YOURDOMAIN created at step 2

![Import project](images/import_project.png)

Deploy the **Loan Validation Service** production_deployment ruleapps using the **production deployment** deployment configuration in the Deployments>Configurations tab.

![Deploy project](images/deploy_project.png)

You can retrieve the payload.json from the ODM Decision Server Console or use [the provided payload](payload.json).

As explained in the ODM on Certified Kubernetes documentation [Configuring user access with OpenID](https://www.ibm.com/docs/en/odm/9.5.0?topic=access-configuring-user-openid), we advise to use basic authentication for the ODM runtime call for performance reasons and to avoid the issue of token expiration and revocation.

You can realize a basic authentication ODM runtime call the following way:

  ```shell
curl -H "Content-Type: application/json" -k --data @payload.json \
        -H "Authorization: Basic b2RtQWRtaW46b2RtQWRtaW4=" \
      https://<DS_RUNTIME_HOST>/DecisionService/rest/production_deployment/1.0/loan_validation_production/1.0
```

Where b2RtQWRtaW46b2RtQWRtaW4= is the base64 encoding of the current username:password odmAdmin:odmAdmin

But if you want to execute a bearer authentication ODM runtime call using the Client Credentials flow, you have to get a bearer access token using a client_assertion.

Before to generate the client_assertion, you need a keystore.jks that will be build using the previously generated myodmcompany.key private key and myodmcompany.crt public key PEM files with the commands:

```shell
openssl pkcs12 -export -out myodmcompany.p12 -inkey myodmcompany.key -in myodmcompany.crt -passout pass:changeme
keytool -importkeystore -srckeystore myodmcompany.p12 -srcstoretype pkcs12 -srcalias 1 -srcstorepass changeme -destkeystore myodmcompany.jks -deststoretype jks -deststorepass changeme -destalias myalias
```

Now you can generate the client_assertion following the [ODM documentation](https://www.ibm.com/docs/en/odm/9.5.0?topic=950-generating-json-web-token-client-assertion).

```shell
java -cp $DCLIB/jrules-teamserver.jar:$DCLIB/jose4j-0.9.5.jar:$DCLIB/slf4j-api-1.7.25.jar com.ibm.rules.oauth.ClientAssertionHelper -clientId <CLIENT_ID> -tokenEndpoint https://login.microsoftonline.com/<TENANT_ID>/oauth2/v2.0/token -keyAliasName myalias -keyStorePwd changeme -keyStoreLocation ./myodmcompany.jks
```

Now, generate the access token using the client_assertion:

```shell
curl -k -X POST -H "Content-Type: application/x-www-form-urlencoded" \
    -d 'client_id=<CLIENT_ID>&scope=<CLIENT_ID>%2F.default&client_assertion_type=urn%3Aietf%3Aparams%3Aoauth%3Aclient-assertion-type%3Ajwt-bearer&client_assertion=<CLIENT_ASSERTION>&grant_type=client_credentials' \
    'https://login.microsoftonline.com/<TENANT_ID>/oauth2/v2.0/token'
```

And use the retrieved access token in the following way:

  ```shell
curl -H "Content-Type: application/json" -k --data @payload.json \
        -H "Authorization: Bearer <ACCESS_TOKEN>" \
        https://<DS_RUNTIME_HOST>/DecisionService/rest/production_deployment/1.0/loan_validation_production/1.0
```

# Troubleshooting

If you encounter any issue, have a look at the [common troubleshooting explanation](../README.md#troubleshooting)

# License

[Apache 2.0](/LICENSE)
