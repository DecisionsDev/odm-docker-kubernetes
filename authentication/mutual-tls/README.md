# Configuration of ODM Runtime using mutual TLS

<!-- TOC depthfrom:1 depthto:6 withlinks:false updateonsave:false orderedlist:false -->
- [Introduction](#introduction)
    - [What is mTLS?](#what-is-mtls)
    - [How works mTLS?](#how-works-mtls)
- [Configure mTLS on an ODM Instance](#configure-mtls-on-an-ODM-instance)
<!-- /TOC -->

# Introduction

We already provide several tutorials explaining how to configure ODM on K8S with major OpenId provider vendors like Microsoft EntraID, OKTA, Keycloak and Amazon Cognito.
The OpenID protocol is well adapted to manage SSO when dealing with an Identity, which is quite interesting to connect to UI in a web browser like the Decision Center Business Console or the Desision Server RES Console.
However, for machine to machine communication where there is no identity needs and especially for runtime execution that are performance demanding, the openId protocol is less adapted and mutual TLS is providing enough security by avoiding the following OpenId drawbacks :
- less configuration complexity 
- no token management => expiracy management
- no third party communication needed (OpenId provider)

But, mTLS can recquire a certificate rotation management, which is also the case for OpenId (client_secret and/or certificate)

In this tutorial, we will describe the step by step approach to setup mTLS on the ODM on K8S Decision Server Runtime deployed on OCP.

You can drill on the relevant platform tutorials to adapt it to your own platform. 


## What is mTLS?

Mutual TLS (Transport Layer Security) — also called two-way SSL — is an extension of the standard HTTPS protocol that provides strong, mutual authentication between a client and a server.

In regular HTTPS, only the server presents a certificate, so the client can verify it’s talking to the right host.
In mutual TLS, both sides — the client and the server — present and verify digital certificates.

That’s why it’s called mutual TLS.

mTLS helps ensure that traffic is secure and trusted in both directions between a client and server. This provides an additional layer of security for users who log in to an organization's network or applications. It also verifies connections with client devices that do not follow a login process, such as Internet of Things (IoT) devices.

mTLS prevents various kinds of attacks, including:

- On-path attacks: On-path attackers place themselves between a client and a server and intercept or modify communications between the two. When mTLS is used, on-path attackers cannot authenticate to either the client or the server, making this attack almost impossible to carry out.

- Spoofing attacks: Attackers can attempt to "spoof" (imitate) a web server to a user, or vice versa. Spoofing attacks are far more difficult when both sides have to authenticate with TLS certificates.

- Credential stuffing: Attackers use leaked sets of credentials from a data breach to try to log in as a legitimate user. Without a legitimately issued TLS certificate, credential stuffing attacks cannot be successful against organizations that use mTLS.

- Brute force attacks: Typically carried out with bots, a brute force attack is when an attacker uses rapid trial and error to guess a user's password. mTLS ensures that a password is not enough to gain access to an organization's network. (Rate limiting is another way to deal with this type of bot attack.)

- Phishing attacks: The goal of a phishing attack is often to steal user credentials, then use those credentials to compromise a network or an application. Even if a user falls for such an attack, the attacker still needs a TLS certificate and a corresponding private key in order to use those credentials.

- Malicious API requests: When used for API security, mTLS ensures that API requests come from legitimate, authenticated users only. This stops attackers from sending malicious API requests that aim to exploit a vulnerability or subvert the way the API is supposed to function.

## How works mTLS?

![mTLS Client-Server flow](images/mtls.png)

1/ Client connects to the server
→ Starts a TLS handshake (just like normal HTTPS).

2/ Server presents its certificate
→ The client verifies it using its truststore (e.g., checking that the certificate is issued by a trusted CA and the hostname matches).

3/ Server requests a client certificate
→ This is the key difference: the server asks the client to identify itself with a certificate.

4/ Client presents its certificate
→ The client sends its own X.509 certificate to the server, proving its identity.

5/ Server verifies the client certificate
→ The server checks that the client’s certificate was issued by a trusted CA and possibly matches an allowed subject or organization.

6/ Server grants access

7/ Handshake completes
→ Both sides now trust each other, and encrypted communication begins.

## Prepare your environment for the ODM installation

To get access to the ODM material, you must have an IBM entitlement key to pull the images from the IBM Entitled Registry.

### Using the IBM Entitled Registry with your IBMid (10 min)

Log in to [MyIBM Container Software Library](https://myibm.ibm.com/products-services/containerlibrary) with the IBMid and password that are associated with the entitled software.

In the Container software library tile, verify your entitlement on the View library page, and then go to Get entitlement key to retrieve the key.

Create a pull secret by running the `kubectl create secret` command.

```shell
kubectl create secret docker-registry <registrysecret> --docker-server=cp.icr.io \
                                                       --docker-username=cp \
                                                       --docker-password="<entitlementkey>" \
                                                       --docker-email=<email>
```
Where:

* \<registrysecret\> is the secret name
* \<entitlementkey\> is the entitlement key from the previous step. Make sure you enclose the key in double-quotes.
* \<email\> is the email address associated with your IBMid.

> [!NOTE]
> The `cp.icr.io` value for the `docker-server` parameter is the only registry domain name that contains the images. You must set the `docker-username` to `cp` to use an entitlement key as docker-password.

Make a note of the secret name so that you can set it for the `image.pullSecrets` parameter when you run a helm install of your containers.  The `image.repository` parameter should be set to `cp.icr.io/cp/cp4a/odm`.


Add the public IBM Helm charts repository:

```shell
helm repo add ibm-helm https://raw.githubusercontent.com/IBM/charts/master/repo/ibm-helm
helm repo update
```

Check that you can access the ODM charts:

```shell
helm search repo ibm-odm-prod
NAME                        CHART VERSION	APP VERSION DESCRIPTION
ibm-helm/ibm-odm-prod       25.1.0       	9.5.0.1     IBM Operational Decision Manager  License By in...
```

### Manage a 'server' certificate for the ODM instance

1. Generate a self-signed server certificate.

If you do not have a trusted certificate, you can use OpenSSL and other cryptography and certificate management libraries to generate a certificate file and a private key, to define the domain name, and to set the expiration date. The following command creates a self-signed certificate (.crt file) and a private key (.key file) that accept the domain name *myserver.com*. The expiration is set to 1000 days:

```shell
openssl req -x509 -nodes -days 1000 -newkey rsa:2048 -keyout myserver.key \
        -out myserver.crt -subj "/CN=myserver.com/OU=it/O=myserver/L=Paris/C=FR" \
        -addext "subjectAltName = DNS:myserver.com"
```

> [!NOTE]
> You can use -addext only with actual OpenSSL and from LibreSSL 3.1.0.

2. Create a Kubernetes secret with the server certificate.

```shell
kubectl create secret generic <my-server-secret> --from-file=tls.crt=myserver.crt --from-file=tls.key=myserver.key
```

The certificate must be the same as the one you used to enable TLS connections in your ODM release. For more information, see [Server certificates](https://www.ibm.com/docs/en/odm/9.5.0?topic=servers-server-certificates).

### Manage a 'client' certificate to communicate with the ODM Runtime

1. Generate a self-signed client certificate.

If you do not have a trusted certificate, you can use OpenSSL and other cryptography and certificate management libraries to generate a certificate file and a private key, to define the domain name, and to set the expiration date. The following command creates a self-signed certificate (.crt file) and a private key (.key file) that accept the domain name *myclient.com*. The expiration is set to 1000 days:

```shell
openssl req -x509 -nodes -days 1000 -newkey rsa:2048 -keyout myclient.key \
        -out myclient.crt -subj "/CN=myclient.com/OU=it/O=myserver/L=Paris/C=FR" \
        -addext "subjectAltName = DNS:myclient.com"
```

2. Create a Kubernetes secret with the client ertificate.

```shell
kubectl create secret generic <my-client-secret> --from-file=tls.crt=myclient.crt
```

> [!NOTE]
> The mTLS communication can be managed using the same certificate on the client and the server side.
> If this solution is preferred, then, no need to create the client certificate neither this secret

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
  ibm-helm/ibm-odm-prod	     25.1.0       	9.5.0.1   	IBM Operational Decision Manager
  ```

### 3. Run the `helm install` command

You can now install the product. We will use the PostgreSQL internal database and disable data persistence (`internalDatabase.persistence.enabled=false`) to avoid any platform complexity with persistent volume allocation.

#### a. Installation on OpenShift using Routes

  See the [Preparing to install](https://www.ibm.com/docs/en/odm/9.5.0?topic=production-preparing-install-operational-decision-manager) documentation for more information.

Get the [ocp-values.yaml](./ocp-values.yaml) file and install your ODM instance:

```bash
helm install mtls-tuto ibm-helm/ibm-odm-prod -f ocp-values.yaml
```

> **Note:**  
> - This command installs the **latest available version** of the chart. If you want to install a **specific version**, add the `--version` option:
>
> ```bash
> helm install mtls-tuto ibm-helm/ibm-odm-prod --version <version> -f ocp-values.yaml
> ```
>
> You can list all available versions using:
>
> ```bash
> helm search repo ibm-helm/ibm-odm-prod -l
> ```
> 
> - This configuration will deployed ODM with a sample database. You should used your own database such as [IBM Cloud Databases for PostgreSQL](https://www.ibm.com/products/databases-for-postgresql) for production.


