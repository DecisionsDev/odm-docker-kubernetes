# Install an ODM Helm release and expose it with a NGINX Ingress controller (15 min)

This section explains how to expose the ODM services to Internet connectivity with a NGINX Ingress controller instead of the standard Google Cloud load balancer.

For reference, see the Google Cloud documentation https://cloud.google.com/community/tutorials/nginx-ingress-gke

## Table of Contents

1. [Create a NGINX Ingress controller](#1-create-a-nginx-ingress-controller)
2. [Install the ODM release](#2-install-the-odm-release)
3. [Check the deployment and access ODM services](#3-check-the-deployment-and-access-odm-services)

### 1. Create a NGINX Ingress controller

Refer to the [Create a NGINX Ingress controller](README.md#a-create-a-nginx-ingress-controller) section if you have not created it already.

### 2. Install the ODM release

You can install the product using the dedicated Ingress annotation `kubernetes.io/ingress.class: nginx`.

The ODM services will be exposed through NGINX.
The secured HTTPS communication is managed by the NGINX ingress controller. So, we disable TLS at container level.

Replace the placeholders in the [gcp-values.yaml](./gcp-values.yaml) file and install the chart:

```
helm install mycompany ibmcharts/ibm-odm-prod --version 22.2.0 \
    -f gcp-values.yaml \
    --set service.ingress.annotations={"kubernetes.io/ingress.class: nginx"}
```

### 3. Check the deployment and access ODM services

Refer to the [the main README](README.md#b-check-the-topology) to check the deployment and access the ODM services.

## Troubleshooting

If your ODM instances are not running properly, please refer to [our dedicated troubleshooting page](https://www.ibm.com/docs/en/odm/8.11.0?topic=8110-troubleshooting-support).

# License

[Apache 2.0](../LICENSE)
