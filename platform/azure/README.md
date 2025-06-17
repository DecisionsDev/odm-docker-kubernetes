# Deploying IBM Operational Decision Manager on Azure AKS

This project demonstrates how to deploy an IBM® Operational Decision Manager (ODM) clustered topology on the Azure Kubernetes Service (AKS) cloud service. This deployment implements Kubernetes and Docker technologies.
Here is the home page of Microsoft Azure: https://portal.azure.com/#home

![AKS schema](images/aks-schema.png)

The ODM on Kubernetes Docker images are available in the [IBM Entitled Registry](https://www.ibm.com/cloud/container-registry). The ODM Helm chart is available in the [IBM Helm charts repository](https://github.com/IBM/charts).

## Included components

The project comes with the following components:

- [IBM Operational Decision Manager](https://www.ibm.com/docs/en/odm/9.5.0)
- [Azure Database for PostgreSQL](https://docs.microsoft.com/en-us/azure/postgresql/)
- [Azure Kubernetes Service (AKS)](https://docs.microsoft.com/en-us/azure/aks/)
- [Network concepts for applications in AKS](https://docs.microsoft.com/en-us/azure/aks/concepts-network)
- [IBM License Service](https://github.com/IBM/ibm-licensing-operator)

## Tested environment
The commands and tools have been tested on macOS and Linux.

## Prerequisites
First, install the following software on your machine:

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
- [Helm v3](https://helm.sh/docs/intro/install/)

Then, [create an Azure account and pay as you go](https://azure.microsoft.com/en-us/pricing/purchase-options/pay-as-you-go/).

> [!NOTE]
> Prerequisites and software supported by ODM 9.5.0 are listed in [the Detailed System Requirements page](https://www.ibm.com/support/pages/ibm-operational-decision-manager-detailed-system-requirements).

## Steps to deploy ODM on Kubernetes to Azure AKS
<!-- TOC depthfrom:2 depthto:2 -->

- [Included components](#included-components)
- [Tested environment](#tested-environment)
- [Prerequisites](#prerequisites)
- [Steps to deploy ODM on Kubernetes to Azure AKS](#steps-to-deploy-odm-on-kubernetes-to-azure-aks)
- [Prepare your AKS instance 30 min](#prepare-your-aks-instance-30-min)
- [Create the PostgreSQL Azure instance 10 min](#create-the-postgresql-azure-instance-10-min)
- [Prepare your environment for the ODM installation](#prepare-your-environment-for-the-odm-installation)
- [Install an ODM Helm release and expose it with the service type LoadBalancer 10 min](#install-an-odm-helm-release-and-expose-it-with-the-service-type-loadbalancer-10-min)
- [Install the IBM License Service and retrieve license usage](#install-the-ibm-license-service-and-retrieve-license-usage)
- [Troubleshooting](#troubleshooting)
- [Getting Started with IBM Operational Decision Manager for Containers](#getting-started-with-ibm-operational-decision-manager-for-containers)

<!-- /TOC -->

## Prepare your AKS instance (30 min)

Source: https://docs.microsoft.com/en-us/azure/aks/kubernetes-walkthrough

### Log into Azure

After installing the Azure CLI, use the following command line:

```shell
az login [--tenant <name>.onmicrosoft.com]
```

A web browser opens where you can connect with your Azure credentials.

### Create a resource group

An Azure resource group is a logical group in which Azure resources are deployed and managed. When you create a resource group, you will be prompted to specify a location. This location is where resource group metadata is stored. It is also where your resources run in Azure, if you do not specify another region during resource creation. 

To get a list of available locations, run:

```shell
az account list-locations -o table
```

Then, create a resource group by running the following command:

```shell
az group create --name <resourcegroup> --location <azurelocation> --tags Owner=<email> Team=<team> Usage=demo Usage_desc="Azure customers support" Delete_date=2025-12-31
```

The following example output shows that the resource group has been created successfully:

```json
{
  "id": "/subscriptions/<guid>/resourceGroups/<resourcegroup>",
  "location": "<azurelocation>",
  "managedBy": null,
  "name": "<resourcegroup>",
  "properties": {
    "provisioningState": "Succeeded"
  },
  "tags": {
    "Delete_date": "2025-12-31",
    "Owner": "<email>",
    "Team": "<team>",
    "Usage": "demo",
    "Usage_desc": "Azure customers support"
  },
  "type": "Microsoft.Resources/resourceGroups"
}
```

### Create an AKS cluster

Use the `az aks create` command to create an AKS cluster. The following example creates a cluster named <cluster> with two nodes. Azure Monitor for containers can also be enabled by using the `--enable-addons monitoring` parameter.  The operation takes several minutes to complete.

```shell
az aks create --name <cluster> --resource-group <resourcegroup> --node-count 2 \
          --enable-cluster-autoscaler --min-count 2 --max-count 4 --generate-ssh-keys
```
> [!NOTE]
> During the creation of the AKS cluster, a second resource group is automatically created to store the AKS resources. For more information, see [Why are two resource groups created with AKS](https://docs.microsoft.com/en-us/azure/aks/faq#why-are-two-resource-groups-created-with-aks).

After a few minutes, the command completes and returns JSON-formatted information about the cluster.  

Make a note of the newly-created Resource Group that is displayed in the JSON output (e.g. `"nodeResourceGroup": "<noderesourcegroup>"`). You can update the resource with additional tags. For example:

```shell
az group update --name <noderesourcegroup> \
    --tags Owner=<email> Team=<team> Usage=demo Usage_desc="Azure customers support" Delete_date=2025-12-31
```
       
### Set up your environment to this cluster

To manage a Kubernetes cluster, you will need to use `kubectl`, the Kubernetes command-line client. If you use `Azure Cloud Shell`, kubectl is already installed. Otherwise, to use `kubectl` locally, run the the following command to install the client:

```shell
az aks install-cli
```

To configure kubectl to connect to your Kubernetes cluster, use the `az aks get-credentials` command. This command downloads credentials and configures the Kubernetes CLI to use them.

```shell
az aks get-credentials --name <cluster> --resource-group <resourcegroup>
```

To verify the connection to your cluster, use the `kubectl get` command to return the list of cluster nodes.

```shell
kubectl get nodes
```

The following example output shows the single node created in the previous steps. Make sure that the status of the node is Ready.

```
NAME                                STATUS   ROLES   AGE   VERSION
aks-nodepool1-27504729-vmss000000   Ready    agent   21m   v1.31.7
aks-nodepool1-27504729-vmss000001   Ready    agent   21m   v1.31.7
```

## Create the PostgreSQL Azure instance (10 min)

### Create an Azure Database for PostgreSQL

Create an Azure Database for PostgreSQL flexible server by running the `az postgres flexible-server create` command. A server can contain multiple databases.
To get a good bandwidth between ODM containers and the database, choose the same location for the PostgreSQL server and for the AKS cluster.

```shell
az postgres flexible-server create --name <postgresqlserver> --resource-group <resourcegroup> \
                          --admin-user myadmin --admin-password 'passw0rd!' \
                          --sku-name Standard_D2s_v3 --version 15
```

> [!NOTE]
> The PostgreSQL server name must be unique within Azure.

Verify the database.
To connect to your server, you need to provide host information and access credentials.

```shell
az postgres flexible-server show --name <postgresqlserver> --resource-group <resourcegroup>
```

Result:

```json
{
  "administratorLogin": "myadmin",
  "administratorLoginPassword": null,
  "authConfig": {
    "activeDirectoryAuth": "Disabled",
    "passwordAuth": "Enabled",
    "tenantId": null
  },
  "availabilityZone": "2",
  "backup": {
    "backupRetentionDays": 7,
    "earliestRestoreDate": "2025-04-29T09:37:34.208183+00:00",
    "geoRedundantBackup": "Disabled"
  },
  "cluster": null,
  "createMode": null,
  "dataEncryption": {
    "geoBackupEncryptionKeyStatus": null,
    "geoBackupKeyUri": null,
    "geoBackupUserAssignedIdentityId": null,
    "primaryEncryptionKeyStatus": null,
    "primaryKeyUri": null,
    "primaryUserAssignedIdentityId": null,
    "type": "SystemManaged"
  },
  "fullyQualifiedDomainName": "<postgresqlserver>.postgres.database.azure.com",
  "highAvailability": {
    "mode": "Disabled",
    "standbyAvailabilityZone": null,
    "state": "NotEnabled"
  },
  "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-cb6e4a84fda1/resourceGroups/<resourcegroup>/providers/Microsoft.DBforPostgreSQL/flexibleServers/<postgresqlserver>",
  "identity": null,
  "location": "<azurelocation>",
  "maintenanceWindow": {
    "customWindow": "Disabled",
    "dayOfWeek": 0,
    "startHour": 0,
    "startMinute": 0
  },
  "minorVersion": "12",
  "name": "<postgresqlserver>",
  "network": {
    "delegatedSubnetResourceId": null,
    "privateDnsZoneArmResourceId": null,
    "publicNetworkAccess": "Enabled"
  },
  "pointInTimeUtc": null,
  "privateEndpointConnections": [],
  "replica": {
    "capacity": 5,
    "promoteMode": null,
    "promoteOption": null,
    "replicationState": null,
    "role": "Primary"
  },
  "replicaCapacity": 5,
  "replicationRole": "Primary",
  "resourceGroup": "<resourcegroup>",
  "sku": {
    "name": "Standard_D2s_v3",
    "tier": "GeneralPurpose"
  },
  "sourceServerResourceId": null,
  "state": "Ready",
  "storage": {
    "autoGrow": "Disabled",
    "iops": 500,
    "storageSizeGb": 128,
    "throughput": null,
    "tier": "P10",
    "type": ""
  },
  "systemData": {
    "createdAt": "2025-04-29T09:31:58.093917+00:00",
    "createdBy": null,
    "createdByType": null,
    "lastModifiedAt": null,
    "lastModifiedBy": null,
    "lastModifiedByType": null
  },
  "tags": null,
  "type": "Microsoft.DBforPostgreSQL/flexibleServers",
  "version": "15"
}
```

Make a note of the server name that is displayed in the JSON output (e.g. `"fullyQualifiedDomainName": "<postgresqlserver>.postgres.database.azure.com"`) as it will be used later to deploy ODM with `helm install`.

###  Create a firewall rule that allows access from Azure services

To make sure your database and your AKS cluster can communicate, put in place firewall rules with the following command:

```shell
az postgres flexible-server firewall-rule create --resource-group <resourcegroup> --name <postgresqlserver> \
            --rule-name <rule-name> --start-ip-address 0.0.0.0 --end-ip-address 255.255.255.255
```

### Create the database credentials secret for Azure PostgreSQL

To secure the access to the database, create a secret that encrypts the database user and password before you install the Helm release.

```shell
kubectl create secret generic <odmdbsecret> --from-literal=db-user=myadmin \
                                            --from-literal=db-password='passw0rd!'
```

## Prepare your environment for the ODM installation

To get access to the ODM material, you must have an IBM entitlement key to pull the images from the IBM Entitled Registry.

### Using the IBM Entitled Registry with your IBMid (10 min)

Log in to [MyIBM Container Software Library](https://myibm.ibm.com/products-services/containerlibrary) with the IBMid and password that are associated with the entitled software.

In the Container software library tile, verify your entitlement on the View library page, and then go to Get entitlement key to retrieve the key.

Create a pull secret by running the `kubectl create secret` command.

```shell
$ kubectl create secret docker-registry <registrysecret> --docker-server=cp.icr.io \
                                                         --docker-username=cp \
                                                         --docker-password="<entitlementkey>" \
                                                         --docker-email=<email>
```
Where:

* \<registrysecret\> is the secret name
* \<entitlementkey\> is the entitlement key from the previous step. Make sure you enclose the key in double-quotes.
* \<email\> is the email address associated with your IBMid.

> [!NOTE]
> The `cp.icr.io` value for the `docker-server` parameter is the only registry domain name that contains the images. You must set the `docker-username` to `cp` to use an entitlement key as docker-password.

Make a note of the secret name so that you can set it for the `image.pullSecrets` parameter when you run a helm install of your containers.  The `image.repository` parameter should be set to `cp.icr.io/cp/cp4a/odm`.


Add the public IBM Helm charts repository:

```shell
helm repo add ibm-helm https://raw.githubusercontent.com/IBM/charts/master/repo/ibm-helm
helm repo update
```

Check that you can access the ODM charts:

```shell
helm search repo ibm-odm-prod
NAME                        CHART VERSION	APP VERSION DESCRIPTION
ibm-helm/ibm-odm-prod       25.0.0       	9.5.0.0     IBM Operational Decision Manager  License By in...
```

### Manage a digital certificate (10 min)

1. (Optional) Generate a self-signed certificate.

If you do not have a trusted certificate, you can use OpenSSL and other cryptography and certificate management libraries to generate a certificate file and a private key, to define the domain name, and to set the expiration date. The following command creates a self-signed certificate (.crt file) and a private key (.key file) that accept the domain name *mynicecompany.com*. The expiration is set to 1000 days:

```shell
openssl req -x509 -nodes -days 1000 -newkey rsa:2048 -keyout mynicecompany.key \
        -out mynicecompany.crt -subj "/CN=mynicecompany.com/OU=it/O=mynicecompany/L=Paris/C=FR" \
        -addext "subjectAltName = DNS:mynicecompany.com"
```

> [!NOTE]
> You can use -addext only with actual OpenSSL and from LibreSSL 3.1.0.

2. Create a Kubernetes secret with the certificate.

```shell
kubectl create secret generic <mynicecompanytlssecret> --from-file=tls.crt=mynicecompany.crt --from-file=tls.key=mynicecompany.key
```

The certificate must be the same as the one you used to enable TLS connections in your ODM release. For more information, see [Server certificates](https://www.ibm.com/docs/en/odm/9.5.0?topic=servers-server-certificates).

## Install an ODM Helm release and expose it with the service type LoadBalancer (10 min)

### Allocate public IP addresses

```shell
az aks update --name <cluster> --resource-group <resourcegroup> --load-balancer-managed-outbound-ip-count 4
```

### Install the ODM release

> **Note**
> If you prefer to use the NGINX Ingress Controller instead of the default AKS Load Balancer, refer to [Deploying IBM Operational Decision Manager with NGINX Ingress Controller on Azure AKS](README-NGINX.md)

You can now install the product.
- Get the [aks-values.yaml](./aks-values.yaml) file and replace the following keys:
  - `<registrysecret>` is your registry secret name
  - `<postgresqlserver>` is your flexible postgres server name
  - `<odmdbsecret>` is the database credentials secret name
  - `<mynicecompanytlssecret>` is the container certificate
  - `<password>` is the password to login with the basic registry users like `odmAdmin`  

```shell
helm install <release> ibm-helm/ibm-odm-prod -f aks-values.yaml
```

Where:
* \<password\> is the password that will be used for standard users odmAdmin, resAdmin, and rtsAdmin.

> **Note:**  
> The above command installs the **latest available version** of the chart.  
> If you want to install a **specific version**, add the `--version` option:
>
> ```bash
> helm install <release> ibm-helm/ibm-odm-prod --version <version> -f aks-values.yaml
> ```
>
> You can list all available versions using:
>
> ```bash
> helm search repo ibm-helm/ibm-odm-prod -l
> ```

### Check the topology

Run the following command to check the status of the pods that have been created:

```shell
kubectl get pods
NAME                                                   READY   STATUS    RESTARTS   AGE
<release>-odm-decisioncenter-***                       1/1     Running   0          20m
<release>-odm-decisionrunner-***                       1/1     Running   0          20m
<release>-odm-decisionserverconsole-***                1/1     Running   0          20m
<release>-odm-decisionserverruntime-***                1/1     Running   0          20m
```

### Access ODM services

By setting `service.type=LoadBalancer`, the services are exposed with public IPs to be accessed with the following command:

```shell
kubectl get services --selector release=<release>
NAME                                        TYPE           CLUSTER-IP     EXTERNAL-IP       PORT(S)          AGE
<release>-odm-decisioncenter                LoadBalancer   10.0.141.125   xxx.xxx.xxx.xxx   9453:31130/TCP   22m
<release>-odm-decisionrunner                LoadBalancer   10.0.157.225   xxx.xxx.xxx.xxx   9443:31325/TCP   22m
<release>-odm-decisionserverconsole         LoadBalancer   10.0.215.192   xxx.xxx.xxx.xxx   9443:32448/TCP   22m
<release>-odm-decisionserverconsole-notif   ClusterIP      10.0.201.87    <none>            1883/TCP         22m
<release>-odm-decisionserverruntime         LoadBalancer   10.0.177.153   xxx.xxx.xxx.xxx   9443:31921/TCP   22m
```

<!-- markdown-link-check-disable -->
You can then open a browser on `https://xxx.xxx.xxx.xxx:9453` to access Decision Center, and on `https://xxx.xxx.xxx.xxx:9443` to access Decision Server console, Decision Server Runtime, and Decision Runner.
<!-- markdown-link-check-enable -->

## Install the IBM License Service and retrieve license usage

This section explains how to track ODM usage with the IBM License Service.

Follow the **Installation** section of the [Installation License Service without Operator Lifecycle Manager (OLM)](https://www.ibm.com/docs/en/cloud-paks/foundational-services/4.12.0?topic=ilsfpcr-installing-license-service-without-operator-lifecycle-manager-olm) documentation.

#### a. Expose the licensing service using the AKS LoadBalancer

To expose the licensing service using the AKS LoadBalancer, run the command:

```bash
kubectl patch svc ibm-licensing-service-instance -p '{"spec": { "type": "LoadBalancer"}}' -n ibm-licensing
```

Wait a couple of minutes for the changes to be applied.
Then, you should see an EXTERNAL-IP available for the exposed licensing service.

```shell
kubectl get service -n ibm-licensing
NAME                                        TYPE           CLUSTER-IP     EXTERNAL-IP       PORT(S)          AGE
ibm-licensing-service-instance              LoadBalancer   10.0.58.142    xxx.xxx.xxx.xxx   8080:32301/TCP   10m
```

#### b. Patch the IBM Licensing instance

Get the [licensing-instance.yaml](./licensing-instance.yaml) file and run the command:

```bash
kubectl patch IBMLicensing instance --type merge --patch-file licensing-instance.yaml -n ibm-licensing 
```

Wait a couple of minutes for the changes to be applied. 

You can find more information and use cases on [this page](https://www.ibm.com/docs/en/cloud-paks/foundational-services/4.12.0?topic=configuring-kubernetes-ingress).

> **Note**
> If you choose to use the NGINX Ingress Controller, you must use the [licensing-instance-nginx.yaml](./licensing-instance-nginx.yaml) file. Refer to [Deploying IBM Operational Decision Manager with NGINX Ingress Controller on Azure AKS](README-NGINX.md#install-the-ibm-license-service-and-retrieve-license-usage).

### Retrieve license usage

You will be able to access the IBM License Service by retrieving the URL and the required token with this command:

```bash
export LICENSING_URL=$(kubectl get service ibm-licensing-service-instance -n ibm-licensing -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export TOKEN=$(kubectl get secret ibm-licensing-token -n ibm-licensing -o jsonpath='{.data.token}' |base64 -d)
```

> **Note**
> If `LICENSING_URL` is empty, take a look at the [troubleshooting](https://www.ibm.com/docs/en/cloud-paks/foundational-services/4.12.0?topic=service-troubleshooting-license) page.

You can access the `http://${LICENSING_URL}:8080/status?token=${TOKEN}` URL to view the licensing usage or retrieve the licensing report .zip file by running:

```shell
curl "http://${LICENSING_URL}:8080/snapshot?token=${TOKEN}" --output report.zip
```

If your IBM License Service instance is not running properly, refer to this [troubleshooting page](https://www.ibm.com/docs/en/cloud-paks/foundational-services/4.12.0?topic=service-troubleshooting-license).

## Troubleshooting

If your ODM instances are not running properly, refer to [our dedicated troubleshooting page](https://www.ibm.com/docs/en/odm/9.5.0?topic=950-troubleshooting-support).

## Getting Started with IBM Operational Decision Manager for Containers

Get hands-on experience with IBM Operational Decision Manager in a container environment by following this [Getting started tutorial](https://github.com/DecisionsDev/odm-for-container-getting-started/blob/master/README.md).

# License

[Apache 2.0](/LICENSE)
