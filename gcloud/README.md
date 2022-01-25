# Deploying IBM Operational Decision Manager on Google GKE

This project demonstrates how to deploy an IBM® Operational Decision Manager (ODM) clustered topology on the Google Kubernetes Engine (GKE) cloud service. This deployment implements Kubernetes and Docker technologies.
Here is the home page of Google Cloud: https://cloud.google.com

<img width="800" height="560" src='./images/aks-schema.jpg'/>

The ODM Docker material is available in Passport Advantage. It includes Docker container images and Helm chart descriptors.

## Included components

The project comes with the following components:

- [IBM Operational Decision Manager](https://www.ibm.com/docs/en/odm/8.11.0)
- [Google Cloud SQL for PostgreSQL](https://cloud.google.com/sql)
- [Google Kubernetes Engine (GKE)](https://cloud.google.com/kubernetes-engine)
- [IBM License Service](https://github.com/IBM/ibm-licensing-operator)

## Tested environment
The commands and tools have been tested on macOS and Linux.

## Prerequisites
First, install the following software on your machine:

* [gcloud tool](https://cloud.google.com/sdk/gcloud)
* [Helm v3](https://github.com/helm/helm/releases)

[create a google cloud account](https://cloud.google.com/apigee/docs/hybrid/v1.6/precog-gcpaccount)
[create a google cloud project](https://cloud.google.com/resource-manager/docs/creating-managing-projects)
[manage the associated billing](https://cloud.google.com/billing/docs/how-to/modify-project#confirm_billing_is_enabled_on_a_project).

Without the relevant billing level, some google cloud resources will not be created

> Note:  Prerequisites and software supported by ODM 8.11 are listed on [the Detailed System Requirements page](https://www.ibm.com/software/reports/compatibility/clarity-reports/report/html/softwareReqsForProduct?deliverableId=2D28A510507B11EBBBEA1195F7E6DF31&osPlatforms=AIX%7CLinux%7CMac%20OS%7CWindows&duComponentIds=D002%7CS003%7CS006%7CS005%7CC006&mandatoryCapIds=30%7C1%7C13%7C25%7C26&optionalCapIds=341%7C47%7C9%7C1%7C15).

## Steps to deploy ODM on Kubernetes from Google GKE

<!-- TOC titleSize:2 tabSpaces:2 depthFrom:1 depthTo:6 withLinks:1 updateOnSave:1 orderedList:0 skip:0 title:0 charForUnorderedList:* -->
* [Deploying IBM Operational Decision Manager on Google GKE](#deploying-ibm-operational-decision-manager-on-azure-aks)
  * [Included components](#included-components)
  * [Tested environment](#tested-environment)
  * [Prerequisites](#prerequisites)
  * [Steps to deploy ODM on Kubernetes from Google GKE](#steps-to-deploy-odm-on-kubernetes-from-azure-aks)
  * [Prepare your GKE instance (30 min)](#prepare-your-aks-instance-30-min)
    * [Log into Google Cloud](#log-into-gcloud)
    * [Create a GKE cluster](#create-a-gke-cluster)
    * [Set up your environment to this cluster](#set-up-your-environment-to-this-cluster)
  * [Create the PostgreSQL Azure instance (10 min)](#create-the-postgresql-azure-instance-10-min)
    * [Create an Azure Database for PostgreSQL](#create-an-azure-database-for-postgresql)
    * [Create a firewall rule that allows access from Azure services](#create-a-firewall-rule-that-allows-access-from-azure-services)
  * [Prepare your environment for the ODM installation](#prepare-your-environment-for-the-odm-installation)
    * [Using the IBM Entitled registry with your IBMid (10 min)](#using-the-ibm-entitled-registry-with-your-ibmid-10-min)
    * [Create the datasource secrets for Azure PostgreSQL](#create-the-datasource-secrets-for-azure-postgresql)
    * [Manage a digital certificate (10 min)](#manage-a-digital-certificate-10-min)
  * [Install an ODM Helm release and expose it with the service type LoadBalancer (10 min)](#install-an-odm-helm-release-and-expose-it-with-the-service-type-loadbalancer-10-min)
    * [Allocate public IP addresses](#allocate-public-ip-addresses)
    * [Install the ODM release](#install-the-odm-release)
    * [Check the topology](#check-the-topology)
    * [Access ODM services](#access-odm-services)
  * [Install the IBM License Service and retrieve license usage](#install-the-ibm-license-service-and-retrieve-license-usage)
    * [Create a NGINX Ingress controller](#create-a-nginx-ingress-controller)
    * [Install the IBM License Service](#install-the-ibm-license-service)
    * [Create the Licensing instance](#create-the-licensing-instance)
    * [Retrieving license usage](#retrieving-license-usage)
  * [Optional steps](#optional-steps)
  * [Troubleshooting](#troubleshooting)
* [License](#license)
<!-- /TOC -->

## Prepare your GKE instance (30 min)

Source: https://cloud.google.com/kubernetes-engine/docs/quickstart

### Log into Google Cloud

After installing the gcloud tool, use the following command line:

```
gcloud auth login [ACCOUNT]
```
https://cloud.google.com/sdk/gcloud/reference/auth/login

If your project is already created, you can also retrieve the gcloud 




### Create a GKE cluster

There is several [type of clusters](https://cloud.google.com/kubernetes-engine/docs/concepts/types-of-clusters)
We will choose to create a [regional cluster](https://cloud.google.com/kubernetes-engine/docs/how-to/creating-a-regional-cluster)

You can also create your cluster from the Google Cloud Platform using the Kubernetes Engine Clusters panel, by clicking on the Create button



       
### Set up your environment to this cluster

To manage a Kubernetes cluster, use kubectl, the Kubernetes command-line client.

When your cluster is created 


## Create the PostgreSQL Azure instance (10 min)

### Create an Azure Database for PostgreSQL

Create an Azure Database for PostgreSQL server by running the `az postgres server create` command. A server can contain multiple databases.

```
az postgres server create --name <postgresqlserver> --resource-group <resourcegroup> \
                          --admin-user myadmin --admin-password 'passw0rd!' \
                          --sku-name GP_Gen5_2 --version 11 [--location <azurelocation>]
```

> Note:  The PostgreSQL server name must be unique within Azure.

Verify the database.
To connect to your server, you need to provide host information and access credentials.

```
az postgres server show --name <postgresqlserver> --resource-group <resourcegroup>
```

Result:

```json
{
  "administratorLogin": "myadmin",
  "byokEnforcement": "Disabled",
  "earliestRestoreDate": "2022-01-06T09:15:54.563000+00:00",
  "fullyQualifiedDomainName": "<postgresqlserver>.postgres.database.azure.com",
  "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-5242e4507709/resourceGroups/<resourcegroup>/providers/Microsoft.DBforPostgreSQL/servers/<postgresqlserver>",
  "identity": null,
  "infrastructureEncryption": "Disabled",
  "location": "<azurelocation>",
  "masterServerId": "",
  "minimalTlsVersion": "TLSEnforcementDisabled",
  "name": "<postgresqlserver>",
  "privateEndpointConnections": [],
  "publicNetworkAccess": "Enabled",
  "replicaCapacity": 5,
  "replicationRole": "None",
  "resourceGroup": "<resourcegroup>",
  "sku": {
    "capacity": 2,
    "family": "Gen5",
    "name": "GP_Gen5_2",
    "size": null,
    "tier": "GeneralPurpose"
  },
  "sslEnforcement": "Enabled",
  "storageProfile": {
    "backupRetentionDays": 7,
    "geoRedundantBackup": "Disabled",
    "storageAutogrow": "Enabled",
    "storageMb": 51200
  },
  "tags": null,
  "type": "Microsoft.DBforPostgreSQL/servers",
  "userVisibleState": "Ready",
  "version": "11"
}
```

Make a note of the server name that is displayed in the JSON output (e.g.: "fullyQualifiedDomainName": "<postgresqlserver>.postgres.database.azure.com") as it will be used [later](#create-the-datasource-secrets-for-azure-postgresql).

###  Create a firewall rule that allows access from Azure services

To make sure your database and your AKS cluster can communicate, put in place firewall rules with the following command:

```
az postgres server firewall-rule create --resource-group <resourcegroup> --server-name <postgresqlserver> \
            --name <rulename> --start-ip-address 0.0.0.0 --end-ip-address 255.255.255.255
```

## Prepare your environment for the ODM installation

To get access to the ODM material, you must have an IBM entitlement registry key to pull the images from the IBM Entitled registry.

(If you prefer to install ODM from Azure Container Registry instead, you can a look at [this dedicated page](README_PPA.md).)

### Using the IBM Entitled registry with your IBMid (10 min)

Log in to [MyIBM Container Software Library](https://myibm.ibm.com/products-services/containerlibrary) with the IBMid and password that are associated with the entitled software.

In the Container software library tile, verify your entitlement on the View library page, and then go to Get entitlement key to retrieve the key.

Create a pull secret by running a kubectl create secret command.

```
$ kubectl create secret docker-registry <registrysecret> --docker-server=cp.icr.io \
                                                         --docker-username=cp \
                                                         --docker-password="<entitlementkey>" \
                                                         --docker-email=<email>
```

where:

* \<registrysecret\> is the secret name
* \<entitlementkey\> is the entitlement key from the previous step. Make sure you enclose the key in double-quotes.
* \<email\> is the email address associated with your IBMid.

> Note:  The cp.icr.io value for the docker-server parameter is the only registry domain name that contains the images. You must set the docker-username to cp to use an entitlement key as docker-password.

Make a note of the secret name so that you can set it for the image.pullSecrets parameter when you run a helm install of your containers.  The image.repository parameter will later be set to cp.icr.io/cp/cp4a/odm.

Add the public IBM Helm charts repository:

```
helm repo add ibmcharts https://raw.githubusercontent.com/IBM/charts/master/repo/entitled
helm repo update
```

Check you can access ODM's charts:

```
helm search repo ibm-odm-prod --versions                  
NAME                  	CHART VERSION	APP VERSION	DESCRIPTION                     
ibmcharts/ibm-odm-prod	21.3.0       	8.11.0.0   	IBM Operational Decision Manager
ibmcharts/ibm-odm-prod	21.2.0       	8.10.5.1   	IBM Operational Decision Manager
ibmcharts/ibm-odm-prod	21.1.0       	8.10.5.0   	IBM Operational Decision Manager
ibmcharts/ibm-odm-prod	20.3.0       	8.10.5.0   	IBM Operational Decision Manager
```

You can now proceed to the [datasource secret's creation](#create-the-datasource-secrets-for-azure-postgresql).

### Create the datasource secrets for Azure PostgreSQL

Copy the files [ds-bc.xml.template](ds-bc.xml.template) and [ds-res.xml.template](ds-res.xml.template) on your local machine and rename them to `ds-bc.xml` and `ds-res.xml`.

Replace the following placeholers:
- DBNAME: The database name
- USERNAME: The database username 
- PASSWORD: The database password
- SERVERNAME: The name of the database server

It should be something like in the following extract:

```xml
 <properties
  databaseName="postgres"
  user="myadmin@<postgresqlserver>"
  password="passw0rd!"
  portNumber="5432"
  sslMode="require"
  serverName="<postgresqlserver>.postgres.database.azure.com" />
```

Create a secret with this two modified files

```
kubectl create secret generic <customdatasourcesecret> \
        --from-file datasource-ds.xml=ds-res.xml --from-file datasource-dc.xml=ds-bc.xml
```

### Manage a digital certificate (10 min)

1. (Optional) Generate a self-signed certificate

If you do not have a trusted certificate, you can use OpenSSL and other cryptography and certificate management libraries to generate a certificate file and a private key, to define the domain name, and to set the expiration date. The following command creates a self-signed certificate (.crt file) and a private key (.key file) that accept the domain name *mycompany.com*. The expiration is set to 1000 days:

```
openssl req -x509 -nodes -days 1000 -newkey rsa:2048 -keyout mycompany.key \
        -out mycompany.crt -subj "/CN=mycompany.com/OU=it/O=mycompany/L=Paris/C=FR"
```

2. Generate a JKS version of the certificate to be used in the ODM container 

```
openssl pkcs12 -export -passout pass:password -passin pass:password \
      -inkey mycompany.key -in mycompany.crt -name mycompany -out mycompany.p12
keytool -importkeystore -srckeystore mycompany.p12 -srcstoretype PKCS12 \
      -srcstorepass password -destkeystore mycompany.jks \
      -deststoretype JKS -deststorepass password
keytool -import -v -trustcacerts -alias mycompany -file mycompany.crt \
      -keystore truststore.jks -storepass password -storetype jks -noprompt
```

3. Create a Kubernetes secret with the certificate

```
kubectl create secret generic <mycompanystore> --from-file=keystore.jks=mycompany.jks \
                                               --from-file=truststore.jks=truststore.jks \
                                               --from-literal=keystore_password=password \
                                               --from-literal=truststore_password=password
```

The certificate must be the same as the one you used to enable TLS connections in your ODM release. For more information, see [Server certificates](https://www.ibm.com/docs/en/odm/8.11.0?topic=servers-server-certificates) and [Working with certificates and SSL](https://docs.oracle.com/cd/E19830-01/819-4712/ablqw/index.html).

## Install an ODM Helm release and expose it with the service type LoadBalancer (10 min)

### Allocate public IP addresses

```
az aks update --name <cluster> --resource-group <resourcegroup> --load-balancer-managed-outbound-ip-count 4
```

### Install the ODM release

You can now install the product:

```
helm install <release> ibmcharts/ibm-odm-prod --version 21.3.0 \
        --set image.repository=cp.icr.io/cp/cp4a/odm --set image.pullSecrets=<registrysecret> \
        --set image.arch=amd64 --set image.tag=${ODM_VERSION:-8.11.0.0} --set service.type=LoadBalancer \
        --set externalCustomDatabase.datasourceRef=<customdatasourcesecret> \
        --set customization.securitySecretRef=<mycompanystore>
```

### Check the topology

Run the following command to check the status of the pods that have been created:

```
kubectl get pods
NAME                                                   READY   STATUS    RESTARTS   AGE
<release>-odm-decisioncenter-***                       1/1     Running   0          20m
<release>-odm-decisionrunner-***                       1/1     Running   0          20m
<release>-odm-decisionserverconsole-***                1/1     Running   0          20m
<release>-odm-decisionserverruntime-***                1/1     Running   0          20m
```

### Access ODM services

By setting `service.type=LoadBalancer`, the services are exposed with a public IP to be accessed with the following command:

```
kubectl get services
NAME                                        TYPE           CLUSTER-IP     EXTERNAL-IP       PORT(S)          AGE
kubernetes                                  ClusterIP      10.0.0.1       <none>            443/TCP          26h
<release>-odm-decisioncenter                LoadBalancer   10.0.141.125   xxx.xxx.xxx.xxx   9453:31130/TCP   22m
<release>-odm-decisionrunner                LoadBalancer   10.0.157.225   xxx.xxx.xxx.xxx   9443:31325/TCP   22m
<release>-odm-decisionserverconsole         LoadBalancer   10.0.215.192   xxx.xxx.xxx.xxx   9443:32448/TCP   22m
<release>-odm-decisionserverconsole-notif   ClusterIP      10.0.201.87    <none>            1883/TCP         22m
<release>-odm-decisionserverruntime         LoadBalancer   10.0.177.153   xxx.xxx.xxx.xxx   9443:31921/TCP   22m
```

You can then open a browser on https://xxx.xxx.xxx.xxx:9443 to access Decision Server console, Decision Server Runtime, and Decision Runner, and on https://xxx.xxx.xxx.xxx:9453 to access Decision Center.

## Install the IBM License Service and retrieve license usage

This section explains how to track ODM usage with the IBM License Service.

### Create a NGINX Ingress controller

1. Add the official stable repository

    ```
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    ```

2. Use Helm to deploy an NGINX Ingress controller

    ```
    helm install nginx-ingress ingress-nginx/ingress-nginx \
      --set controller.replicaCount=2 \
      --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
      --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux
    ```

3. Get the Ingress controller external IP address

    ```
    kubectl get service -l app.kubernetes.io/name=ingress-nginx
    NAME                                               TYPE           CLUSTER-IP     EXTERNAL-IP    PORT(S)                      AGE
    nginx-ingress-ingress-nginx-controller             LoadBalancer   10.0.191.246   <externalip>   80:30222/TCP,443:31103/TCP   3m8s
    nginx-ingress-ingress-nginx-controller-admission   ClusterIP      10.0.214.250   <none>         443/TCP                      3m8s
    ```

### Install the IBM License Service

Follow the **Installation** section of the [Manual installation without the Operator Lifecycle Manager (OLM)](https://github.com/IBM/ibm-licensing-operator/blob/latest/docs/Content/Install_without_OLM.md), make sure you don't follow the instantiation part!

### Create the Licensing instance

Just run:

```
kubectl create -f licensing-instance.yml
```

(More information and use cases on [this page](https://github.com/IBM/ibm-licensing-operator/blob/latest/docs/Content/Configuration.md#configuring-ingress).)

### Retrieving license usage

After a couple of minutes, the NGINX load balancer reflects the Ingress configuration and you will be able to access the IBM License Service by retrieving the URL with this command:

```
export LICENSING_URL=$(kubectl get ingress ibm-licensing-service-instance -n ibm-common-services |awk '{print $4}' |tail -1)/ibm-licensing-service-instance
export TOKEN=$(oc get secret ibm-licensing-token -o jsonpath={.data.token} -n ibm-common-services |base64 -d)
```

You can access the `http://${LICENSING_URL}/status?token=${TOKEN}` URL to view the licensing usage or retrieve the licensing report zip file by running:
```
curl -v "http://${LICENSING_URL}/snapshot?token=${TOKEN}" --output report.zip
```

If your IBM License Service instance is not running properly, please refer to this [troubleshooting page](https://github.com/IBM/ibm-licensing-operator/blob/latest/docs/Content/Troubleshooting.md).

## Optional steps

You may prefer to access ODM components through NGINX Ingress controller instead of directly from these different IP addresses.  If so, please follow [these instructions](README_NGINX.md).

## Troubleshooting

If your ODM instances are not running properly, please refer to [our dedicated troubleshooting page](https://www.ibm.com/docs/en/odm/8.11.0?topic=8110-troubleshooting-support).

# License

[Apache 2.0](../LICENSE)
