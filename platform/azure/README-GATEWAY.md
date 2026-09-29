# Deploying IBM Operational Decision Manager with Application Gateway for Containers (AGC) supporting Gateway API on Azure AKS


The aim of this complementary documentation is to explain how to replace the deprecated **NGINX Ingress Controller** with the **Application Gateway for Containers (AGC) and ALB controller** leveraging Kubernetes **Gateway API**. 

You can read more about [Application Gateway for Containers](https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/overview). In this tutorial, we use the Managed by ALB Controller deployment strategy for its ease of use. 

## Prerequisites

First, install the following software on your machine:

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
- [Helm v3](https://helm.sh/docs/v3/intro/install/) or [Helm v4](https://helm.sh/docs/intro/install/)
- [gettext](https://www.gnu.org/software/gettext/)

Then, [create an Azure account and pay as you go](https://azure.microsoft.com/en-us/pricing/purchase-options/pay-as-you-go/).

> [!NOTE]
> Prerequisites and software supported by ODM 9.6.0 are listed in [the Detailed System Requirements page](https://www.ibm.com/support/pages/ibm-operational-decision-manager-detailed-system-requirements).

## Create an AKS cluster and Application Gateway for Containers (AGC)

Source: https://docs.microsoft.com/en-us/azure/aks/kubernetes-walkthrough

### 1. Create an AKS cluster

#### 1.1 Log into Azure

After installing the Azure CLI, use the following command line:

```shell
az login [--tenant <name>.onmicrosoft.com]
```

A web browser opens where you can connect with your Azure credentials.

#### 1.2 Create a resource group

An Azure resource group is a logical group in which Azure resources are deployed and managed. When you create a resource group, you will be prompted to specify a location. This location is where resource group metadata is stored. It is also where your resources run in Azure, if you do not specify another region during resource creation. 

To get a list of available locations, run:

```shell
az account list-locations -o table
```

Then, create a resource group by running the following command:

```shell
az group create --name <resourcegroup> --location <azurelocation> --tags Owner=<email> Team=<team> Usage=demo Usage_desc="Azure customers support" Delete_date=2026-12-31
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
    "Delete_date": "2026-12-31",
    "Owner": "<email>",
    "Team": "<team>",
    "Usage": "demo",
    "Usage_desc": "Azure customers support"
  },
  "type": "Microsoft.Resources/resourceGroups"
}
```

#### 1.3 Create an AKS cluster

This tutorial was tested using an AKS cluster version 1.35.8.

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
    --tags Owner=<email> Team=<team> Usage=demo Usage_desc="Azure customers support" Delete_date=2026-12-31
```

#### 1.4 Set up your environment to this cluster

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
aks-nodepool1-32493714-vmss000000   Ready    <none>  21m   v1.35.8
aks-nodepool1-32493714-vmss000001   Ready    <none>  21m   v1.35.8
```

### 2. Deploy Application Gateway for Containers ALB Controller using AKS Add-on
- Prerequisites:

  - [Install or update the Azure CLI extensions](https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/quickstart-deploy-application-gateway-for-containers-alb-controller-addon?toc=%2Fazure%2Faks%2Ftoc.json&bc=%2Fazure%2Faks%2Fbreadcrumb%2Ftoc.json&tabs=azure-cli%2Cazure-cli2#prerequisites)
    ```shell
    # Install Azure CLI extensions
    az extension add --name alb
    az extension add --name aks-preview

    # Update the extensions to the latest version
    az extension update --name alb
    az extension update --name aks-preview
    ```

  - [Register the add-on features flag](https://learn.microsoft.com/en-us/azure/aks/managed-gateway-api#register-the-managed-gateway-api-preview-feature-flag)
    ```shell
    az feature register --namespace "Microsoft.ContainerService" --name "ManagedGatewayAPIPreview"
    az feature register --namespace "Microsoft.ContainerService" --name "ApplicationLoadBalancerPreview"
    ```

  - [Add prerequisites to an existing cluster](https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/quickstart-deploy-application-gateway-for-containers-alb-controller-addon?toc=%2Fazure%2Faks%2Ftoc.json&bc=%2Fazure%2Faks%2Fbreadcrumb%2Ftoc.json&tabs=azure-cli%2Cazure-cli2#add-prerequisites-to-an-existing-cluster)
    ```shell
    az aks update --resource-group <resourcegroup> --name <cluster> --enable-oidc-issuer --enable-workload-identity --no-wait
    ```

    This update might take a while. To check its progress, run:
    ```shell
    az aks show \
      --resource-group <resourcegroup> \
      --name <cluster> \
      --query "provisioningState" \
      --output table
    ```

  - [Install Managed Gateway API CRDs on an existing AKS cluster](https://learn.microsoft.com/en-us/azure/aks/managed-gateway-api#install-managed-gateway-api-crds-on-an-existing-aks-cluster) and [Install ALB Controller add-on](https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/quickstart-deploy-application-gateway-for-containers-alb-controller-addon#install-alb-controller-add-on)
  
    When the update is succeeded, run:
    ```shell
    az aks update --resource-group <resourcegroup> --name <cluster> --enable-gateway-api --enable-application-load-balancer
    ```
    Wait for the update to complete before proceeding to the next step.

- Verification:

  - [Verify Managed Gateway API CRD installation](https://learn.microsoft.com/en-us/azure/aks/managed-gateway-api#verify-managed-gateway-api-crd-installation).

  - [Verify the ALB Controller installation](https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/quickstart-deploy-application-gateway-for-containers-alb-controller-addon#verify-the-alb-controller-installation)
    - check the ALB controller is running:
      ```shell
      kubectl get pods -n kube-system | grep alb-controller
      ```
      You should see two alb-controller pods in Running state.

    - Verify the GatewayClass `azure-alb-external` is installed on your cluster:
      ```shell
      kubectl get gatewayclass azure-alb-external -o yaml
      ```

  - [Validate Add-on Resources in Azure portal](https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/quickstart-deploy-application-gateway-for-containers-alb-controller-addon?toc=%2Fazure%2Faks%2Ftoc.json&bc=%2Fazure%2Faks%2Fbreadcrumb%2Ftoc.json&tabs=azure-cli%2Cazure-cli2#validate-add-on-resources-in-azure-portal):

    - A managed identity named `applicationloadbalancer-<cluster-name>` should be created and granted three roles `Network Contributor`, `AppGw for Containers Configuration Manager`, and `Reader`
    - A subnet named `aks-appgateway` (found under your Virtual network `aks-vnet-xxxxxx`) is automatically created with delegation enabled for `Microsoft.ServiceNetworking/TrafficController`

## Install an ODM release and expose it with Gateway API

### 1. Create a PostgreSQL Azure instance

Optionally click this link to [Create a PostgreSQL Azure instance 10 min](README.md#create-the-postgresql-azure-instance-10-min).

### 2. Define secrets

#### 2.1 Create the registry pull secret

Log in to [MyIBM Container Software Library](https://myibm.ibm.com/products-services/containerlibrary) with the IBMid and password that are associated with the entitled software.

In the Container software library tile, verify your entitlement on the View library page, and then go to Get entitlement key to retrieve the key.

Create a pull secret by running the `kubectl create secret` command.

```shell
kubectl create secret docker-registry ibm-entitlement-key \
        --docker-server=cp.icr.io \
        --docker-username=cp \
        --docker-password="<API_KEY_GENERATED>" \
        --docker-email=<USER_EMAIL>
```
Where:

* `<API_KEY_GENERATED>` is the entitlement key from the previous step. Make sure you enclose the key in double-quotes.
* `<USER_EMAIL>` is the email address associated with your IBMid.

> [!NOTE]
> 1. The **cp.icr.io** value for the docker-server parameter is the only registry domain name that contains the images. You must set the *docker-username* to **cp** to use an entitlement key as *docker-password*.
> 2. The `ibm-entitlement-key` secret name will be used for the `image.pullSecrets` parameter when you run a Helm install of your containers. The `image.repository` parameter is also set by default to `cp.icr.io/cp/cp4a/odm`.

#### 2.2 Add the public IBM Helm charts repository

Add the public IBM Helm charts repository:

```shell
helm repo add ibm-helm https://raw.githubusercontent.com/IBM/charts/master/repo/ibm-helm
helm repo update
```

Check that you can access the ODM charts:

```shell
helm search repo ibm-odm-prod
NAME                        CHART VERSION	APP VERSION DESCRIPTION
ibm-helm/ibm-odm-prod       26.3.0       	9.7.0.0     IBM Operational Decision Manager  License By in...
```

#### 2.3 (optional) Generate a self-signed certificate

If you do not have a trusted certificate, you can use OpenSSL and other cryptography and certificate management libraries to generate a certificate file and a private key, to define the domain name, and to set the expiration date. The following command creates a self-signed certificate (.crt file) and a private key (.key file) that accept the domain name *mynicecompany.com*. The expiration is set to 1000 days:

```shell
openssl req -x509 -nodes -days 1000 -newkey rsa:2048 -keyout mynicecompany.key \
        -out mynicecompany.crt -subj "/CN=mynicecompany.com/OU=it/O=mynicecompany/L=Paris/C=FR" \
        -addext "subjectAltName = DNS:mynicecompany.com"
```

> [!NOTE]
> You can use -addext only with actual OpenSSL and from LibreSSL 3.1.0.

#### 2.4 Create a Kubernetes secret containing the key and certificate to use to secure the communication (TLS)

```shell
kubectl create secret tls <mynicecompanytlssecret> --cert=mynicecompany.crt --key=mynicecompany.key
```

The certificate must be the same as the one you used to enable TLS connections in your ODM release. For more information, see [Server certificates](https://www.ibm.com/docs/en/odm/9.6.0?topic=production-defining-security-certificate).

### 3. Configure your environment and set environment variables

- Clone this repository and change the current directory:

    ```shell
    git clone https://github.com/DecisionsDev/odm-docker-kubernetes.git
    cd odm-docker-kubernetes/platform/azure
    ```

- Set the environment variables below (change their values if needed):

    ```bash
    export HELM_RELEASE="odmchart"
    export USERS_PASSWORD="odmAdmin"
    export DOMAIN="mynicecompany.com"
    export TLS_SECRET="mynicecompanytlssecret"
    export CLUSTER_NAME=<cluster>           # Your AKS cluster name
    export RESOURCE_GROUP=<resourcegroup>   # Your Azure resource group
    export NAMESPACE="default"              # Namespace where ODM is installed
    ```

### 4. Deploy ODM

Make sure you have set the environment variables in the previous step.

You can either:

- deploy ODM with an **internal ephemeral database** (for a quick test):

  ```bash
  envsubst < aks-gateway-values.yaml | helm install ${HELM_RELEASE} ibm-helm/ibm-odm-prod -f - -n ${NAMESPACE}
  ```

- or deploy ODM with the **PostgreSQL Azure database**:

  ```bash
  export POSTGRESQL_SERVER_NAME="postgresqlserver" # not the FQDN - the FQDN is ${POSTGRESQL_SERVER_NAME}.postgres.database.azure.com
  export POSTGRESQL_CREDENTIALS_SECRET="odmdbsecret"

  envsubst < aks-gateway-external-db-values.yaml | helm install ${HELM_RELEASE} ibm-helm/ibm-odm-prod -f - -n ${NAMESPACE}
  ```

> [!NOTE] 
> The above command installs the **latest version** of the chart (possibly an iFix). To install an alternative version:
> 
>   - List all versions available by running:
>
>     ```bash
>     helm search repo ibm-helm/ibm-odm-prod -l
>     ```
>
>   - Add the `--version <version>` option to specify the version to install, eg.:
>
>     ```bash
>     envsubst < aks-gateway-external-db-values.yaml | helm install ${HELM_RELEASE} ibm-helm/ibm-odm-prod --version 26.0.0 -f - -n ${NAMESPACE}
>     ```

### 5. Expose ODM with Gateway API

Run the script:

```bash
source get_alb_subnet_id.sh   # sets ALB_SUBNET_ID

# uncomment the line below if you are running this script a second time to update the Gateway API k8s resources (safer)
# envsubst < odm-gateway.yaml | kubectl delete -f -

envsubst < odm-gateway.yaml | kubectl apply -f -

echo "Waiting for the Application Load Balancer to be programmed..."
kubectl wait --for=condition=Programmed gateway/${HELM_RELEASE}-odm-gateway -n ${NAMESPACE} --timeout=5m

echo "Waiting for the gateway to have an address..."
while true; do
    FQDN=$(kubectl get gateway ${HELM_RELEASE}-odm-gateway -n ${NAMESPACE} -o jsonpath='{.status.addresses[0].value}')
    if [[ -n "${FQDN}" ]]; then break; fi
    sleep 5
done

EXTERNAL_IP=$(ping -c 1 ${FQDN} | awk -F '[()]' '/PING/ { print $2}')
echo "External IP: ${EXTERNAL_IP}"
```

You should see the traces below:
```bash
applicationloadbalancer.alb.networking.azure.io/shared-alb created
gateway.gateway.networking.k8s.io/odmchart-odm-gateway created
httproute.gateway.networking.k8s.io/odmchart-odm-httproute created
httproute.gateway.networking.k8s.io/odmchart-odm-decisioncenter-httproute created
routepolicy.alb.networking.azure.io/odmchart-odm-decisioncenter-session-affinity-route-policy created
healthcheckpolicy.alb.networking.azure.io/odmchart-odm-decisioncenter-health-check-policy created
healthcheckpolicy.alb.networking.azure.io/odmchart-odm-decisionrunner-health-check-policy created
healthcheckpolicy.alb.networking.azure.io/odmchart-odm-decisionserverconsole-health-check-policy created
healthcheckpolicy.alb.networking.azure.io/odmchart-odm-decisionserverruntime-health-check-policy created
backendtlspolicy.alb.networking.azure.io/odmchart-odm-decisioncenter-tls-policy created
backendtlspolicy.alb.networking.azure.io/odmchart-odm-decisionrunner-tls-policy created
backendtlspolicy.alb.networking.azure.io/odmchart-odm-decisionserverconsole-tls-policy created
backendtlspolicy.alb.networking.azure.io/odmchart-odm-decisionserverruntime-tls-policy created

Waiting for the Application Load Balancer to be programmed...
gateway.gateway.networking.k8s.io/odmchart-odm-gateway condition met

Waiting for the gateway to have an address...
External IP: 4.150.170.213
```

Check that the status of the Gateway is PROGRAMMED=`True`:

```bash
kubectl get gateway
```

You should see the following:
```bash
NAME                  CLASS                ADDRESS                               PROGRAMMED   AGE
odmchart-odm-gateway  azure-alb-external   hvf6h8c5f4fdhcbk.fz46.alb.azure.com   True         10m
```

When the Gateway is programmed (set to `True`), you can add the external IP address to your `/etc/hosts` file.

Add the line below to your `/etc/hosts` file (where <externalip> is the external IP address of the gateway that you can find in the traces of the commands above):

```
<externalip> mynicecompany.com
```

The ODM services are then accessible from the following URLs:

| *Component* | *URL* | *Username/Password* |
|---|---|---|
| Decision Center | https://mynicecompany.com/decisioncenter | odmAdmin/odmAdmin |
| Decision Center Swagger | https://mynicecompany.com/decisioncenter-api | odmAdmin/odmAdmin |
| Decision Server Console |https://mynicecompany.com/res| odmAdmin/odmAdmin |
| Decision Server Runtime | https://mynicecompany.com/DecisionService | odmAdmin/odmAdmin |
| Decision Runner | https://mynicecompany.com/DecisionRunner | odmAdmin/odmAdmin |

## Track ODM usage

### 1. Install the IBM Usage Metering service

IBM Usage Metering Service (UMS) gathers adoption metrics and creates reports. It captures business value metrics for auditing purposes and to visualize metric usage in reporting tools, and sends the information to IBM Software Central. For more details, see [Collecting and sending usage metrics](https://www.ibm.com/docs/en/odm/9.6.0?topic=production-collecting-sending-usage-metrics).

The IBM License Service (ILS) discovers the software that is installed in your infrastructure and generates reports containing contractual details. These metrics directly affect licensing obligations and are required for calculating license usage in compliance with IBM licensing requirements.

An ILS side-car must be activated when installing UMS. This allows UMS to capture two metrics: contractual metrics for compliance purposes, and adoption metrics for various scenarios related to usage analysis. 

It is required to install UMS in the same namespace as ODM. ODM will systematically report the usage metrics to the metering service through a CronJob. If the service is not installed, the job fails when it runs. 

To install and configure UMS, follow the information at [Installing the usage metering service](https://www.ibm.com/docs/en/odm/9.6.0?topic=metrics-installing-metering).

In this tutorial, we assume that ODM, UMS, and ILS are installed in the same namespace: `default`. The ILS side car is enabled with *namespace scope* to monitor only `default` namespace.

### 2. Troubleshooting

If the CronJob fails, check the pod logs:
```bash
kubectl logs -n <namespace> -l job-name=<cronjob-name>
```

### 3. Data transmission options

After installing the IBM Usage Metering service, choose one of the following modes to transmit the usage metering data based on your environment:

1. **Online mode** (Recommended): Automatic data transmission to IBM Software Central
2. **Offline mode** (Air-gapped): Manual data download and upload process

#### 3.1 Online mode (Recommended)

In online mode, the Usage Metering Service automatically sends *both adoption and contractual* data to IBM Software Central on a scheduled basis every 24 hours. This is the recommended configuration for environments with internet connectivity.

**Configuration requirements**:
- IBM Entitlement Key (required for authentication).
- Network connectivity to IBM Software Central (`swc.saas.ibm.com`)

For complete step-by-step instructions on configuring online mode, see [Automatic data transmission to IBM Software Central](https://www.ibm.com/docs/en/odm/9.6.0?topic=metrics-automatic-data-transmission).

#### 3.2 Offline mode (Air-gapped environments)

For offline/air-gapped environments where the Usage Metering Service cannot connect directly to IBM Software Central, you need to manually download and upload usage data.

#### 3.2.1 Expose the IBM Usage Metering service and IBM License Service using a Gateway API

The IBM License Service (ILS) is integrated as a sidecar in the UMS pod and exposed through the same gateway. The script below creates:
- A dedicated `ClusterIP` service (`ibm-license-service-agc-target`) pointing to the ILS sidecar port
- A single Gateway with two HTTPRoutes — one for UMS (`/ibm-usage-metering-instance`) and one for ILS (`/ibm-licensing-service-instance`)
- Independent health check and TLS policies for each service

Make sure you have set the environment variables (see [step](#3-configure-your-environment-and-set-environment-variables)), then run:

```bash
# uncomment the lines below if you are running this script a second time to update the Gateway API k8s resources (safer)
# envsubst < ils-service.yaml | kubectl delete -f -
# envsubst < ums-gateway.yaml | kubectl delete -f -

envsubst < ils-service.yaml | kubectl apply -f -
envsubst < ums-gateway.yaml | kubectl apply -f -

echo "Waiting for the Application Load Balancer to be programmed..."
kubectl wait --for=condition=Programmed gateway/ibm-usage-metering-gateway -n ${NAMESPACE} --timeout=5m
```

You should see the traces below:
```bash
service/ibm-license-service-agc-target created
gateway.gateway.networking.k8s.io/ibm-usage-metering-gateway created
httproute.gateway.networking.k8s.io/ibm-usage-metering-routes created
healthcheckpolicy.alb.networking.azure.io/ums-health-check-policy created
healthcheckpolicy.alb.networking.azure.io/ils-health-check-policy created
backendtlspolicy.alb.networking.azure.io/ums-backend-tls-policy created
backendtlspolicy.alb.networking.azure.io/ils-backend-tls-policy created

Waiting for the Application Load Balancer to be programmed...
gateway.gateway.networking.k8s.io/ibm-usage-metering-gateway condition met
```

It may take a couple of minutes for the gateway to be programmed.

Run this command to see the status of the Gateway instance:
```bash
kubectl get gateway
```

```bash
NAME                         CLASS                ADDRESS                               PROGRAMMED   AGE
odmchart-odm-gateway         azure-alb-external   hvf6h8c5f4fdhcbk.fz46.alb.azure.com   True         20m
ibm-usage-metering-gateway   azure-alb-external   asayd2eue7efc3ea.fz25.alb.azure.com   True         1m
```

Wait for the Gateway to be programmed (`True`) to access the UMS and ILS services.

#### 3.2.2 Retrieve metering usage data

To get the report, run the command below:
```bash
GW_URL=$(kubectl get gateway ibm-usage-metering-gateway -n ${NAMESPACE} -o jsonpath='{.status.addresses[*].value}')
TOKEN=$(kubectl get secret ibm-usage-metering-upload-token -n ${NAMESPACE} -o jsonpath='{.data.token}' | base64 -d)
curl -k --output "swc_payload.tar.gz" \
     --header "Authorization: Bearer ${TOKEN}" \
     "https://${GW_URL}/ibm-usage-metering-instance/api/v1/swc"
```

The `swc_payload.tar.gz` contains the following files:
- manifest.json
- usage.json

The `usage.json` file contains both adoption (`"metricType": "adoption"`) and contractual (`"metricType": "contract"`) metrics.

#### 3.2.3 Sending data to IBM Software Central

Transfer the downloaded `swc_payload.tar.gz` file to a system with internet connectivity.

Run the command to upload the file to IBM Software Central through its API:
```bash
curl -X POST "https://swc.saas.ibm.com/metering/api/v2/metrics" \
     -H "Authorization: Bearer <ENTITLEMENT_KEY>" \
     -F "file=@swc_payload.tar.gz;type=application/gzip"
```
> [!NOTE]
> Replace the `<ENTITLEMENT_KEY>` placeholder with IBM Entitlement Key. You can obtain it from [IBM Container Software Library](https://myibm.ibm.com/products-services/containerlibrary).

For complete instructions, see [Uploading usage metrics to IBM Software Central](https://www.ibm.com/docs/en/odm/9.6.0?topic=metrics-uploading-usage-software-central).

#### 3.2.4 Additional resources

For general information about collecting and sending usage metrics, see [Collecting and sending usage metrics](https://www.ibm.com/docs/en/odm/9.6.0?topic=production-collecting-sending-usage-metrics).

### 4. [Optional] Access IBM License Service

ILS is exposed through the same gateway as UMS (deployed in [section 3.2.1](#321-expose-the-ibm-usage-metering-service-and-ibm-license-service-using-a-gateway-api)). You will be able to access its dashboard by retrieving the URL and the required token with this command:

```bash
GW_URL=$(kubectl get gateway ibm-usage-metering-gateway -n ${NAMESPACE} -o jsonpath='{.status.addresses[*].value}')
TOKEN=$(kubectl get secret ibm-usage-metering-upload-token -n ${NAMESPACE} -o jsonpath='{.data.token}' | base64 -d)

# View license usage status
echo "https://${GW_URL}/ibm-licensing-service-instance/status?token=${TOKEN}"
```
Alternatively you can retrieve the licensing report .zip file by running:

```shell
# Download license snapshot
curl -k --output "ils_report.zip" \
     "https://${GW_URL}/ibm-licensing-service-instance/snapshot?token=${TOKEN}"
```
