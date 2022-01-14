# Install the IBM License Service and retrieve license usage

This section explains how to track ODM usage with the IBM License Service.

<!-- TOC titleSize:2 tabSpaces:2 depthFrom:1 depthTo:6 withLinks:1 updateOnSave:1 orderedList:0 skip:0 title:1 charForUnorderedList:* -->
## Table of Contents
* [Install the IBM License Service and retrieve license usage](#install-the-ibm-license-service-and-retrieve-license-usage)
  * [Install the IBM License Service](#install-the-ibm-license-service)
  * [Create the Licensing instance](#create-the-licensing-instance)
  * [Retrieving license usage](#retrieving-license-usage)
  * [Troubleshooting](#troubleshooting)
* [License](#license)
<!-- /TOC -->

## Install the IBM License Service

Follow the **Installation** section of the [Manual installation without the Operator Lifecycle Manager (OLM)](https://github.com/IBM/ibm-licensing-operator/blob/latest/docs/Content/Install_without_OLM.md), make sure you don't follow the instantiation part!

## Create the Licensing instance

Just run:

```
kubectl create -f licensing-instance.yml
```

(More information and use cases on [this page](https://github.com/IBM/ibm-licensing-operator/blob/latest/docs/Content/Configuration.md#configuring-ingress).)

## Retrieving license usage

After a couple of minutes, the NGINX load balancer reflects the Ingress configuration and you will be able to access the IBM License Service by retrieving the URL with this command:

```
export LICENSING_URL=$(kubectl get ingress ibm-licensing-service-instance -n ibm-common-services |awk '{print $4}' |tail -1)/ibm-licensing-service-instance
export TOKEN=$(oc get secret ibm-licensing-token -o jsonpath={.data.token} -n ibm-common-services |base64 -d)
```

You can access the `http://${LICENSING_URL}/status?token=${TOKEN}` URL to view the licensing usage or retrieve the licensing report zip file by running:
```
curl -v "http://${LICENSING_URL}/snapshot?token=${TOKEN}" --output report.zip
```

## Troubleshooting

If your IBM License Service instance is not running properly, please refer to [our dedicated troubleshooting page](https://github.com/IBM/ibm-licensing-operator/blob/latest/docs/Content/Troubleshooting.md).

# License

[Apache 2.0](../LICENSE)
