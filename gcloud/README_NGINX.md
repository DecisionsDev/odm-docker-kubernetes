# Install an ODM Helm release and expose it with a NGINX Ingress controller (15 min)

This section explains how to expose the ODM services to Internet connectivity with Ingress.
For reference, see the Google Cloud documentation https://cloud.google.com/community/tutorials/nginx-ingress-gke

<!-- TOC titleSize:2 tabSpaces:2 depthFrom:1 depthTo:6 withLinks:1 updateOnSave:1 orderedList:0 skip:0 title:1 charForUnorderedList:* -->
## Table of Contents
* [Install an ODM Helm release and expose it with a NGINX Ingress controller (15 min)](#install-an-odm-helm-release-and-expose-it-with-a-nginx-ingress-controller-15-min)
  * [Create a Kubernetes secret for the TLS certificate](#create-a-kubernetes-secret-for-the-tls-certificate)
  * [Install the ODM release](#install-the-odm-release)
  * [Edit your /etc/hosts](#edit-your-etchosts)
  * [Access the ODM services](#access-the-odm-services)
  * [Troubleshooting](#troubleshooting)
* [License](#license)
<!-- /TOC -->

NGINX has been installed while deploying IBM License Manager, see [README.md](README.md#create-a-nginx-ingress-controller).

## Create a Kubernetes secret for the TLS certificate

For more informations see https://docs.microsoft.com/en-US/azure/aks/ingress-own-tls#create-kubernetes-secret-for-the-tls-certificate

1. (Optional) Generate a self-signed certificate

If you do not have a trusted certificate, you can use OpenSSL and other cryptography and certificate management libraries to generate a certificate file and a private key, to define the domain name, and to set the expiration date. The following command creates a self-signed certificate (.crt file) and a private key (.key file) that accept the domain name *mycompany.com*. The expiration is set to 1000 days:

```
openssl req -x509 -nodes -days 1000 -newkey rsa:2048 -keyout mycompany.key \
        -out mycompany.crt -subj "/CN=mycompany.com/OU=it/O=mycompany/L=Paris/C=FR"
```

2. Create the according Kubernetes secret that contains the certificate

```
kubectl create secret tls <mycompanytlssecret> --key mycompany.key --cert mycompany.crt
```

## Install the ODM release

You can now install the product:

The ODM instance is using the externalCustomDatabase parameters to import the PostgreSQL datasource and driver. The ODM services will be exposed through NGINX thanks to the dedicated Ingress annotation (kubernetes.io/ingress.class: nginx). It allows sticky session needed by decision center thanks to the affinity annotation (nginx.ingress.kubernetes.io/affinity: cookie).  The secured HTTPS communcation is managed by NGINX. So, we disable the ODM internal TLS as it's not needed. We use a kustomize as post-rendering to change the decision server readiness because the GKE loadbalancer is using it to create service healthCheck that recquires 200 as response code (ODM default is 301).

```
helm install <release> ibmcharts/ibm-odm-prod \
        --set image.repository=cp.icr.io/cp/cp4a/odm --set image.pullSecrets=<registrysecret> \
        --set externalCustomDatabase.datasourceRef=<customdatasourcesecret> --set externalCustomDatabase.driverPvc=customdatasource-pvc \
        --set service.enableTLS=false --set service.ingress.tlsSecretRef=<mycompanytlssecret> \
        --set service.ingress.enabled=true --set service.ingress.host=mycompany.com --set service.ingress.tlsHosts={"mycompany.com"} \
        --set service.ingress.annotations={"kubernetes.io/ingress.class: nginx"\,"nginx.ingress.kubernetes.io/backend-protocol: HTTPS"\,"nginx.ingress.kubernetes.io/affinity: cookie"} \
        --post-renderer ./kustomize
```

## Edit your /etc/hosts

```
# vi /etc/hosts
<externalip> mycompany.com
```

## Access the ODM services

Check that ODM services are in NodePort type:

```
kubectl get services
NAME                                               TYPE           CLUSTER-IP     EXTERNAL-IP    PORT(S)                      AGE
mycompany-odm-decisioncenter                       NodePort       10.0.178.43    <none>         9453:32720/TCP               16m
mycompany-odm-decisionrunner                       NodePort       10.0.171.46    <none>         9443:30223/TCP               16m
mycompany-odm-decisionserverconsole                NodePort       10.0.106.222   <none>         9443:30280/TCP               16m
mycompany-odm-decisionserverconsole-notif          ClusterIP      10.0.115.118   <none>         1883/TCP                     16m
mycompany-odm-decisionserverruntime                NodePort       10.0.232.212   <none>         9443:30082/TCP               16m
nginx-ingress-ingress-nginx-controller             LoadBalancer   10.0.191.246   51.103.3.254   80:30222/TCP,443:31103/TCP   3d
nginx-ingress-ingress-nginx-controller-admission   ClusterIP      10.0.214.250   <none>         443/TCP                      3d
```

ODM services are available through the following URLs:

| SERVICE NAME | URL | USERNAME/PASSWORD
| --- | --- | ---
| Decision Server Console | https://mycompany.com/res | odmAdmin/odmAdmin
| Decision Center | https://mycompany.com/decisioncenter | odmAdmin/odmAdmin
| Decision Server Runtime | https://mycompany.com/DecisionService | odmAdmin/odmAdmin
| Decision Runner | https://mycompany.com/DecisionRunner | odmAdmin/odmAdmin

## Troubleshooting

If your ODM instances are not running properly, please refer to [our dedicated troubleshooting page](https://www.ibm.com/docs/en/odm/8.11.0?topic=8110-troubleshooting-support).

# License

[Apache 2.0](../LICENSE)

