# Deploying IBM Operational Decision Manager with NGINX Ingress Controller on Azure AKS

The aim of this complementary documentation is to explain how to replace the **AKS default Load Balancer** usage with an **NGINX Ingress Controller**.

## Prerequisites

You must have created an AKS cluster and set up your environment by following steps :
- [Prepare your AKS instance 30 min](README.md#prepare-your-aks-instance-30-min)
- [Create the PostgreSQL Azure instance 10 min](README.md#create-the-postgresql-azure-instance-10-min)
- [Prepare your environment for the ODM installation](README.md#prepare-your-environment-for-the-odm-installation)

## Provision an NGINX Ingress Controller

Installing an NGINX Ingress controller allows you to access ODM components through a single external IP address instead of the different IP addresses as seen above.  It is also mandatory to retrieve license usage through the IBM License Service.

1. Use the official YAML manifest:

    ```shell
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/cloud/deploy.yaml
    ```

> [!NOTE]
> The version will probably change after the publication of our documentation, so please refer to the actual [documentation](https://kubernetes.github.io/ingress-nginx/deploy/#azure).

2. Get the Ingress controller external IP address (it will appear 80 seconds or so after the resource application above):

    ```shell
    kubectl get service --selector app.kubernetes.io/name=ingress-nginx --namespace ingress-nginx
    NAME                                 TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)                      AGE
    ingress-nginx-controller             LoadBalancer   10.0.78.246    20.19.105.130   80:32208/TCP,443:30249/TCP   2m12s
    ingress-nginx-controller-admission   ClusterIP      10.0.229.164   <none>          443/TCP                      2m12s
    ```

3. Verify the name of the new IngressClass:

    ```shell
    kubectl get ingressclass
    NAME    CONTROLLER             PARAMETERS   AGE
    nginx   k8s.io/ingress-nginx   <none>       5h38m
    ```

    The name should be `nginx`. If it is different please replace `nginx` with the actual class name in the value of the parameter `service.ingress.class` in [aks-nginx-values.yaml](./aks-nginx-values.yaml).

## Install an ODM release with NGINX Ingress Controller

You can reuse the secret with TLS certificate created at [Manage a digital certificate](README.md#manage-adigital-certificate-10-min). 

You can now install the product.
- Get the [aks-nginx-values.yaml](./aks-nginx-values.yaml) file and replace the following keys:
  - `<registrysecret>` is your registry secret name
  - `<postgresqlserver>` is your flexible postgres server name
  - `<odmdbsecret>` is the database credentials secret name
  - `<mynicecompanytlssecret>` is the container certificate
  - `<password>` is the password to login with the basic registry users like `odmAdmin`

```shell
helm install <release> ibm-helm/ibm-odm-prod -f aks-nginx-values.yaml
```

> [!NOTE]
> - By default, the NGINX Ingress controller does not enable sticky session. If you want to use sticky session to connect to DC, refer to [Using sticky session for Decision Center connection](../../contrib/sticky-session/README.md#configuring-ingress-to-use-sticky-sessions)
>
> - This command installs the **latest available version** of the chart. If you want to install a **specific version**, add the `--version` option:
>
> ```bash
> helm install <release> ibm-helm/ibm-odm-prod --version <version> -f aks-nginx-values.yaml
> ```
>
> - You can list all available versions using:
>
> ```bash
> helm search repo ibm-helm/ibm-odm-prod -l
> ```


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

ODM services are available through the following URLs:

<!-- markdown-link-check-disable -->
| SERVICE NAME | URL | USERNAME/PASSWORD
| --- | --- | ---
| Decision Server Console | https://mynicecompany.com/res | odmAdmin/\<password\>
| Decision Center | https://mynicecompany.com/decisioncenter | odmAdmin/\<password\>
| Decision Server Runtime | https://mynicecompany.com/DecisionService | odmAdmin/\<password\>
| Decision Runner | https://mynicecompany.com/DecisionRunner | odmAdmin/\<password\>
<!-- markdown-link-check-enable -->

Where:

* \<password\> is the password provided to the **usersPassword** helm chart parameter

## Track ODM usage

### Install the IBM Usage Metering service

IBM Usage Metering Service gathers metrics to monitor compliance and create reports. It captures business value metrics for auditing purposes and to visualize metric usage in reporting tools, and sends the information to IBM Software Central.

From ODM 9.6.0 onwards, it is required to install this metering service in the same namespace as ODM. ODM will systematically reports usage metrics to the metering service through a CronJob. If the service is not installed, the job fails when it runs. For more information about the installation and configuration of UMS, see [Installing the usage metering service](https://www.ibm.com/docs/en/odm/9.6.0?topic=production-installing-metering).

### Install the IBM License Service and retrieve license usage

This section explains how to track ODM usage with the IBM License Service.

Follow the instructions in the **Installation** section of the [Manual installation without the Operator Lifecycle Manager (OLM)](https://www.ibm.com/docs/en/cloud-paks/foundational-services/4.14.0?topic=ilsfpcr-installing-license-service-without-operator-lifecycle-manager-olm#installation) documentation, **except for the step 3** which should be replaced by:

> 3. Use `git clone`.
>
>```bash
>export operator_release_version=4.2.20
git clone -b ${operator_release_version} https://github.com/IBM/ibm-licensing-operator.git
cd ibm-licensing-operator/
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

If your ODM instances are not running properly, refer to [our dedicated troubleshooting page](https://www.ibm.com/docs/en/odm/9.6.0?topic=960-troubleshooting-support).

## Getting Started with IBM Operational Decision Manager for Containers

Get hands-on experience with IBM Operational Decision Manager in a container environment by following this [Getting started tutorial](https://github.com/DecisionsDev/odm-for-container-getting-started/blob/master/README.md).

# License

[Apache 2.0](/LICENSE)
