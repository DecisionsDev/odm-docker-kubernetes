# Install an ODM Helm release and expose it with a NGINX Ingress controller (15 min)

This section explains how to expose the ODM services to Internet connectivity with a NGINX Ingress controller instead of the standard Google Cloud load balancer.

For reference, see the Google Cloud documentation https://cloud.google.com/community/tutorials/nginx-ingress-gke

## Table of Contents

- [Install an ODM Helm release and expose it with a NGINX Ingress controller (15 min)](#install-an-odm-helm-release-and-expose-it-with-a-nginx-ingress-controller-15-min)
  - [Table of Contents](#table-of-contents)
    - [1. Create a NGINX Ingress controller](#1-create-a-nginx-ingress-controller)
    - [2. Install the ODM release](#2-install-the-odm-release)
    - [3. Check the deployment and access ODM services](#3-check-the-deployment-and-access-odm-services)
  - [Troubleshooting](#troubleshooting)
- [License](#license)

### 1. Create a NGINX Ingress controller

- Use Helm to deploy the NGINX Ingress controller:

  ```shell
  helm upgrade --install ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx --namespace ingress-nginx --create-namespace
  ```

### 2. Install the ODM release

You can install the product using the dedicated Ingress annotation `kubernetes.io/ingress.class: nginx`.

The ODM services will be exposed through NGINX.
The secured HTTPS communication is managed by the NGINX ingress controller. So, we disable TLS at container level.

Replace the placeholders in the [gcp-values.yaml](./gcp-values.yaml) file and install the chart:

```shell
helm install mycompany ibm-helm/ibm-odm-prod --version 24.1.0 \
    -f gcp-values.yaml \
    --set service.ingress.class=nginx
```

> **Note**
> By default, NGINX does not enable sticky session. If you want to use sticky session to connect to DC, refer to [Using sticky session for Decision Center connection](../../contrib/sticky-session/README.md)

### 3. Check the deployment and access ODM services

Refer to the [the main README](README.md#b-check-the-topology) to check the deployment and access the ODM services.

### 4. Deploy and check IBM Licensing Service

Refer to [the main README](README.md#b-check-the-topology) to install IBM Licensing Service, except that you have to apply this updated IBMLicensing instance instead:

```shell
kubectl apply -f licensing-instance-NGINX.yaml -n ibm-licensing
```

## Troubleshooting

If your ODM instances are not running properly, please refer to [our dedicated troubleshooting page](https://www.ibm.com/docs/en/odm/9.0.0?topic=900-troubleshooting-support).

## License

[Apache 2.0](/LICENSE)
