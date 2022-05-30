# Install an ODM Helm release and expose it with a NGINX Ingress controller (15 min)

This section explains how to expose the ODM services to Internet connectivity with Ingress.
For reference, see the Google Cloud documentation https://cloud.google.com/community/tutorials/nginx-ingress-gke

## Table of Contents

1. [Create a NGINX Ingress controller](#1-create-a-nginx-ingress-controller)
2. [Install the ODM release](#2-install-the-odm-release)
3. [Edit your /etc/hosts](#3-edit-your-etchosts)
4. [Access the ODM services](#4-access-the-odm-services)

### 1. Create a NGINX Ingress controller

An NGINX Ingress controller need to be installed while to access the IBM License Manager. Refer to the [Create a NGINX Ingress controller](README.md#b-create-a-nginx-ingress-controller) section if you have not created it already.

### 2. Install the ODM release

You can install the product using the dedicated Ingress annotation `kubernetes.io/ingress.class: nginx`.

The ODM services will be exposed through NGINX.
The secured HTTPS communication is managed by the NGINX ingress controller. So, we disable TLS at container level.

Replace the placeholders in the [gcp-values-nginx.yaml](./gcp-values-nginx.yaml) file and install the chart:

```
helm install mycompany ibmcharts/ibm-odm-prod --version 22.1.0 \
             -f gcp-values-nginx.yaml
```

## Access the ODM services

- Check that ODM services are in *NodePort* type:

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

- Get the EXTERNAL-IP using the command line:

  ```
  kubectl get ingress <release>-odm-ingress -o jsonpath='{.status.loadBalancer.ingress[].ip}'
  ```

- Edit your /etc/hosts

  ```
  # vi /etc/hosts
  <externalip> mycompany.com
  ```

- ODM services are available through the following URLs:

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
