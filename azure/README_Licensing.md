# Install an ODM Helm release and expose it with a NGINX Ingress controller (15 min)

This section explains how to track ODM usage with the IBM License Service.

<!-- TOC titleSize:2 tabSpaces:2 depthFrom:1 depthTo:6 withLinks:1 updateOnSave:1 orderedList:0 skip:0 title:1 charForUnorderedList:* -->
## Table of Contents
* [Install an ODM Helm release and expose it with a NGINX Ingress controller (15 min)](#install-an-odm-helm-release-and-expose-it-with-a-nginx-ingress-controller-15-min)
  * [Install the IBM License Service](#install-the-ibm-license-service)
  * [Retrieving license usage](#retrieving-license-usage)
  * [Troubleshooting](#troubleshooting)
* [License](#license)
<!-- /TOC -->

## Install the IBM License Service

Follow the **Installation** section of the [Manual installation without the Operator Lifecycle Manager (OLM)](https://github.com/IBM/ibm-licensing-operator/blob/latest/docs/Content/Install_without_OLM.md)

> Note: The instance created in the documentation is configured to use NGINX as it has been installed in the [previous steps](README_NGINX.md).

## Retrieving license usage

After a couple of minutes, the NGINX load balancer reflects the Ingress configuration and you will be able to access the IBM License Service by retrieving the URL with this command:

```
export LICENSING_URL=$(kubectl get ingress ibm-licensing-service-instance -n ibm-common-services |awk '{print $4}' |tail -1)
export TOKEN=$(oc get secret ibm-licensing-token -o jsonpath={.data.token} -n ibm-common-services |base64 -d)
```

You can access the `http://${LICENSING_URL}/status?token=${TOKEN}` URL to view the licensing usage or retrieve the licensing report zip file by running:
```
curl -v http://${LICENSING_URL}/snapshot?token=${TOKEN} --output report.zip
```

## Troubleshooting

If your ODM instances are not running properly, please refer to [our dedicated troubleshooting page](https://www.ibm.com/docs/en/odm/8.11.0?topic=8110-troubleshooting-support).

# License

[Apache 2.0](../LICENSE)
