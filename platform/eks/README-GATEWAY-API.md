# Deploying IBM Operational Decision Manager with AWS Load Balancer Controller supporting Gateway API on Amazon EKS


The aim of this complementary documentation is to explain how to replace the deprecated **NGINX Ingress Controller** using the **AWS Load Balancer Controller that supports Kubernetes Gateway API**. For more information, see [AWS Load Balancer Controller for Kubernetes Gateway API](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/how-it-works/#gateway-api).

## Prerequisites

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

## Install an ODM release with Gateway API

In this tutorial, you will use [eks-gateway-values.yaml](./eks-gateway-values.yaml) or [eks-rds-gateway-values.yaml](./eks-rds-gateway-values.yaml) file for the installation.

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

## Track ODM usage

### Install the IBM Usage Metering service

IBM Usage Metering Service gathers metrics to monitor compliance and create reports. It captures business value metrics for auditing purposes and to visualize metric usage in reporting tools, and sends the information to IBM Software Central. For more details, see [Collecting and sending usage metrics](https://www.ibm.com/docs/en/odm/9.6.0?topic=production-collecting-sending-usage-metrics)

From ODM 9.6.0 onwards, it is required to install this metering service in the same namespace as ODM. ODM will systematically report usage metrics to the metering service through a CronJob. If the service is not installed, the job fails when it runs. For more information about the installation and configuration of UMS, see [Installing the usage metering service](https://www.ibm.com/docs/en/odm/9.6.0?topic=metrics-installing-metering). In this tutorial, we assume that ODM and UMS are installed in the same namespace `default`.

#### Expose the IBM Usage Metering service using a Gateway API

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
``` bash
NAME          CLASS                   ADDRESS                                                                  PROGRAMMED   AGE
odm-gateway   odm-alb-gateway-class   k8s-default-odmgatew-abcdefgh-123456789.<aws-region>.elb.amazonaws.com   True         20m
ums-gateway   ums-alb-gateway-class   k8s-default-umsgatew-ijklmnop-987654321.<aws-region>.elb.amazonaws.com   True         1m
```

Wait for the Gateway to be programmed to `True` to access the UMS service to retrieve the report.

#### Retrieve metering usage

To get the Usage Metering report, run the command below:
```bash
UMS_URL=$(kubectl get gateway ums-gateway -o jsonpath='{.status.addresses[*].value}')
UMS_TOKEN=$(kubectl get secret ibm-usage-metering-upload-token -o jsonpath='{.data.token}' | base64 -d)
curl -k --output ums-report.zip \
        --header "Authorization: Bearer ${UMS_TOKEN}" \
        --url "https://${UMS_URL}/api/v1/snapshot"
```

### Install IBM License Service

Follow the **Installation** section of the [Installation License Service without Operator Lifecycle Manager (OLM)](https://www.ibm.com/docs/en/cloud-paks/foundational-services/4.x_cd?topic=ilsfpcr-installing-license-service-without-operator-lifecycle-manager-olm) documentation, **except for the step 7** which must be replaced by the following:

> 7. Update the License Service instance that was created during installation to accept the license. At the same time, the default gateway configuration must be deactivated. We will apply the configuration that is adapted for AWS Load Balancer controller.
> - Create the `accept-license.yaml` file with the following content:
>
>```bash
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

#### Create the Gateway for the IBM License Service instance

Edit the file [ils-gateway-api.yaml](./ils-gateway-api.yaml) and replace the `<AWS-AccountId>` placeholder with your account ID. This can be found at the `defaultCertificate` parameter of `LoadBalancerConfiguration`. Save the file.

> **Note**
>  You can replace the `defaultCertificate` value with the ARN of the digital certificate that you have created in [Manage a  digital certificate](README.md#4-manage-adigital-certificate-10-min) section. If you have an existing digital certificate in ACM, you can use it instead of creating a new one.

Run this command to create the Gateway for the License Service instance:
```bash
kubectl apply -f ils-gateway-api.yaml
```

You should see the Gatewayclass, AWS Load Balancer configuration, Target Group configuration, Gateway and Httproute being created:
```bash
gatewayclass.gateway.networking.k8s.io/ibm-licensing created
loadbalancerconfiguration.gateway.k8s.aws/ils-alb-config created
targetgroupconfiguration.gateway.k8s.aws/ibm-licensing-service-tgc created
gateway.gateway.networking.k8s.io/ibm-licensing-service-gateway created
httproute.gateway.networking.k8s.io/ibm-licensing-route created
```

Wait a couple of minutes for the changes to be applied. 

Run the following command to see the status of Gateway instance:

```bash
kubectl get gateway -n ibm-licensing                         
```

You will find the address and other details about `ibm-licensing-service-gateway`.
```
NAME                            CLASS           ADDRESS                                                                 PROGRAMMED   AGE
ibm-licensing-service-gateway   ibm-licensing   k8s-ibmlicen-ibmlicen-xxxxxyyyyzzzzzz.<aws-region>.elb.amazonaws.com    True         1m
```

When the Gateway is programmed (set to `True`), you will be able to access the IBM License Service by retrieving the URL with this command:

```bash
export TOKEN=$(kubectl get secret ibm-licensing-token -n ibm-licensing -o jsonpath='{.data.token}' |base64 -d)
export LICENSING_URL=$(kubectl get gateway ibm-licensing-service-gateway -n ibm-licensing -o jsonpath='{.status.addresses[*].value}')/ibm-licensing-service-instance
echo https://${LICENSING_URL}/status?token=${TOKEN}
```

You can access the `https://${LICENSING_URL}/status?token=${TOKEN}` URL to view the licensing usage. 

Otherwise, you can also retrieve the licensing report .zip file by running:

```bash
curl -k "https://${LICENSING_URL}/snapshot?token=${TOKEN}" --output report.zip
```

IBM License Service can optionally send collected license usage data directly to IBM Software Central. For more information about the configuration, see [Reporting license usage to IBM Software Central](https://www.ibm.com/docs/en/odm/9.6.0?topic=metering-reporting-license-usage-software-central).

If your IBM License Service instance is not running properly, refer to this [troubleshooting page](https://www.ibm.com/docs/en/cloud-paks/foundational-services/4.x_cd?topic=service-troubleshooting-license).
