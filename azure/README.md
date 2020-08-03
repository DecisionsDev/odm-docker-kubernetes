# Deploying IBM Operational Decision Manager on Azure AKS

This project demonstrates how to deploy an IBM® Operational Decision Manager (ODM) clustered topology on the Azure Kubernetes Service (AKS) cloud service. This deployment implements Kubernetes and Docker technologies. 
Here is the home page of Microsoft Azure: https://portal.azure.com/?feature.quickstart=true#home

<img width="800" height="560" src='./images/aks-schema.jpg'/>

The ODM Docker material is available in Passport Advantage. It includes Docker container images and Helm chart descriptors. 

## Included components
The project comes with the following components:
- [IBM Operational Decision Manager](https://www.ibm.com/support/knowledgecenter/en/SSQP76_8.10.x/com.ibm.odm.kube/kc_welcome_odm_kube.html)
- [Azure Kubernetes Service (AKS)](https://docs.microsoft.com/en-us/azure/aks/)
- [Azure Database for PostgreSQL](https://docs.microsoft.com/en-us/azure/postgresql/)
- [AKS Networking](https://docs.microsoft.com/en-us/azure/aks/concepts-network)

## Tested environment
The commands and tools have been tested on macOS.

## Prerequisites
First, install the following software on your machine:

* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) 
* [Helm](https://github.com/helm/helm/releases)


Then, [create an Azure account and pay as you go](https://azure.microsoft.com/en-us/pricing/purchase-options/pay-as-you-go/)

## Steps to deploy ODM on Kubernetes from Azure AKS

### Table of Contents
=================

   * [Deploying IBM Operational Decision Manager on Azure AKS](#deploying-ibm-operational-decision-manager-on-azure-aks)
      * [Included components](#included-components)
      * [Tested environment](#tested-environment)
      * [Prerequisites](#prerequisites)
      * [Steps to deploy ODM on Kubernetes from Azure AKS](#steps-to-deploy-odm-on-kubernetes-from-azure-aks)
      * [Prepare your AKS instance](#prepare-your-aks-instance)
         * [a. Login to Azure](#a-login-to-azure)
         * [b. Create a resource group](#b-create-a-resource-group)
         * [c. Create an AKS cluster (30 min)](#c-create-an-aks-cluster-30-min)
         * [d. Set up your environment to this cluster](#d-set-up-your-environment-to-this-cluster)
      * [Create the Postgreql Azure instance](#create-the-postgreql-azure-instance)
         * [Create an Azure Database for PostgreSQL](#create-an-azure-database-for-postgresql)
         * [Create a firewall rule that allows access from Azure services](#create-a-firewall-rule-that-allows-access-from-azure-services)
      * [Preparing your environment for ODM installation](#preparing-your-environment-for-odm-installation)
         * [Create a pull secret to pull images from the IBM Entitled Registry that contains ODM Docker images](#create-a-pull-secret-to-pull-images-from-the-ibm-entitled-registry-that-contains-odm-docker-images)
         * [(Optional) Push the ODM images to the ACR (Azure Container Registry)](#optional-push-the-odm-images-to-the-acr-azure-container-registry)
            * [1. create an ACR](#1-create-an-acr)
            * [2. Login to the ACR registry](#2-login-to-the-acr-registry)
            * [3. Load the ODM images locally](#3-load-the-odm-images-locally)
            * [4. Tag and push the images to the ACR registry](#4-tag-and-push-the-images-to-the-acr-registry)
            * [5. Create a registry key to access to the ACR registry](#5-create-a-registry-key-to-access-to-the-acr-registry)
         * [Create the datasource Secrets for Azure Postgresql](#create-the-datasource-secrets-for-azure-postgresql)
         * [Create a secrets with this 2 files](#create-a-secrets-with-this-2-files)
         * [Create a database secret](#create-a-database-secret)
         * [Manage a  digital certificate (10 min)](#manage-a-digital-certificate-10-min)
            * [a. (Optional) Generate a self-signed certificate](#a-optional-generate-a-self-signed-certificate)
            * [b. Generate a JKS version of the certificate to be used in the ODM container ](#b-generate-a-jks-version-of-the-certificate-to-be-used-in-the-odm-container)
            * [c. Create a Kubernetes secret with the certificate.](#c-create-a-kubernetes-secret-with-the-certificate)
      * [Install an ODM Helm release and expose it with the service type loadbalalncer](#install-an-odm-helm-release-and-expose-it-with-the-service-type-loadbalalncer)
         * [Allocate public IP.](#allocate-public-ip)
         * [Install the ODM Release](#install-the-odm-release)
         * [Check the topology](#check-the-topology)
         * [Access ODM services](#access-odm-services)
      * [Access the ODM services via ingress](#access-the-odm-servicesvia-ingress)
         * [Create an ingress controller](#create-an-ingress-controller)
            * [Create a namespace for your ingress resources](#create-a-namespace-for-your-ingress-resources)
            * [Add the official stable repository](#add-the-official-stable-repository)
            * [Use Helm to deploy an NGINX ingress controller](#use-helm-to-deploy-an-nginx-ingress-controller)
         * [Get the ingress controller external IP address](#get-the-ingress-controller-external-ip-address)
         * [Create Kubernetes secret for the TLS certificate (<a href="https://docs.microsoft.com/en-US/azure/aks/ingress-own-tls#create-kubernetes-secret-for-the-tls-certificate" rel="nofollow">https://docs.microsoft.com/en-US/azure/aks/ingress-own-tls#create-kubernetes-secret-for-the-tls-certificate</a>)](#create-kubernetes-secret-for-the-tls-certificate-httpsdocsmicrosoftcomen-usazureaksingress-own-tlscreate-kubernetes-secret-for-the-tls-certificate)
         * [Deploy an ODM instance](#deploy-an-odm-instance)
         * [Create an Ingress route](#create-an-ingress-route)
         * [Edit your /etc/hosts](#edit-your-etchosts)
         * [Access ODM services](#access-odm-services-1)
            * [We can check that ODM services are in NodePort type](#we-can-check-that-odm-services-are-in-nodeport-type)
            * [ODM services are available through the following URLs](#odm-services-are-available-through-the-following-urls)
      * [Troubleshooting](#troubleshooting)
      * [References](#references)
   * [License](#license)

## Prepare your AKS instance

Source from : https://docs.microsoft.com/en-us/azure/aks/kubernetes-walkthrough

### a. Login to Azure

After installing the Azure cli use this command line.
   ```console
   az login 
   ```

It will open a web browser where you can connect using your Azure credentials

### b. Create a resource group
 An Azure resource group is a logical group in which Azure resources are deployed and managed. When you create a resource group, you are asked to specify a location. This location is where resource group metadata is stored, it is also where your resources run in Azure if you don't specify another region during resource creation. Create a resource group using the az group create command.
   ```console
az group create --name odm-group --location francecentral
   ```

The following example output shows the resource group created successfully:
   ```json
    {
      "id": "/subscriptions/<guid>/resourceGroups/odm-group",
      "location": "eastus",
      "managedBy": null,
      "name": "odm-group",
      "properties": {
        "provisioningState": "Succeeded"
      },
      "tags": null
    }
   ```
   

### c. Create an AKS cluster (30 min)
Use the az aks create command to create an AKS cluster. The following example creates a cluster named myAKSCluster with one node. Azure Monitor for containers is also enabled using the --enable-addons monitoring parameter.  This will take several minutes to complete.
 Note
When creating an AKS cluster a second resource group is automatically created to store the AKS resources. For more information see Why are two resource groups created with AKS?
   ```console
az aks create --resource-group odm-group --name odm-cluster --node-count 2 \
                  --location francecentral --enable-addons monitoring --generate-ssh-keys
   ```

After a few minutes, the command completes and returns JSON-formatted information about the cluster.

> NOTE: By default this will create a Kubernetes version 1.16 or higher.
       
### d. Set up your environment to this cluster
manage a Kubernetes cluster, you use kubectl, the Kubernetes command-line client. If you use Azure Cloud Shell, kubectl is already installed. To install kubectl locally, use the az aks install-cli command:

```console
az aks install-cli
```

To configure kubectl to connect to your Kubernetes cluster, use the az aks get-credentials command. This command downloads credentials and configures the Kubernetes CLI to use them.

```console
az aks get-credentials --resource-group odm-group --name odm-cluster
```

To verify the connection to your cluster, use the kubectl get command to return a list of the cluster nodes.

```console
kubectl get nodes
```

The following example output shows the single node created in the previous steps. Make sure that the status of the node is Ready:
Output
NAME                       STATUS   ROLES   AGE     VERSION
aks-nodepool1-31718369-0   Ready    agent   6m44s   v1.12.8


To further debug and diagnose cluster problems, run the command:

```console
kubectl cluster-info dump
```

## Create the Postgreql Azure instance

### Create an Azure Database for PostgreSQL

Create an Azure Database for PostgreSQL server using the az postgres server create command. A server can contain multiple databases.

```console
 az postgres server create --resource-group odm-group --name odmpsqlserver \
                           --admin-user myadmin --admin-password 'passw0rd!' \
                           --sku-name GP_Gen5_2 --version 9.6 --location francecentral
```

Verify the database
To connect to your server, you need to provide host information and access credentials.

```console
 az postgres server show --resource-group odm-group --name odmpsqlserver
```

Result:
   ```javascript
   {
        "administratorLogin": "myadmin",
        "byokEnforcement": "Disabled",
        "earliestRestoreDate": "2020-07-13T06:59:05.050000+00:00",
        "fullyQualifiedDomainName": "odmpsqlserver.postgres.database.azure.com",
        "id": "/subscriptions/18583f39-c9d2-4813-beba-1a633f94cdaa/resourceGroups/odm-group/providers/Microsoft.DBforPostgreSQL/servers/odmpsqlserver",
        "identity": null,
        "infrastructureEncryption": "Disabled",
        "location": "francecentral",
        "masterServerId": "",
        "minimalTlsVersion": "TLSEnforcementDisabled",
        "name": "odmpsqlserver",
        "privateEndpointConnections": [],
        "publicNetworkAccess": "Enabled",
        "replicaCapacity": 5,
        "replicationRole": "None",
        "resourceGroup": "odm-group",
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
           "storageMb": 5120
        },
        "tags": null,
        "type": "Microsoft.DBforPostgreSQL/servers",
        "userVisibleState": "Ready",
        "version": "9.6"
    }
```

###  Create a firewall rule that allows access from Azure services
To be able your database and your AKS cluster can communicate you should put in place Firewall rules with this following command:

```console
az postgres server firewall-rule create -g odm-group -s odmpsqlserver \
                       -n myrule --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0
```

## Preparing your environment for ODM installation

### Create a pull secret to pull images from the IBM Entitled Registry that contains ODM Docker images
1. Log in to [MyIBM Container Software Library](https://myibm.ibm.com/products-services/containerlibrary) with the IBMid and password that are associated with the entitled software.

2. In the **Container software library** tile, verify your entitlement on the **View library** page, and then go to **Get entitlement key** to retrieve the key.

3. Create a pull secret by running a `kubectl create secret` command.
   ```console
   kubectl create secret docker-registry admin.registrykey --docker-server=cp.icr.io --docker-username=cp --docker-password="<API_KEY_GENERATED>" --docker-email=<USER_EMAIL>```

   > **Note**: The `cp.icr.io` value for the **docker-server** parameter is the only registry domain name that contains the images.
   
   > **Note**: Use “cp” for the docker-username. The docker-email has to be a valid email address (associated to your IBM ID). Make sure you are copying the Entitlement Key in the docker-password field within double-quotes.

4. Take a note of the secret and the server values so that you can set them to the **pullSecrets** and **repository** parameters when you run the helm install for your containers.

### (Optional) Push the ODM images to the ACR (Azure Container Registry)

Reference documentation: ref. documentation: https://docs.microsoft.com/fr-fr/azure/container-registry/container-registry-get-started-azure-cli

#### 1. create an ACR 
```console
az acr create --resource-group odm-group --name odmregistry --sku Basic
```
Note the <loginServer> which will be displayed in the json output (e.g.: "loginServer": "registryodm.azurecr.io").
    
#### 2. Login to the ACR registry
```console
az acr login --name registryodm
```
#### 3. Load the ODM images locally

 - Download one or more packages (.tgz archives) from [IBM Passport Advantage (PPA)](https://www-01.ibm.com/software/passportadvantage/pao_customer.html).  To view the full list of eAssembly installation images, refer to the [8.10.4 download document](https://www.ibm.com/support/pages/ibm-operational-decision-manager-v8104-download-document).
 
 - Extract the .tgz archives to your local file system.
     ```bash
     $ tar xzf <PPA-ARCHIVE>.tar.gz
     ```

- Load the images to your local registry.
    ```bash
    $ cd images
    $ foreach name ( `ls`)  echo $name && docker image load --input $name && end
    ```

   For more information, refer to the [ODM knowledge center](https://www.ibm.com/support/knowledgecenter/SSQP76_8.10.x/com.ibm.odm.kube/topics/tsk_config_odm_prod_kube.html).

#### 4. Tag and push the images to the ACR registry

- Tag the images to the ACR registry previously created
```bash
    $ docker tag odm-decisionserverconsole:8.10.4.0-amd64 <loginServer>/odm-decisionserverconsole:8.10.4.0-amd64
    $ docker tag dbserver:8.10.4.0-amd64 <loginServer>/dbserver:8.10.4.0-amd64
    $ docker tag odm-decisioncenter:8.10.4.0-amd64 <loginServer>/odm-decisioncenter:8.10.4.0-amd64
    $ docker tag odm-decisionserverruntime:8.10.4.0-amd64 <loginServer>/odm-decisionserverruntime:8.10.4.0-amd64
    $ docker tag odm-decisionrunner:8.10.4.0-amd64 <loginServer>/odm-decisionrunner:8.10.4.0-amd64
```
- Push the images to the ACR registry
```bash
    $ docker push <loginServer>/odm-decisioncenter:8.10.4.0-amd64
    $ docker push <loginServer>/odm-decisionserverconsole:8.10.4.0-amd64
    $ docker push <loginServer>/odm-decisionserverruntime:8.10.4.0-amd64
    $ docker push <loginServer>/odm-decisionrunner:8.10.4.0-amd64
    $ docker push <loginServer>/dbserver:8.10.4.0-amd64
```
#### 5. Create a registry key to access to the ACR registry
```console
kubectl create secret docker-registry admin.registrykey --docker-server="registryodm.azurecr.io" --docker-username="registryodm" --docker-password="lSycuCFWnbIc8828xr4d87cbkn=OUWCg" --docker-email="mycompany@email.com"
```
Credentials can be found here: https://portal.azure.com/#@ibm.onmicrosoft.com/resource/subscriptions/36d56f7a-94b5-4b27-bd27-8dcf98753217/resourceGroups/odm-group/providers/Microsoft.ContainerRegistry/registries/registryodm/accessKey

### Create the datasource Secrets for Azure Postgresql
Copy the files [ds-bc.xml.template](ds-bc.xml.template]) and [ds-res.xml.template](ds-res.xml.template) on your local machine and copy it to ds-bc.xml / ds-res.xml

 Replace placeholer  
- DBNAME : The db name.
- USERNAME : The db username. 
- PASSWORD : The db password
- SERVERNAME : The name of the db server name
  
Should be something like that if you have not change the value of the cmd line.

```xml
 <properties
  databaseName="postgres"
  user="myadmin@odmpsqlserver"
  password="passw0rd!"
  portNumber="5432"
  sslMode="require"
  serverName="odmpsqlserver.postgres.database.azure.com" />
```

### Create a secrets with this 2 files
```console
kubectl create secret generic customdatasource-secret --from-file datasource-ds.xml=ds-res.xml --from-file datasource-dc.xml=ds-bc.xml
```

### Create a database secret

To secure access to the database, you must create a secret that encrypts the database user and password before you install the Helm release.

```console
kubectl create secret generic <odm-db-secret> --from-literal=db-user=<rds-postgresql-user-name> --from-literal=db-password=<rds-postgresql-password> 
```
Example:
```console
kubectl create secret generic odm-db-secret --from-literal=db-user=postgres --from-literal=db-password=postgres
```

### Manage a  digital certificate (10 min)

#### a. (Optional) Generate a self-signed certificate 

If you do not have a trusted certificate, you can use OpenSSL and other cryptography and certificate management libraries to generate a .crt certificate file and a private key, to define the domain name, and to set the expiration date. The following command creates a self-signed certificate (.crt file) and a private key (.key file) that accept the domain name *.mycompany.com*. The expiration is set to 1000 days:

```bash
$ openssl req -x509 -nodes -days 1000 -newkey rsa:2048 -keyout mycompany.key -out mycompany.crt -subj "/CN=*.mycompany.com/OU=it/O=mycompany/L=Paris/C=FR"
```

#### b. Generate a JKS version of the certificate to be used in the ODM container 

```bash
$ openssl pkcs12 -export -passout pass:password -passin pass:password -inkey mycompany.key -in mycompany.crt -name mycompany -out mycompany.p12
$ keytool -importkeystore -srckeystore mycompany.p12 -srcstoretype PKCS12 -srcstorepass password -destkeystore mycompany.jks -deststoretype JKS -deststorepass password
$ keytool -import -v -trustcacerts -alias mycompany -file mycompany.crt -keystore truststore.jks -storepass password -noprompt
```

#### c. Create a Kubernetes secret with the certificate.
```console
kubectl create secret generic mycompany-secret --from-file=keystore.jks=mycompany.jks \
                                               --from-file=truststore.jks=truststore.jks \
                                               --from-literal=keystore_password=password \
                                               --from-literal=truststore_password=password
```

The certificate must be the same as the one you used to enable TLS connections in your ODM release. For more information, see [Defining the security certificate](https://www.ibm.com/support/knowledgecenter/SSQP76_8.10.x/com.ibm.odm.icp/topics/tsk_replace_security_certificate.html?view=kc) and [Working with certificates and SSL](https://www.ibm.com/links?url=https%3A%2F%2Fdocs.oracle.com%2Fcd%2FE19830-01%2F819-4712%2Fablqw%2Findex.html).


## Install an ODM Helm release and expose it with the service type loadbalalncer

### Allocate public IP.
```console
 az aks update \
    --resource-group odm-group \
    --name odm-cluster \
    --load-balancer-managed-outbound-ip-count 4
```

### Install the ODM Release
```console
helm install mycompany --set image.repository=cp.icr.io/cp/cp4a/odm --set image.pullSecrets=admin.registrykey \
                       --set image.arch=amd64 --set image.tag=8.10.4.0 --set service.type=LoadBalancer \
                       --set externalCustomDatabase.datasourceRef=customdatasource-secret \
                       --set customization.securitySecretRef=mycompany-secret ibm-odm-prod
```

### Check the topology
Run the following command to check the status of the pods that have been created: 
```console
kubectl get pods
```


| *NAME* | *READY* | *STATUS* | *RESTARTS* | *AGE* |
|---|---|---|---|---|
| mycompany-odm-decisioncenter-*** | 1/1 | Running | 0 | 44m |  
| mycompany-odm-decisionrunner-*** | 1/1 | Running | 0 | 44m | 
| mycompany-odm-decisionserverconsole-*** | 1/1 | Running | 0 | 44m | 
| mycompany-odm-decisionserverruntime-*** | 1/1 | Running | 0 | 44m | 

Table 1. Status of pods

### Access ODM services
By setting the **service.type=LoadBalancer** the service are exposed with public ip to access it use this command:

```console
kubectl get svc
```

| NAME | TYPE | CLUSTER-IP | EXTERNAL-IP | PORT(S) | AGE |
| --- | --- | --- | -- | --- | --- | 
| mycompany-odm-decisionserverruntime | LoadBalancer  |  10.0.118.182 |   xx.xx.xxx.xxx  |     9443:32483/TCP  | 9s |
| mycompany-odm-decisioncenter | LoadBalancer  |  10.0.118.181 |   xx.xx.xxx.xxx  |     9453:32483/TCP  | 9s |
| mycompany-odm-decisionrunner | LoadBalancer  |  10.0.166.199 |   xx.xx.xxx.xxx   |  9443:31367/TCP  | 2d17h |
| mycompany-odm-decisionserverconsole | LoadBalancer |   10.0.224.220  |  xx.xx.xxx.xxx   |      9443:30874/TCP |   9s |
| mycompany-odm-decisionserverconsole-notif | ClusterIP | 10.0.103.221 |  \<none\> | 1883/TCP |        9s |
    
  Then you can open a browser to the https://xx.xx.xxx.xxx:9443 for Decision Server console/runtime and runner and https://xx.xx.xxx.xxx:9453 for Decision center.
    

## Access the ODM services via ingress

This section explains how to expose the ODM services to Internet connectivity with Ingress (reference Microsoft Azure documentation https://docs.microsoft.com/fr-fr/azure/aks/ingress-own-tls).

### Create an ingress controller
#### Create a namespace for your ingress resources
```console
kubectl create namespace ingress-basic
```
#### Add the official stable repository
```console
helm repo add stable https://kubernetes-charts.storage.googleapis.com/
```
#### Use Helm to deploy an NGINX ingress controller
```console
helm install nginx-ingress stable/nginx-ingress \
    --namespace ingress-basic \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux
```
### Get the ingress controller external IP address
```console
kubectl get service -l app=nginx-ingress --namespace ingress-basic
 NAME                             TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)                      AGE
nginx-ingress-controller         LoadBalancer   10.0.61.144    EXTERNAL_IP   80:30386/TCP,443:32276/TCP   6m2s
nginx-ingress-default-backend    ClusterIP      10.0.192.145   <none>        80/TCP                       6m2s
```
### Create Kubernetes secret for the TLS certificate (https://docs.microsoft.com/en-US/azure/aks/ingress-own-tls#create-kubernetes-secret-for-the-tls-certificate)
You must create the appropriate certificate files: mycompany.key mycompany.crt as defined in https://github.com/ODMDev/odm-docker-kubernetes/tree/azure/azure#a-optional-generate-a-self-signed-certificate.
```console
kubectl create secret tls mycompany-tls --namespace ingress-basic --key mycompany.key --cert mycompany.crt
```

### Deploy an ODM instance
```console
helm install mycompany --set image.repository=cp.icr.io/cp/cp4a/odm --set image.pullSecrets=admin.registrykey \
                        --set image.arch=amd64 --set image.tag=8.10.4.0 \
                        --set externalCustomDatabase.datasourceRef=customdatasource-secret ibm-odm-prod
```

### Create an Ingress route
Create a yaml file ingress-odm.yml as follow:
```console
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: mycompany
  namespace: ingress-basic
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    # Sticky session parameter needed for DecisionCenter see https://github.com/kubernetes/ingress-nginx/tree/master/docs/examples/affinity/cookie
    nginx.ingress.kubernetes.io/affinity: "cookie"
spec:
  tls:
  - hosts:
    - mycompany.com
    secretName: mycompany-tls
  rules:
  - host: mycompany.com
    http:
      paths:
      - path: /res
        backend:
          serviceName: mycompany-odm-decisionserverconsole
          servicePort: 9443
      - path: /DecisionService
        backend:
          serviceName: mycompany-odm-decisionserverruntime
          servicePort: 9443
      - path: /DecisionRunner
        backend:
          serviceName: mycompany-odm-decisionrunner
          servicePort: 9443
      - path: /decisioncenter
        backend:
          serviceName: mycompany-odm-decisioncenter
          servicePort: 9453
```

Apply ingress route:
```console
kubectl apply -f ingress-odm.yml
```

### Edit your /etc/hosts
```console
vi /etc/hosts
<EXTERNAL_IP> mycompany.com
```
### Access ODM services

#### We can check that ODM services are in NodePort type 

```console
kubectl get svc
```

| NAME | TYPE | CLUSTER-IP | EXTERNAL-IP | PORT(S) | AGE |
| --- | --- | --- | -- | --- | --- |
| mycompany-odm-decisioncenter | NodePort | 10.0.156.79 | <none> | 9453:31328/TCP | 56m |
| mycompany-odm-decisionrunner | NodePort | 10.0.53.181 | <none> | 9443:31576/TCP | 56m |
| mycompany-odm-decisionserverconsole | NodePort | 10.0.216.189 | <none> | 9443:30671/TCP | 56m |
| mycompany-odm-decisionserverconsole-notif | ClusterIP | 10.0.242.117 | <none> | 1883/TCP | 56m |
| mycompany-odm-decisionserverruntime | NodePort | 10.0.107.18 | <none> | 9443:32114/TCP | 56m |
| nginx-nginx-ingress-controller | LoadBalancer | 10.0.5.199 | <EXTERNAL_IP> | 80:30157/TCP,443:30409/TCP | 5h6m |
| nginx-nginx-ingress-default-backend | ClusterIP | 10.0.38.114 | <none> | 80/TCP | 5h6m |


#### ODM services are available through the following URLs

| SERVICE NAME | URL | USERNAME/PASSWORD |
| --- | --- | --- |
| Decision Server Console | https://mycompany.com/res | odmAdmin/odmAdmin |
| Decision Center | https://mycompany.com/decisioncenter | odmAdmin/odmAdmin |
| Decision Server Runtime | https://mycompany.com/DecisionService | odmAdmin/odmAdmin |
| Decision Runner | https://mycompany.com/DecisionRunner | odmAdmin/odmAdmin |

## Troubleshooting

If your microservice instances are not running properly, check the logs by running the following command:
```console
kubectl logs <your-pod-name>
```


## References
https://docs.microsoft.com/en-US/azure/aks/
https://docs.microsoft.com/en-US/azure/aks/ingress-own-tls
https://docs.microsoft.com/fr-fr/azure/container-registry/container-registry-get-started-azure-cli

# License
[Apache 2.0](LICENSE)
