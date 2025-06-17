# Deploying IBM Operational Decision Manager with NGINX Ingress Controller on Amazon EKS

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

## Track ODM usage with the IBM License Service with NGINX Ingress Controller

Install the IBM License Service following *7a.* section of [Track ODM usage with the IBM License Service](README.md#7-track-odm-usage-with-the-ibm-license-service) step of the documentation.

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
NAME                             CLASS   HOSTS   ADDRESS                                                                         PORTS   AGE
ibm-licensing-service-instance   nginx   *       abcdefghijklmnopqrstuvqxyz-xxxxxxxyyyyyyzzzzzz.elb.<aws-region>.amazonaws.com   80      11m
```

You will be able to access the IBM License Service by retrieving the URL with this command:

```bash
export LICENSING_URL=$(kubectl get ingress ibm-licensing-service-instance -n ibm-licensing -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')/ibm-licensing-service-instance
export TOKEN=$(kubectl get secret ibm-licensing-token -n ibm-licensing -o jsonpath='{.data.token}' |base64 -d)
```

You can access the `http://${LICENSING_URL}/status?token=${TOKEN}` URL to view the licensing usage. 

Otherwise, you can also retrieve the licensing report .zip file by running:

```bash
curl "http://${LICENSING_URL}/snapshot?token=${TOKEN}" --output report.zip
```

If your IBM License Service instance is not running properly, refer to this [troubleshooting page](https://www.ibm.com/docs/en/cloud-paks/foundational-services/4.12.0?topic=service-troubleshooting-license).
