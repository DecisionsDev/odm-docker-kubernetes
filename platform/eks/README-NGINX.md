# Deploying IBM Operational Decision Manager with NGINX Ingress Controller on Amazon EKS

The aim of this complementary documentation is to explain how to replace the **AWS Load Balancer Controller** usage with an **NGINX Ingress Controller**.

## Prerequisites

You must have created an EKS cluster and set up your environment by following step 1 of [Deploying IBM Operational Decision Manager on Amazon EKS](README.md#1-prepare-your-environment-20-min).

## Provision an NGINX Ingress Controller

You can replace the [Provision an AWS Load Balancer Controller](README.md#d-provision-an-aws-load-balancer-controller) step by provisioning an NGINX Ingress Controller with the following commands.

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install my-odm-nginx ingress-nginx/ingress-nginx
```

For more information, refer to the [ingress-nginx readme](https://github.com/kubernetes/ingress-nginx/tree/main/charts/ingress-nginx#install-chart).

The `my-odm-nginx` service should have an available `External-IP` when you run the command:

```bash
kubectl get service my-odm-nginx-ingress-nginx-controller
```

You can then go back to the [main documentation](README.md#2-create-an-rds-database-10-min).

## Install an ODM release with NGINX Ingress Controller

During the helm install, you just have to replace  **eks-values.yaml** with **eks-nginx-values.yaml** that contains the relevant Ingress annotations:
`kubernetes.io/ingress.class: nginx` and `nginx.ingress.kubernetes.io/backend-protocol: https`

To install ODM with the AWS RDS PostgreSQL database created in [step 2](README.md#2-create-an-rds-database-10-min):

- Get the [eks-rds-nginx-values.yaml](./eks-rds-nginx-values.yaml) file and replace the following keys:
  - `<RDS_DB_ENDPOINT>`: your database server endpoint (of the form: `<INSTANCE_NAME>.xxxxxxxx.<REGION>.rds.amazonaws.com`)
  - `<RDS_DATABASE_NAME>`: the initial database name defined when creating the RDS database

```bash
helm install mycompany ibm-helm/ibm-odm-prod --version 23.1.0 -f eks-rds-nginx-values.yaml
```

> **Note**
> By default, NGINX does not enable sticky session. If you want to use sticky session to connect to DC, refer to [Using sticky session for Decision Center connection](../../contrib/sticky-session/README.md)

> **Note**
> If you prefer to install ODM for prototyping (not for production) with the ODM PostgreSQL internal database:
>
> - Get the [eks-nginx-values.yaml](./eks-nginx-values.yaml) file:
>
> ```bash
> helm install mycompany ibm-helm/ibm-odm-prod --version 23.1.0 -f eks-nginx-values.yaml
> ```

## Track ODM usage with the IBM License Service with NGINX Ingress Controller

Install the IBM License Service following a. section of [Track ODM usage with the IBM License Service](README.md#7-track-odm-usage-with-the-ibm-license-service) step of the documentation.

To create the IBM Licensing instance using NGINX, get the [licensing-instance-nginx.yaml](./licensing-instance-nginx.yaml) file and run the command:

```bash
kubectl create -f licensing-instance-nginx.yaml
```

You can then go back to the [main documentation](README.md#c-retrieving-license-usage) to retrieve license usage.
