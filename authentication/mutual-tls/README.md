# Configuration of ODM Runtime using mutual TLS

<!-- TOC depthfrom:1 depthto:6 withlinks:false updateonsave:false orderedlist:false -->
- [Introduction](#introduction)
    - [What is mTLS?](#what-is-mtls)
    - [About this task](#about-this-task)
<!-- /TOC -->

# Introduction

We already provide several tutorials explaining how to configure ODM on K8S with major OpenId provider vendors like Microsoft EntraID, OKTA, Keycloak and Amazon Cognito.
The OpenID protocol is well adapted to manage SSO when dealing with an Identity, which is quite interesting to connect to UI in a web browser like the Decision Center Business Console or the Desision Server RES Console.
However, for machine to machine communication where there is no identity needs and especially for runtime execution that are performance demanding, the openId protocol is less adapted and mutual TLS is providing enough security by avoiding the following OpenId drawbacks :
- less configuration complexity 
- no token management => expiracy management
- no third party communication needed (OpenId provider)

But, mTLS can recquire a certificate rotation management, which is also the case for OpenId (client_secret and/or certificate)
    

## What is mTLS?

Mutual TLS (Transport Layer Security) — also called two-way SSL — is an extension of the standard HTTPS protocol that provides strong, mutual authentication between a client and a server.

In regular HTTPS, only the server presents a certificate, so the client can verify it’s talking to the right host.
In mutual TLS, both sides — the client and the server — present and verify digital certificates.

That’s why it’s called mutual TLS.
Here is a description the way it works :

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

6/ Handshake completes
→ Both sides now trust each other, and encrypted communication begins.

![mTLS Client-Server flow](images/mtls.png)


## About this task


