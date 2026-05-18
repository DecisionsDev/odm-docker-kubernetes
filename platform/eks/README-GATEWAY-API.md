# Deploying IBM Operational Decision Manager with AWS Load Balancer Controller supporting Gateway API on Amazon EKS


The aim of this complementary documentation is to explain how to replace the deprecated **NGINX Ingress Controller** using the **AWS Load Balancer Controller that supports Kubernetes Gateway API**. For more information, see [AWS Load Balancer Controller for Kubernetes Gateway API](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/how-it-works/#gateway-api).

## 1. Prerequisites

Follow [Step 1 of Preparing your environment](README.md#1-prepare-your-environment-20-min) to create an EKS cluster and set up your environment. **Important:** After completing steps 1.a-1.c, install the Gateway API CRDs below before proceeding to step 1.d (Provision an AWS Load Balancer Controller).


You must first install the following Gateway API CRDs before you provision the ALB controller:

- Installation of Gateway API CRDs:

```bash
kubectl apply --server-side=true -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml
```

- Installation of LBC Gateway API specific CRDs: 

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/refs/heads/main/config/crd/gateway/gateway-crds.yaml
```

For more information, see [AWS Load Balancer Controller Gateway prerequisites](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/gateway/gateway/#prerequisites).


You can then go back to the main documentation to continue [Step 2: Create an RDS database](README.md#2-create-an-rds-database-10-min) and [Step 3: Prepare your environment for the ODM installation](README.md#3-prepare-your-environment-for-the-odm-installation-5-min).

## 2. Install an ODM release with Gateway API

In this tutorial, you will use [eks-gateway-values.yaml](./eks-gateway-values.yaml) or [eks-rds-gateway-values.yaml](./eks-rds-gateway-values.yaml) file for the installation. We assume that ODM is installed in the namespace `default`.

To install ODM with the AWS RDS PostgreSQL database created in [step 2](README.md#2-create-an-rds-database-10-min):

- Get the [eks-rds-gateway-values.yaml](./eks-rds-gateway-values.yaml) file and replace the following keys:
  - `<RDS_DB_ENDPOINT>`: your database server endpoint (of the form: `<INSTANCE_NAME>.xxxxxxxx.<REGION>.rds.amazonaws.com`)
  - `<RDS_DATABASE_NAME>`: the initial database name defined when creating the RDS database

```bash
helm install mycompany ibm-helm/ibm-odm-prod -f eks-rds-gateway-values.yaml
```

> **Note**
> 
> - The above command installs the **latest available version** of the chart. If you want to install a **specific version**, add the `--version` option:
>
> ```bash
> helm install mycompany ibm-helm/ibm-odm-prod --version <version> -f eks-rds-gateway-values.yaml
> ```
>
> - You can list all available versions using:
>
> ```bash
> helm search repo ibm-helm/ibm-odm-prod -l
> ```
>
> - If you prefer to install ODM for prototyping (not for production) with the ODM PostgreSQL internal database. Get the [eks-gateway-values.yaml](./eks-gateway-values.yaml) file:
>
> ```bash
> helm install mycompany ibm-helm/ibm-odm-prod -f eks-gateway-values.yaml
> ```

After ODM is installed, you will proceed to create the relevant Gateway using [odm-gateway-api.yaml](./odm-gateway-api.yaml) file. 

Edit the [odm-gateway-api.yaml](./odm-gateway-api.yaml) file and replace the `<AWS-AccountId>` placeholder with your account ID. This can be found at the `defaultCertificate` parameter of `LoadBalancerConfiguration`. Save the file.

> **Note**
> - You can replace the `defaultCertificate` value with the ARN of the digital certificate that you have created in [Manage a digital certificate](README.md#4-manage-adigital-certificate-10-min) section. If you have an existing digital certificate in ACM, you can use it instead of creating a new one.
> - The `odm-gateway-api.yaml` file assumes ODM's release name is `mycompany`. If you used a different release name during installation, you must update all service name references in the file:
>   - In each `TargetGroupConfiguration`, update the `targetReference.name` field (e.g., `mycompany-odm-decisionserverconsole` to `<your-release-name>-odm-decisionserverconsole`).
>   - In the `HTTPRoute`, update all `backendRefs.name` fields to match your release name.

Apply the changes to the Gateway:
```bash
kubectl apply -f odm-gateway-api.yaml
```

You should see the Gatewayclass, AWS Load Balancer configuration, Target Group configurations for each ODM components, Gateway and Httproute being created:
```bash
gatewayclass.gateway.networking.k8s.io/odm-alb-gateway-class created
loadbalancerconfiguration.gateway.k8s.aws/odm-alb-config created
targetgroupconfiguration.gateway.k8s.aws/odm-decisionserverconsole-tgc created
targetgroupconfiguration.gateway.k8s.aws/odm-decisioncenter-tgc created
targetgroupconfiguration.gateway.k8s.aws/odm-decisionserverruntime-tgc created
targetgroupconfiguration.gateway.k8s.aws/odm-decisionrunner-tgc created
gateway.gateway.networking.k8s.io/odm-gateway created
httproute.gateway.networking.k8s.io/odm-services-route created
```

Wait a couple of minutes for the gateway to be programmed. 

Run this command to see the status of Gateway instance:

```bash
kubectl get gateway
```

You will find the address and other details about the newly created `odm-gateway` gateway.
```bash
NAME          CLASS                   ADDRESS                                                                  PROGRAMMED   AGE
odm-gateway   odm-alb-gateway-class   k8s-default-odmgatew-abcdefgh-123456789.<aws-region>.elb.amazonaws.com   True         10m
```

When the Gateway is programmed (set to `True`), you can then access the ODM services by retrieving the URL with this command:

```bash
export ROOTURL=$(kubectl get gateway odm-gateway -o jsonpath='{.status.addresses[*].value}')
echo $ROOTURL
```

With this ODM topology in place, you can access web applications to author, deploy, and test your rule-based decision services.

The ODM services are accessible from the following URLs:

| *Component* | *URL* | *Username/Password* |
|---|---|---|
| Decision Center | https://${ROOTURL}/decisioncenter | odmAdmin/odmAdmin |
| Decision Center Swagger | https://${ROOTURL}/decisioncenter-api | odmAdmin/odmAdmin |
| Decision Server Console |https://${ROOTURL}/res| odmAdmin/odmAdmin |
| Decision Server Runtime | https://${ROOTURL}/DecisionService | odmAdmin/odmAdmin |
| Decision Runner | https://${ROOTURL}/DecisionRunner | odmAdmin/odmAdmin |

## 3. Track ODM usage

### 3.1. Install the IBM Usage Metering service

IBM Usage Metering Service gathers metrics to monitor compliance and create reports. It captures business value metrics for auditing purposes and to visualize metric usage in reporting tools, and sends the information to IBM Software Central. For more details, see [Collecting and sending usage metrics](https://www.ibm.com/docs/en/odm/9.6.0?topic=production-collecting-sending-usage-metrics)

From ODM 9.6.0 onwards, it is required to install this metering service in the same namespace as ODM. ODM will systematically report usage metrics to the metering service through a CronJob. If the service is not installed, the job fails when it runs. For more information about the installation and configuration of UMS, see [Installing the usage metering service](https://www.ibm.com/docs/en/odm/9.6.0?topic=metrics-installing-metering). In this tutorial, we assume that ODM and UMS are installed in the same namespace `default`.

#### 3.1.1. Troubleshooting

If the CronJob fails, check the pod logs:
```bash
kubectl logs -n <namespace> -l job-name=<cronjob-name>
```

#### 3.1.2. Data transmission options

After installing the IBM Usage Metering service, choose one of the following modes to transmit the usage metering data based on your environment:

1. **Online mode** (Recommended): Automatic data transmission to IBM Software Central
2. **Offline mode** (Air-gapped): Manual data download and upload process

##### 3.1.2.1. Online mode (Recommended)

In online mode, the Usage Metering Service automatically sends usage data to IBM Software Central on a scheduled basis every 24 hours. This is the recommended configuration for environments with internet connectivity.

*Configuration requirements*:
- IBM Entitlement Key (required for authentication)
- Network connectivity to IBM Software Central (`swc.saas.ibm.com`)

For complete step-by-step instructions on configuring online mode, see [Automatic data transmission to IBM Software Central](https://www.ibm.com/docs/en/odm/9.6.0?topic=metrics-automatic-data-transmission).

##### 3.1.2.2. Offline mode (Air-gapped environments)

For offline/air-gapped environments where the Usage Metering Service cannot connect directly to IBM Software Central, you need to manually download and upload usage data.

###### 3.1.2.2.1. Expose the IBM Usage Metering service using a Gateway API

First, you will need to expose the service to have the access.

Edit the [ums-gateway-api.yaml](./ums-gateway-api.yaml) file and replace the `<AWS-AccountId>` placeholder with your account ID. This can be found at the `defaultCertificate` parameter of `LoadBalancerConfiguration`. Save the file.

> **Note**
>  You can replace the `defaultCertificate` value with the ARN of the digital certificate that you have created in [Manage a  digital certificate](README.md#4-manage-adigital-certificate-10-min) section. If you have an existing digital certificate in ACM, you can use it instead of creating a new one.

Run the command to create UMS's gateway:
```bash
kubectl apply -f ums-gateway-api.yaml
```

You should see the Gatewayclass, AWS Load Balancer configuration, Target Group configuration, Gateway and Httproute being created:
```bash
gatewayclass.gateway.networking.k8s.io/ums-alb-gateway-class created
loadbalancerconfiguration.gateway.k8s.aws/ums-alb-config created
targetgroupconfiguration.gateway.k8s.aws/ibm-usage-metering-tgc created
gateway.gateway.networking.k8s.io/ums-gateway created
httproute.gateway.networking.k8s.io/usage-metering-route created
```

Wait a couple of minutes for the gateway to be programmed. 

Run this command to see the status of Gateway instance:
```bash
kubectl get gateway
```

You will find the address and other details about the gateway pertaining to UMS `ums-gateway`.
```bash
NAME          CLASS                   ADDRESS                                                                  PROGRAMMED   AGE
odm-gateway   odm-alb-gateway-class   k8s-default-odmgatew-abcdefgh-123456789.<aws-region>.elb.amazonaws.com   True         20m
ums-gateway   ums-alb-gateway-class   k8s-default-umsgatew-ijklmnop-987654321.<aws-region>.elb.amazonaws.com   True         1m
```

Wait for the Gateway to be programmed to `True` to access the UMS service to retrieve the report.

###### 3.1.2.2.2. Retrieve metering usage data

To get the Usage Metering report, run the command below:
```bash
export UMS_URL=$(kubectl get gateway ums-gateway -o jsonpath='{.status.addresses[*].value}')
export UMS_TOKEN=$(kubectl get secret ibm-usage-metering-upload-token -o jsonpath='{.data.token}' | base64 -d)
curl -k --output "swc_payload.tar.gz" \
     --header "Authorization: Bearer ${UMS_TOKEN}" \
     --url "https://${UMS_URL}/api/v1/swc"
```

The `swc_payload.tar.gz` contains the following files:
- manifest.json
- usage.json

###### 3.1.2.2.3. Sending data to IBM Software Central

Transfer the downloaded `swc_payload.tar.gz` file to a system with internet connectivity.

Run the command to upload the file to IBM Software Central through its API:
```bash
curl -X POST "https://swc.saas.ibm.com/metering/api/v2/metrics" \
     -H "Authorization: Bearer <IEK>" \
     -F "file=@swc_payload.tar.gz;type=application/gzip"
```
> **Note**
> Replace the `<IEK>` placeholder with IBM Entitlement Key. You can obtain it from [IBM Container Software Library](https://myibm.ibm.com/products-services/containerlibrary).

For complete instructions, see [Uploading usage metrics to IBM Software Central](https://www.ibm.com/docs/en/odm/9.6.0?topic=metrics-uploading-usage-software-central).

#### 3.1.3. Additional resources

For general information about collecting and sending usage metrics, see [Collecting and sending usage metrics](https://www.ibm.com/docs/en/odm/9.6.0?topic=production-collecting-sending-usage-metrics).

### 3.2. Install IBM License Service

Follow the **Installation** section of the [Installation License Service without Operator Lifecycle Manager (OLM)](https://www.ibm.com/docs/en/cloud-paks/foundational-services/4.x_cd?topic=ilsfpcr-installing-license-service-without-operator-lifecycle-manager-olm) documentation, **except for the step 7** which must be replaced by the following:

> 7. Update the License Service instance that was created during installation to accept the license. At the same time, the default gateway configuration must be deactivated. We will apply the configuration that is adapted for AWS Load Balancer controller.
> - Create the `accept-license.yaml` file with the following content:
>
>```yaml
>spec:
>  gatewayEnabled: false
>  license:
>    accept: true
>```
> 
> - Patch the IBM Licensing instance
>```bash
>kubectl patch IBMLicensing instance --type merge --patch-file accept-license.yaml
>```

#### 3.2.1. Create the Gateway for the IBM License Service instance

Edit the file [ils-gateway-api.yaml](./ils-gateway-api.yaml) and replace the `<AWS-AccountId>` placeholder with your account ID. This can be found at the `defaultCertificate` parameter of `LoadBalancerConfiguration`. Save the file.

> **Note**
>  You can replace the `defaultCertificate` value with the ARN of the digital certificate that you have created in [Manage a  digital certificate](README.md#4-manage-adigital-certificate-10-min) section. If you have an existing digital certificate in ACM, you can use it instead of creating a new one.

Run this command to create the Gateway for the License Service instance:
```bash
kubectl apply -f ils-gateway-api.yaml
```

You should see the Gatewayclass, AWS Load Balancer configuration, Target Group configuration, Gateway and Httproute being created:
```bash
gatewayclass.gateway.networking.k8s.io/ils-alb-gateway-class created
loadbalancerconfiguration.gateway.k8s.aws/ils-alb-config created
targetgroupconfiguration.gateway.k8s.aws/ibm-licensing-service-tgc created
gateway.gateway.networking.k8s.io/ils-gateway created
httproute.gateway.networking.k8s.io/ibm-licensing-route created
```

Wait a couple of minutes for the changes to be applied. 

Run the following command to see the status of Gateway instance:

```bash
kubectl get gateway -n ibm-licensing                         
```

You will find the address and other details about `ibm-licensing-service-gateway`.
```bash
NAME          CLASS                   ADDRESS                                                                   PROGRAMMED   AGE
ils-gateway   ils-alb-gateway-class   k8s-ibmlicen-ilsgatew-3xxxxxyyyyzzzzzz.<aws-region>.elb.amazonaws.com     True         3m30s
```

When the Gateway is programmed (set to `True`), you will be able to access the IBM License Service by retrieving the URL with this command:

```bash
export TOKEN=$(kubectl get secret ibm-licensing-token -n ibm-licensing -o jsonpath='{.data.token}' |base64 -d)
export LICENSING_URL=$(kubectl get gateway ils-gateway -n ibm-licensing -o jsonpath='{.status.addresses[*].value}')/ibm-licensing-service-instance
echo https://${LICENSING_URL}/status?token=${TOKEN}
```

You can access the `https://${LICENSING_URL}/status?token=${TOKEN}` URL to view the licensing usage. 

Otherwise, you can also retrieve the licensing report .zip file by running:

```bash
curl -k "https://${LICENSING_URL}/snapshot?token=${TOKEN}" --output report.zip
```

#### 3.2.2. Reporting License Usage to IBM Software Central

IBM License Service can optionally send collected license usage data directly to IBM Software Central. For more information about the configuration, see [Reporting license usage to IBM Software Central](https://www.ibm.com/docs/en/odm/9.6.0?topic=metering-reporting-license-usage-software-central).

##### 3.2.2.1. Online mode

For detailed steps on configuring online mode (automatic data transmission), including creating the IBM Entitlement Key secret, configuring the IBMLicensing Custom Resource, and verifying the setup, refer to the [online mode documentation](https://www.ibm.com/docs/en/odm/9.6.0?topic=central-online-mode-configuration).


##### 3.2.2.2. Offline mode (Air-gapped environments)

For air-gapped environments where ILS cannot directly connect to IBM Software Central, download the usage data using the Gateway-specific commands below:

```bash
export TOKEN=$(kubectl get secret ibm-licensing-token -n ibm-licensing -o jsonpath='{.data.token}' |base64 -d)
export LICENSING_URL=$(kubectl get gateway ils-gateway -n ibm-licensing -o jsonpath='{.status.addresses[*].value}')/ibm-licensing-service-instance
curl --insecure --output "ils_swc_payload.tar.gz" \
     "https://${LICENSING_URL}/swc_aggregations?token=${TOKEN}"
```

Transfer the downloaded `ils_swc_payload.tar.gz` file to a system with internet connectivity.

Run the command to upload the file to IBM Software Central:
```bash
curl -X POST "https://swc.saas.ibm.com/metering/api/v2/metrics" \
     -H "Authorization: Bearer <IEK>" \
     -F "file=@ils_swc_payload.tar.gz;type=application/gzip"
```
> **Note**
> Replace the `<IEK>` placeholder with IBM Entitlement Key. You can obtain it from [IBM Container Software Library](https://myibm.ibm.com/products-services/containerlibrary).

For complete instructions on uploading the downloaded file to IBM Software Central, see the [offline mode documentation](https://www.ibm.com/docs/en/odm/9.6.0?topic=central-offline-mode-air-gapped-environments).

If your IBM License Service instance is not running properly, refer to this [troubleshooting page](https://www.ibm.com/docs/en/cloud-paks/foundational-services/4.x_cd?topic=service-troubleshooting-license).
