> [!WARNING]
> **NGINX Ingress Controller is DEPRECATED for GKE deployments.**
>
> Google Cloud now recommends using the **GKE Gateway API** (container-native load balancer) instead of NGINX Ingress Controller. The Gateway API provides better integration with Google Cloud services, improved performance, and native support for features like session affinity.
>
> **Please use the [GKE Gateway deployment guide](README_GATEWAY.md) instead of this NGINX-based approach.**
>
> This documentation is kept for reference purposes only for existing deployments and **will be removed in the coming months**.

---

# Install an ODM Helm release and expose it with a NGINX Ingress controller (15 min)

This section explains how to expose the ODM services to Internet connectivity with a NGINX Ingress controller instead of the standard Google Cloud load balancer.

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
> By default,NGINX does not enable stick y session. If you want to use sticky session to connect to DC, refer to [Using sticky session for Decision Center connection](../../contrib/sticky-session/README.md)

### Edit the file /etc/hosts on your host

```shell
# vi /etc/hosts
<externalip> mynicecompany.com
```

### Access the ODM services

Check that ODM services are in NodePort type:

```shell
kubectl get services --selector release=<release>
NAME                                             TYPE           CLUSTER-IP     EXTERNAL-IP    PORT(S)                      AGE
release-odm-decisioncenter                       NodePort       10.0.178.43    <none>         443:32720/TCP               16m
release-odm-decisionrunner                       NodePort       10.0.171.46    <none>         443:30223/TCP               16m
release-odm-decisionserverconsole                NodePort       10.0.106.222   <none>         443:30280/TCP               16m
release-odm-decisionserverconsole-notif          ClusterIP      10.0.115.118   <none>         1883/TCP                     16m
release-odm-decisionserverruntime                NodePort       10.0.232.212   <none>         443:30082/TCP               16m
```

The ODM services are available at the following URLs:

<!-- markdown-link-check-disable -->
| SERVICE NAME | URL | USERNAME/PASSWORD
| --- | --- | ---
| Decision Server Console | https://mynicecompany.com/res | odmAdmin/\<password\>
| Decision Center | https://mynicecompany.com/decisioncenter | odmAdmin/\<password\>
| Decision Server Runtime | https://mynicecompany.com/DecisionService | odmAdmin/\<password\>
| Decision Runner | https://mynicecompany.com/DecisionRunner | odmAdmin/\<password\>
<!-- markdown-link-check-enable -->

Where:

* \<password\> is the password set using the **usersPassword** helm chart parameter




## Track ODM usage

### Install the IBM Usage Metering service

IBM Usage Metering Service gathers metrics to monitor compliance and create reports. It captures business value metrics for auditing purposes and to visualize metric usage in reporting tools, and sends the information to IBM Software Central.

From ODM 9.6.0 onwards, it is required to install this metering service in the same namespace as ODM. ODM will systematically reports usage metrics to the metering service through a CronJob. If the service is not installed, the job fails when it runs. For more information about the installation and configuration of UMS, see [Installing the usage metering service](https://www.ibm.com/docs/en/odm/9.6.0?topic=production-installing-metering).


### Retrieve metering usage

expose the metering service:
```shell
kubectl apply -f usage-metering-service-NGINX.yaml 
```


To get the Usage Metering report, run the command below:

```bash
UMS_TOKEN=$(kubectl get secret ibm-usage-metering-upload-token -n "${NAMESPACE}" -o jsonpath='{.data.token}' 2>/dev/null | base64 -d || echo "")

curl -k --output report.zip \
        --header "Authorization: Bearer ${UMS_TOKEN}" \
        --url "https://mynicecompany.com/ibm-usage-metering-instance/api/v1/snapshot"
```

### Install the IBM License Service and retrieve license usage

This section explains how to track ODM usage with the IBM License Service.

Follow the instructions in the **Installation** section of the [Manual installation without the Operator Lifecycle Manager (OLM)](https://www.ibm.com/docs/en/cloud-paks/foundational-services/4.14.0?topic=ilsfpcr-installing-license-service-without-operator-lifecycle-manager-olm#installation) documentation, **except for the step 3** which should be replaced by:

> 3. Use `git clone`.
>
>```bash
>export operator_release_version=4.2.20
>git clone -b ${operator_release_version} https://github.com/IBM/ibm-licensing-operator.git
>cd ibm-licensing-operator/
>```

### Patch the IBM Licensing instance with Nginx configuration

Get the [licensing-instance-nginx.yaml](./licensing-instance-nginx.yaml) file and run the command:

```bash
kubectl patch IBMLicensing instance --type merge --patch-file licensing-instance-nginx.yaml -n ibm-licensing
```

Wait a couple of minutes for the changes to be applied. 

Run the following command to see the status of Ingress instance:

```bash
kubectl get ingress -n ibm-licensing
```

You should be able to see the address and other details about `ibm-licensing-service-instance`.
```
NAME                             CLASS   HOSTS   ADDRESS             PORTS   AGE
ibm-licensing-service-instance   nginx   *       xxx.xxx.xxx.xxx     80      11m
```

You will be able to access the IBM License Service by retrieving the URL with this command:

```bash
export LICENSING_URL=$(kubectl get ingress ibm-licensing-service-instance -n ibm-licensing -o jsonpath='{.status.loadBalancer.ingress[0].ip}')/ibm-licensing-service-instance
export TOKEN=$(kubectl get secret ibm-licensing-token -n ibm-licensing -o jsonpath='{.data.token}' |base64 -d)
echo "http://${LICENSING_URL}/status?token=${TOKEN}"
```

You can access the `http://${LICENSING_URL}/status?token=${TOKEN}` URL to view the licensing usage. 

Alternatively you can retrieve the licensing `report.zip` file by running:

```bash
curl "http://${LICENSING_URL}/snapshot?token=${TOKEN}" --output report.zip
```

If your IBM License Service instance is not running properly, refer to this [troubleshooting page](https://www.ibm.com/docs/en/cloud-paks/foundational-services/4.14.0?topic=service-troubleshooting-license).

## Troubleshooting

If your ODM instances are not running properly, please refer to [our dedicated troubleshooting page](https://www.ibm.com/docs/en/odm/9.6.0?topic=950-troubleshooting-support).

## License

[Apache 2.0](/LICENSE)
