# Deploying IBM Operational Decision Manager with NGINX Ingress Controller on Amazon EKS

> **WARNING** 
> The NGINX Ingress Controller is **DEPRECATED**. For more information, see [Ingress NGINX Retirement: What You Need to Know](https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/).
> This documentation is kept for reference purposes only for existing deployments and will be removed in the coming months.

The aim of this complementary documentation is to explain how to replace the **AWS Load Balancer Controller** usage with an **NGINX Ingress Controller**.

## Prerequisites

You must have created an EKS cluster and set up your environment by following step 1 of [Deploying IBM Operational Decision Manager on Amazon EKS](README.md#1-prepare-your-environment-20-min).

> **Note**:
> Make sure that AWS Load Balancer Controller is not provisioned in this cluster.


## Provision an NGINX Ingress Controller

You can replace the [Provision an AWS Load Balancer Controller](README.md#d-provision-an-aws-load-balancer-controller) step by provisioning an NGINX Ingress Controller with the following commands.

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install my-odm-nginx ingress-nginx/ingress-nginx --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"=nlb
```

For more information, refer to the [ingress-nginx readme](https://github.com/kubernetes/ingress-nginx/tree/main/charts/ingress-nginx#install-chart).

The `my-odm-nginx` service should have an available `External-IP` when you run the command:

```bash
kubectl get service my-odm-nginx-ingress-nginx-controller
```

You can then go back to the main documentation to continue [Step 2: Create an RDS database](README.md#2-create-an-rds-database-10-min) and [Step 3: Prepare your environment for the ODM installation](README.md#3-prepare-your-environment-for-the-odm-installation-5-min).

## Install an ODM release with NGINX Ingress Controller

In this tutorial, you will use [eks-nginx-values.yaml](./eks-nginx-values.yaml) or [eks-rds-nginx-values.yaml](./eks-rds-nginx-values.yaml) file that contains the relevant Ingress class: `nginx` and annotation: `nginx.ingress.kubernetes.io/backend-protocol: https` for the installation.

To install ODM with the AWS RDS PostgreSQL database created in [step 2](README.md#2-create-an-rds-database-10-min):

- Get the [eks-rds-nginx-values.yaml](./eks-rds-nginx-values.yaml) file and replace the following keys:
  - `<RDS_DB_ENDPOINT>`: your database server endpoint (of the form: `<INSTANCE_NAME>.xxxxxxxx.<REGION>.rds.amazonaws.com`)
  - `<RDS_DATABASE_NAME>`: the initial database name defined when creating the RDS database

```bash
helm install mycompany ibm-helm/ibm-odm-prod -f eks-rds-nginx-values.yaml
```

> **Note**
> - By default, NGINX does not enable sticky session. If you want to use sticky session to connect to DC, refer to [Using sticky session for Decision Center connection](../../contrib/sticky-session/README.md)
> 
> - The above command installs the **latest available version** of the chart. If you want to install a **specific version**, add the `--version` option:
>
> ```bash
> helm install mycompany ibm-helm/ibm-odm-prod --version <version> -f eks-rds-nginx-values.yaml
> ```
>
> - You can list all available versions using:
>
> ```bash
> helm search repo ibm-helm/ibm-odm-prod -l
> ```
>
> - If you prefer to install ODM for prototyping (not for production) with the ODM PostgreSQL internal database. Get the [eks-nginx-values.yaml](./eks-nginx-values.yaml) file:
>
> ```bash
> helm install mycompany ibm-helm/ibm-odm-prod -f eks-nginx-values.yaml
> ```


## Track ODM usage

### Install the IBM Usage Metering service

IBM Usage Metering Service gathers metrics to monitor compliance and create reports. It captures business value metrics for auditing purposes and to visualize metric usage in reporting tools, and sends the information to IBM Software Central.

From ODM 9.6.0 onwards, it is required to install this metering service in the same namespace as ODM. ODM will systematically reports usage metrics to the metering service through a CronJob. If the service is not installed, the job fails when it runs. For more information about the installation and configuration of UMS, see [Installing the usage metering service](https://www.ibm.com/docs/en/odm/9.6.0?topic=production-installing-metering).

#### Expose IBM Usage Metering service using an ingress. 

- Edit the [nginx-ums-ingress.yaml](./nginx-ums-ingress.yaml) file and update `<UMS_NAMESPACE>` with the namespace that you installed UMS. Save the file.

- Run the command to create UMS's Ingress

```bash
kubectl apply -f nginx-ums-ingress.yaml
```

- Run the following command to see the status of Ingress `usage-metering-svc-ingress` instance:

```bash
$ kubectl get ingress
NAME                         CLASS   HOSTS   ADDRESS                                                                         PORTS   AGE
mycompany-odm-ingress        nginx   *       abcdefghijklmnopqrstuvqxyz-xxxxxxxyyyyyyzzzzzz.elb.<aws-region>.amazonaws.com   80      30m
usage-metering-svc-ingress   nginx   *       abcdefghijklmnopqrstuvqxyz-xxxxxxxyyyyyyzzzzzz.elb.<aws-region>.amazonaws.com   80      1m
```
- Note down the address of the `usage-metering-svc-ingress` instance. It will be use to retrieve the metering usage report in the next step.

#### Retrieve metering usage

To get the Usage Metering report, run the command below:

```bash
UMS_TOKEN=$(kubectl get secret ibm-usage-metering-upload-token -n "${NAMESPACE}" -o jsonpath='{.data.token}' 2>/dev/null | base64 -d || echo "")

curl -k --output report.zip \
        --header "Authorization: Bearer ${UMS_TOKEN}" \
        --url "https://abcdefghijklmnopqrstuvqxyz-xxxxxxxyyyyyyzzzzzz.elb.<aws-region>.amazonaws.com/ibm-usage-metering-instance/api/v1/snapshot"
```

### Install IBM License Service

Install the IBM License Service following *7.2* section of [Track ODM usage](README.md#72-install-the-ibm-license-service) step of the documentation.

#### Patch the IBM Licensing instance with Nginx configuration

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
NAME                             CLASS   HOSTS   ADDRESS                                                                         PORTS   AGE
ibm-licensing-service-instance   nginx   *       abcdefghijklmnopqrstuvqxyz-xxxxxxxyyyyyyzzzzzz.elb.<aws-region>.amazonaws.com   80      11m
```

You will be able to access the IBM License Service by retrieving the URL with this command:

```bash
export LICENSING_URL=$(kubectl get ingress ibm-licensing-service-instance -n ibm-licensing -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')/ibm-licensing-service-instance
export TOKEN=$(kubectl get secret ibm-licensing-token -n ibm-licensing -o jsonpath='{.data.token}' |base64 -d)
echo http://${LICENSING_URL}/status?token=${TOKEN}
```

You can access the `http://${LICENSING_URL}/status?token=${TOKEN}` URL to view the licensing usage. 

Otherwise, you can also retrieve the licensing report .zip file by running:

```bash
curl "http://${LICENSING_URL}/snapshot?token=${TOKEN}" --output report.zip
```

IBM License Service can optionally send collected license usage data directly to IBM Software Central. For more information about the configuration, see [Reporting license usage to IBM Software Central](https://www.ibm.com/docs/en/odm/9.6.0?topic=metering-reporting-license-usage-software-central).

If your IBM License Service instance is not running properly, refer to this [troubleshooting page](https://www.ibm.com/docs/en/cloud-paks/foundational-services/4.14.0?topic=service-troubleshooting-license).
