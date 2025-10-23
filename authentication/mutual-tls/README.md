# Configuration of ODM Runtime using mutual TLS

<!-- TOC depthfrom:1 depthto:6 withlinks:false updateonsave:false orderedlist:false -->
- [Introduction](#introduction)
    - [What is mTLS?](#what-is-mtls)
    - [How works mTLS?](#how-works-mtls)
- [Prepare your environment for the ODM installation](#prepare-your-environment-for-the-odm-installation)
    - [Using the IBM Entitled Registry with your IBMid](#using-the-ibm-entitled-registry-with-your-ibmid)
    - [Manage a server certificate for the ODM instance](#manage-a-server-certificate-for-the-odm-instance)
    - [Manage a client certificate to communicate with the ODM Runtime](#manage-a-client-certificate-to-communicate-with-the-odm-runtime)
- [Install your ODM Helm release](#install-your-odm-helm-release)
- [Test mTLS](#test-mtls)
    - [Call ODM Decision Server Runtime with curl](#call-odm-decision-server-runtime-with-curl)
    - [Call ODM Decision Server Runtime with java](#call-odm-decision-server-runtime-with-java)
    - [Access the Decision Server Runtime Console using a browser](#access-the-decision-server-runtime-console-using-a-browser)
<!-- /TOC -->

# Introduction

We already provide several tutorials explaining how to configure ODM on K8S with major OpenId provider vendors like Microsoft EntraID, OKTA, Keycloak and Amazon Cognito.
The OpenID protocol is well adapted to manage SSO when dealing with an Identity, which is quite interesting to connect to UI in a web browser like the Decision Center Business Console or the Decision Server RES Console.
However, for machine to machine or service to service communication where no identity is needed like a batch processing, the openId protocol is less adapted than mutual TLS.
mTLS or client authentication comes into play when the server wants to allow only specific clients to connect. As with TLS, where the server proves its identity to the client via a server certificate, we can use a client certificate to verify that the client is who it claims to be.

Here, mTLS is providing enough security, like openId but by avoiding several drawbacks : 

- no identity needed 
- less configuration complexity 
- no token management => no need of token expiracy management
- better performance as there is less latency (no third party communication to the OpenId provider managing token validation)

But, mTLS can require a certificate rotation management, which is also the case for OpenId (client_secret and/or certificate)

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

# Prepare your environment for the ODM installation

To get access to the ODM material, you must have an IBM entitlement key to pull the images from the IBM Entitled Registry.

## Using the IBM Entitled Registry with your IBMid

Log in to [MyIBM Container Software Library](https://myibm.ibm.com/products-services/containerlibrary) with the IBMid and password that are associated with the entitled software.

In the Container software library tile, verify your entitlement on the View library page, and then go to Get entitlement key to retrieve the key.

Create a pull secret by running the `kubectl create secret` command.

```shell
kubectl create secret docker-registry <ibm-entitlement-key> --docker-server=cp.icr.io \
                                                       --docker-username=cp \
                                                       --docker-password="<entitlementkey>" \
                                                       --docker-email=<email>
```
Where:

* \<ibm-entitlement-key\> is the secret name
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

## Manage a server certificate for the ODM instance

1. Generate a self-signed server certificate.

For the server certificate, there are 2 options :

* Use the OCP ingress certificate 
* Generate a certificate compatible with the OCP domain name

The best way to inject in the ODM deployment a domain valid certificate is to copy it from the OCP ingress.
On OCP, there is a router-certs-default secret inside the openshift-ingress namespace.
Get the tls.crt public key and the tls.key private key from this secret

```shell
oc extract secret/router-certs-default -n openshift-ingress  
```
So you can rename the tls.crt as myserver.crt and tls.key as myserver.key, for the next step of the tutorial

```shell
mv tls.crt myserver.crt
mv tls.key myserver.key
```

> [!NOTE]
> On ROKS, this secret is named [default-ingress-cert](https://github.com/DecisionsDev/odm-docker-kubernetes/blob/mutual-tls/platform/roks/README.md#a-get-the-roks-domain-certificate).

If you do not have a trusted certificate, you can use OpenSSL and other cryptography and certificate management libraries to generate a certificate file and a private key, to define the domain name, and to set the expiration date. The following command creates a self-signed certificate (.crt file) and a private key (.key file) that accept the domain name *myserver.com*. The expiration is set to 1000 days:

```shell
openssl req -x509 -nodes -days 1000 -newkey rsa:2048 -keyout myserver.key \
        -out myserver.crt -subj "/CN=myserver.com/OU=it/O=myserver/L=Paris/C=FR" \
        -addext "subjectAltName=DNS:myserver.com,DNS:*.<OCP_DOMAIN_NAME>"
```

   Where:
    - *<OCP_DOMAIN_NAME>* is the OpenShift Cluster Domain Name that looks like apps.XXX.XXX.XXX.com


> [!NOTE]
> You can use -addext only with actual OpenSSL and from LibreSSL 3.1.0.

2. Create a Kubernetes secret with the server certificate.

```shell
kubectl create secret generic my-server-secret --from-file=tls.crt=myserver.crt --from-file=tls.key=myserver.key
```

The certificate must be the same as the one you used to enable TLS connections in your ODM release. For more information, see [Server certificates](https://www.ibm.com/docs/en/odm/9.5.0?topic=servers-server-certificates).

## Manage a client certificate to communicate with the ODM Runtime

1. Generate a self-signed client certificate.

If you do not have a trusted certificate, you can use OpenSSL and other cryptography and certificate management libraries to generate a certificate file and a private key, to define the domain name, and to set the expiration date. The following command creates a self-signed certificate (.crt file) and a private key (.key file) that accept the domain name *myclient.com*. The expiration is set to 1000 days:

```shell
openssl req -x509 -nodes -days 1000 -newkey rsa:2048 -keyout myclient.key \
        -out myclient.crt -subj "/CN=myclient.com/OU=it/O=myserver/L=Paris/C=FR" \
        -addext "subjectAltName = DNS:myclient.com"
```

2. Create a Kubernetes secret with the client certificate.

```shell
kubectl create secret generic my-client-secret --from-file=tls.crt=myclient.crt
```

> [!NOTE]
> The mTLS communication can be managed using the same certificate on the client and the server side.
> If this solution is preferred, then, no need to create the client certificate neither this secret

# Install your ODM Helm release

You can now install the product. We will use the PostgreSQL internal database and disable data persistence (`internalDatabase.persistence.enabled=false`) to avoid any platform complexity with persistent volume allocation.

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

> **Optional:**
> - As mTLS will be activated. It could represent enough security to execute the ODM runtime. So, we could avoid to manage the authentication/authorization mechanism.
> To set it, we will override the default ODM Decision Server Runtime authorization mechanism.
> Create a dedicated secret using the [libertyHookEnd.xml](./libertyHookEnd.xml) file :
>
>```bash
>kubectl create secret generic no-authorization-secret --from-file=libertyHookEnd.xml
>```
>
> You can run the ODM deployment using the [ocp-no-authorization-values.yaml](./ocp-no-authorization-values.yaml)
> ```bash
> helm install mtls-tuto ibm-helm/ibm-odm-prod -f ocp-no-authorization-values.yaml
>

# Test mTLS

## Call ODM Decision Server Runtime with curl

Now, ODM Decision Server Runtime is configured for mTLS. It means that all call must be executed  with a trusted certificate.

```bash
curl -k -v --cert myclient.crt --key myclient.key -H "Content-Type: application/json" --data @payload.json \
     https://<DECISION_SERVER_RUNTIME_ROUTE>/DecisionService/rest/production_deployment/1.0/loan_validation_production/1.0 \
     -u odmAdmin:odmAdmin
```

Replace <DECISION_SERVER_RUNTIME_ROUTE> placeholder by getting the ODM Decision Server Route Name :

```bash
oc get route --no-headers | grep odm-decisionserverruntime | awk '{print $2}'
```
> **Optional:**
> Using the specific no authorization deployment, you can remove the '-u odmAdmin:odmAdmin' parameter

The verbose mode will provide you detailed information about the ssl handshake that should look like :

* Host <XXX.XXX.XXX.XXX>:443 was resolved.
* IPv6: (none)
* IPv4: XXX.XXX.XXX.XXX
*   Trying XXX.XXX.XXX.XXX:443...
* ALPN: curl offers h2,http/1.1
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
* TLSv1.3 (IN), TLS handshake, Server hello (2):
* TLSv1.3 (IN), TLS change cipher, Change cipher spec (1):
* TLSv1.3 (IN), TLS handshake, Encrypted Extensions (8):
* TLSv1.3 (IN), TLS handshake, Request CERT (13):
* TLSv1.3 (IN), TLS handshake, Certificate (11):
* TLSv1.3 (IN), TLS handshake, CERT verify (15):
* TLSv1.3 (IN), TLS handshake, Finished (20):
* TLSv1.3 (OUT), TLS change cipher, Change cipher spec (1):
* TLSv1.3 (OUT), TLS handshake, Certificate (11):
* TLSv1.3 (OUT), TLS handshake, CERT verify (15):
* TLSv1.3 (OUT), TLS handshake, Finished (20):
* SSL connection using TLSv1.3 / TLS_AES_256_GCM_SHA384 / x25519 / RSASSA-PSS
* ALPN: server accepted h2
* Server certificate:
*  subject: CN=myserver.com; OU=it; O=myserver; L=Paris; C=FR
*  start date: Oct 17 15:01:06 2025 GMT
*  expire date: Jul 13 15:01:06 2028 GMT
*  issuer: CN=myserver.com; OU=it; O=myserver; L=Paris; C=FR
*  SSL certificate verify result: self-signed certificate (18), continuing anyway.
*   Certificate level 0: Public key type RSA (2048/112 Bits/secBits), signed using sha256WithRSAEncryption
* Connected to <DECISION_SERVER_RUNTIME_ROUTE> (XXX.XXX.XXX.XXX) port 443
* using HTTP/2

## Call ODM Decision Server Runtime with java

Create a java project using your preferred IDE and import the [DecisionServiceExecution.java](./DecisionServiceExecution.java) and [payload.json](./payload.json) files
We need to create a client-keystore.p12 file that will be used to send the client certificate in the HTTP request.

Create a client-keystore.p12 file and push it in the java project by replacing the <KEYSTORE-PASSWORD> placeholder in the [DecisionServiceExecution.java](./DecisionServiceExecution.java) file.

```bash
openssl pkcs12 -export -inkey myclient.key -in myclient.crt -name MYCLIENT -out client-keystore.p12 -passout pass:<KEYSTORE-PASSWORD>
```                	

   Where:
    - *KEYSTORE-PASSWORD* is the password of your choice.

Create the server-truststore.p12 file and push it in the java project by replacing the <TRUSTSTORE-PASSWORD> placeholder in the [DecisionServiceExecution.java](./DecisionServiceExecution.java) file.

```bash
keytool -import -file myserver.crt -srcstoretype PKCS12 -keystore server-truststore.p12 -storepass <TRUSTSTORE-PASSWORD> -alias ODM-RUNTIME -noprompt
```

   Where:
    - *TRUSTSTORE-PASSWORD* is the password of your choice.

Replace <DECISION_SERVER_RUNTIME_ROUTE> placeholder in the [DecisionServiceExecution.java](./DecisionServiceExecution.java) file by getting the ODM Decision Server Route Name :

```bash
oc get route --no-headers | grep odm-decisionserverruntime | awk '{print $2}'
```

Now you can call the ODM Decision Server Runtime using a java HTTP request with a client certificate.

> **Optional:**
> Using the specific no authorization deloyment, you can comment the **.header("Authorization", "Basic b2RtQWRtaW46b2RtQWRtaW4=")** Authorization header in the [DecisionServiceExecution.java](./DecisionServiceExecution.java) file 

## Access the Decision Server Runtime Console using a browser

You can see that's now impossible to access the https://<DECISION_SERVER_RUNTIME_ROUTE>/DecisionService/ URL using a browser.
You have to import and trust the client certificate key chain in your operating system.

Using the previously generated client-keystore.p12 file, you can follow the step 2 of this [article](https://velmuruganv.wordpress.com/2020/04/27/mtls-mutual-tls-authentication-chrome/) to import it in Chrome.

On MacOS, you can see this [video](https://www.youtube.com/watch?v=unXpQNi858Q) on how to importand trust the client certificate in MacOS Keychain Access, using the client-keystore.p12 file.

