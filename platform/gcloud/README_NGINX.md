# Install an ODM Helm release and expose it with a NGINX Ingress controller (15 min)

This section explains how to expose the ODM services to Internet connectivity with a NGINX Ingress controller instead of the standard Google Cloud load balancer.

For reference, see the Google Cloud documentation https://cloud.google.com/community/tutorials/nginx-ingress-gke

## Table of Contents

<!-- TOC -->

- [Create a NGINX Ingress controller](#create-a-nginx-ingress-controller)
- [Install the ODM release](#install-the-odm-release)
- [Check the deployment and access ODM services](#check-the-deployment-and-access-odm-services)
- [Deploy and check IBM Licensing Service](#deploy-and-check-ibm-licensing-service)

<!-- /TOC -->

### Create a NGINX Ingress controller

- Use Helm to deploy the NGINX Ingress controller:

  ```shell
  helm upgrade --install ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx --namespace ingress-nginx --create-namespace
  ```

### Install the ODM release

You can install the product using the dedicated Ingress annotation `kubernetes.io/ingress.class: nginx`.

The ODM services will be exposed through NGINX.
The secured HTTPS communication is managed by the NGINX ingress controller. So, we disable TLS at container level.

Replace the placeholders in the [gcp-values.yaml](./gcp-values.yaml) file and install the chart:

```shell
helm install mycompany ibm-helm/ibm-odm-prod -f gcp-values.yaml \
    --set service.ingress.class=nginx
```

> **Note**
> By default, NGINX does not enable sticky session. If you want to use sticky session to connect to DC, refer to [Using sticky session for Decision Center connection](../../contrib/sticky-session/README.md)

### Check the deployment and access ODM services

Refer to the [the main README](README.md#b-check-the-topology) to check the deployment and access the ODM services.

### Deploy and check IBM Licensing Service

Refer to [the main README](README.md#b-check-the-topology) to install IBM Licensing Service, except that you have to apply this updated IBMLicensing instance instead:

```shell
kubectl apply -f licensing-instance-NGINX.yaml -n ibm-licensing
```

## Troubleshooting

If your ODM instances are not running properly, please refer to [our dedicated troubleshooting page](https://www.ibm.com/docs/en/odm/9.5.0?topic=950-troubleshooting-support).

## License

[Apache 2.0](/LICENSE)
