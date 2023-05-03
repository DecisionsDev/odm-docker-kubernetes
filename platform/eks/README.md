# Deploying IBM Operational Decision Manager on Amazon EKS

This project demonstrates how to deploy an IBM® Operational Decision Manager (ODM) clustered topology on the Amazon Elastic Kubernetes Service (EKS) cloud service. This deployment implements Kubernetes and Docker technologies.

<img src="./images/eks-schema.jpg" alt="Flow" width="2050" height="600" />

The ODM on Kubernetes Docker images are available in the [IBM Entitled Registry](https://www.ibm.com/cloud/container-registry). The ODM Helm chart is available in the [IBM Helm charts repository](https://github.com/IBM/charts).

## Included components
The project uses the following components:
- [IBM Operational Decision Manager](https://www.ibm.com/docs/en/odm/8.12.0)
- [Amazon Elastic Kubernetes Service (Amazon EKS)](https://aws.amazon.com/eks/)
- [Amazon Relational Database Service (Amazon RDS)](https://aws.amazon.com/rds/)
- [AWS Application Load Balancer (ALB)](https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html)

## Tested environment
The commands and tools have been tested on Linux and macOS.

## Prerequisites
First, install the following software on your machine:
* [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)
* [eksctl](https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html)
* [Helm v3](https://helm.sh/docs/intro/install/)
* [kubectl](https://kubernetes.io/docs/tasks/tools/)

Then, create an [AWS Account](https://aws.amazon.com/getting-started/).

## Steps to deploy ODM on Kubernetes from Amazon EKS
<!-- TOC depthFrom:3 depthTo:3 withLinks:1 updateOnSave:1 orderedList:0 -->

- [1. Prepare your environment (40 min)](#1-prepare-your-environment-40-min)
- [2. Create an RDS database (20 min)](#2-create-an-rds-database-20-min)
- [3. Prepare your environment for the ODM installation (25 min)](#3-prepare-your-environment-for-the-odm-installation-25-min)
- [4. Manage a  digital certificate (10 min)](#4-manage-a-digital-certificate-10-min)
- [5. Install an IBM Operational Decision Manager release (10 min)](#5-install-an-ibm-operational-decision-manager-release-10-min)
- [6. Access the ODM services](#6-access-the-odm-services)
- [7. Track ODM usage with the IBM License Service](#7-track-odm-usage-with-the-ibm-license-service)

<!-- /TOC -->

For more information, see [Getting started with Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html)

### 1. Prepare your environment (40 min)

#### a. Configure the `aws` CLI

Set up your environment by [configuring the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html):

```bash
aws configure 
```

#### b. Create an EKS cluster (30 min)

```bash
eksctl create cluster <CLUSTER_NAME> --version 1.26 --alb-ingress-access

```

> **Note**
> Use the latest kubernetes version available in AWS. Refer to [Amazon EKS Kubernetes versions](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html).

For more information, refer to [Creating an Amazon EKS cluster](https://docs.aws.amazon.com/eks/latest/userguide/create-cluster.html).

#### c. Set up your environment (10 min)

If your environment is set up correctly, you should be able to get the cluster information by running the following command:

```bash
$ kubectl cluster-info
Kubernetes control plane is running at https://xxxxxxxx.<REGION>.eks.amazonaws.com
CoreDNS is running at https://xxxxxxxx.<REGION>.eks.amazonaws.com/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

#### d. Provision an AWS Load Balancer Controller

The AWS Load Balancer Controller creates Application Load Balancers (ALBs) and the necessary supporting AWS resources whenever a Kubernetes Ingress resource is created on the cluster with the `kubernetes.io/ingress.class: alb` annotation.

Provision an AWS Load Balancer Controller to your EKS cluster:

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=<CLUSTER_NAME>
```

For more information, refer to [Installing the AWS Load Balancer Controller add-on](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html).

> **Note**
> If you prefer to use the NGINX Ingress Controller instead of the AWS Load Balancer Controller, refer to [Deploying IBM Operational Decision Manager with NGINX Ingress Controller on Amazon EKS](README-NGINX.md)

### 2. Create an RDS database (20 min)

#### a. Create the database instance

The following step uses PostgreSQL but the procedure is valid for any database supported by ODM:

```bash
aws rds create-db-instance --db-instance-identifier <INSTANCE_NAME> \
  --engine postgres --db-instance-class db.t3.large --allocated-storage 250 \
  --master-username <PG_USERNAME> --master-user-password <PG_PASSWORD> \
  --db-name <RDS_DATABASE_NAME>
```

For more information, refer to [Creating an Amazon RDS DB instance](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_CreateDBInstance.html).

#### b. Get the database endpoint

Wait a few minutes for the RDS PostgreSQL database to be created and take note of the its public endpoint. It will be referred to as `RDS_DB_ENDPOINT` in the next sections.

Use the following command to get the RDS instance's endpoint:

```bash
aws rds describe-db-instances | jq -r ".DBInstances[].Endpoint.Address"
```

> **Note**
> If `jq` is not installed, remove the second part above and look for the endpoint address; it looks like `<INSTANCE_NAME>.xxxxxxxx.<REGION>.rds.amazonaws.com`.)

#### c. Create the database secret

To secure access to the database, you must create a secret that encrypts the database user and password before you install the Helm release.

```bash
kubectl create secret generic odm-db-secret \
        --from-literal=db-user=<PG_USERNAME> \
        --from-literal=db-password=<PG_PASSWORD>
```

> **Note**
> ODM on Kubernetes is provided with an internal PostgreSQL database that can be used empty or with pre-populated samples.
> If you want to install an ODM demo quickly, you can use this internal database. It is dedicated to prototyping, not for production.

### 3. Prepare your environment for the ODM installation (25 min)

To get access to the ODM material, you must have an IBM entitlement key to pull the images from the IBM Entitled registry.
This is what will be used in the next step of this tutorial.

You can also download the ODM on Kubernetes package (.tgz file) from Passport Advantage® (PPA), and then push the contained images to the EKS Container Registry (ECR). If you prefer to manage the ODM images this way, see the details [here](README-ECR-REGISTRY.md)

#### a. Retrieve your entitled registry key

- Log in to [MyIBM Container Software Library](https://myibm.ibm.com/products-services/containerlibrary) with the IBMid and password that are associated with the entitled software.

- In the Container software library tile, verify your entitlement on the View library page, and then go to *Get entitlement key* to retrieve the key.

#### b. Create a pull secret by running the kubectl create secret command

```console
kubectl create secret docker-registry my-odm-docker-registry --docker-server=cp.icr.io \
    --docker-username=cp --docker-password="<ENTITLEMENT_KEY>" --docker-email=<USER_EMAIL>
```

Where:
* <ENTITLEMENT_KEY> is the entitlement key from the previous step. Make sure you enclose the key in double-quotes.
* <USER_EMAIL> is the email address associated with your IBMid.

> **Note**
> The `cp.icr.io` value for the docker-server parameter is the only registry domain name that contains the images. You must set the docker-username to `cp` to use an entitlement key as docker-password.

The my-odm-docker-registry secret name is already used for the `image.pullSecrets` parameter when you run a helm install of your containers. The `image.repository` parameter is also set by default to `cp.icr.io/cp/cp4a/odm`.

#### c. Add the public IBM Helm charts repository

```console
helm repo add ibm-helm https://raw.githubusercontent.com/IBM/charts/master/repo/ibm-helm
helm repo update
```

#### d. Check your access to the ODM chart

```console
$ helm search repo ibm-odm-prod
NAME                             	CHART VERSION	APP VERSION	DESCRIPTION
ibm-helm/ibm-odm-prod           	22.2.0       	8.11.1.0   	IBM Operational Decision Manager
```

### 4. Manage a  digital certificate (10 min)

#### a. (Optional) Generate a self-signed certificate

If you do not have a trusted certificate, you can use OpenSSL and other cryptography and certificate management libraries to generate a `.crt` certificate file and a private key, to define the domain name, and to set the expiration date.
The following command creates a self-signed certificate (.crt file) and a private key (.key file) that accept the domain name *.mycompany.com*. The expiration is set to 1000 days:

```bash
openssl req -x509 -nodes -days 1000 -newkey rsa:2048 -keyout mycompany.key \
  -out mycompany.crt -subj "/CN=*.mycompany.com/OU=it/O=mycompany/L=Paris/C=FR"
```

#### b. Upload the certificate to the AWS IAM service

Run the following command:
```bash
aws iam upload-server-certificate --server-certificate-name mycompany \
  --certificate-body file://mycompany.crt --private-key file://mycompany.key
```

The output of the command is:
```json
{
  "ServerCertificateMetadata": {
    "Path": "/",
    "ServerCertificateName": "mycompany",
    "ServerCertificateId": "ASCA4GCFYJYN5C35DTU5X",
    "Arn": "arn:aws:iam::<AWS-AccountId>:server-certificate/mycompany",
    "UploadDate": "2020-04-08T13:52:49+00:00",
    "Expiration": "2023-01-03T13:39:08+00:00"
  }
}
```

> **Note** 
> "Arn": "arn:aws:iam::\<AWS-AccountId\>:server-certificate/mycompany" is used later to configure the Ingress ALB certificate annotation.

### 5. Install an IBM Operational Decision Manager release (10 min)

Install a Kubernetes release with the default configuration and a name of `mycompany`.

To install ODM with the AWS RDS PostgreSQL database created in [step 3](#3-create-an-rds-database-20-min):

- Get the [eks-rds-values.yaml](./eks-rds-values.yaml) file and replace the following keys:
  - `<AWS-AccountId>` is your AWS Account Id
  - `<RDS_DB_ENDPOINT>` is your database server endpoint
  - `<RDS_DATABASE_NAME>` is the initial database name defined when creating the RDS database

```bash
helm install mycompany ibm-helm/ibm-odm-prod --version 22.2.0 -f eks-rds-values.yaml
```

> **Note**
> If you prefer to install ODM to prototype (not for production purpose) with the ODM PostgreSQL internal database:
>
> - Get the [eks-values.yaml](./eks-values.yaml) file and replace the following key:
>   - `<AWS-AccountId>` is your AWS Account Id
>
>```bash
>helm install mycompany ibm-helm/ibm-odm-prod --version 22.2.0 -f eks-values.yaml
>```

> **Note**
> If you choose to use the NGINX Ingress Controller, refer to [Install an ODM release with NGINX Ingress Controller](README-NGINX.md#install-an-odm-release-with-nginx-ingress-controller).


#### Check the topology
Run the following command to check the status of the pods that have been created: 
```bash
kubectl get pods
```

| *NAME* | *READY* | *STATUS* | *RESTARTS* | *AGE* |
|---|---|---|---|---|
| mycompany-odm-decisioncenter-*** | 1/1 | Running | 0 | 44m |
| mycompany-odm-decisionrunner-*** | 1/1 | Running | 0 | 44m |
| mycompany-odm-decisionserverconsole-*** | 1/1 | Running | 0 | 44m |
| mycompany-odm-decisionserverruntime-*** | 1/1 | Running | 0 | 44m |

### 6. Access the ODM services  

This section explains how to implement an Application Load Balancer (ALB) to expose the ODM services to Internet connectivity.

After a couple of minutes, the ALB reflects the Ingress configuration. You can then access the ODM services by retrieving the URL with this command:

```bash
export ROOTURL=$(kubectl get ingress mycompany-odm-ingress --no-headers |awk '{print $4}')
```

If ROOTURL is empty, take a look at the [troubleshooting](#troubleshooting) section.

With this ODM topology in place, you can access web applications to author, deploy, and test your rule-based decision services.

The ODM services are accessible from the following URLs:

| *Component* | *URL* | *Username/Password* |
|---|---|---|
| Decision Center | https://${ROOTURL}/decisioncenter | odmAdmin/odmAdmin |
| Decision Center Swagger | https://${ROOTURL}/decisioncenter-api | odmAdmin/odmAdmin |
| Decision Server Console |https://${ROOTURL}/res| odmAdmin/odmAdmin |
| Decision Server Runtime | https://${ROOTURL}/DecisionService | odmAdmin/odmAdmin |
| Decision Runner | https://${ROOTURL}/DecisionRunner | odmAdmin/odmAdmin |

### 7. Track ODM usage with the IBM License Service

#### a. Install the IBM License Service

Follow the **Installation** section of the [Manual installation without the Operator Lifecycle Manager (OLM)](https://www.ibm.com/docs/en/cpfs?topic=software-manual-installation-without-operator-lifecycle-manager-olm) documentation.

> **Warning**
> Make sure you do not follow the **Creating an IBM Licensing instance** part!

#### b. Create the IBM Licensing instance

Get the [licensing-instance.yaml](./licensing-instance.yaml) file and run the command:

```
kubectl create -f licensing-instance.yaml
```

> **Note**
> You can find more information and use cases on [this page](https://www.ibm.com/docs/en/cpfs?topic=software-configuration).

#### c. Retrieving license usage

After a couple of minutes, the ALB reflects the Ingress configuration. You will be able to access the IBM License Service by retrieving the URL with this command:

```bash
export LICENSING_URL=$(kubectl get ingress ibm-licensing-service-instance -n ibm-common-services -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
export TOKEN=$(kubectl get secret ibm-licensing-token -n ibm-common-services -o jsonpath='{.data.token}' |base64 -d)
```

If LICENSING_URL is empty, take a look at the [troubleshooting](#troubleshooting) section.

You can access the `http://${LICENSING_URL}/status?token=${TOKEN}` URL to view the licensing usage or retrieve the licensing report .zip file by running:

```bash
curl "http://${LICENSING_URL}/snapshot?token=${TOKEN}" --output report.zip
```

## Troubleshooting

If your ODM instances are not running properly, check the logs with the following command:
```
kubectl logs <your-pod-name>
```

If the ROOTURL is empty, it means that the ALB controller did not deliver an address to the ODM Ingress instance (mycompany-odm-ingress).
Check the ALB controller logs with the following command:
```
kubectl logs -n kube-system deployment.apps/aws-load-balancer-controller
```

Check the ALB configuration if you get a message like:
"msg"="Reconciler error" "error"="failed to reconcile ...

Reference: https://aws.amazon.com/blogs/opensource/network-load-balancer-nginx-ingress-controller-eks/

## Getting Started with IBM Operational Decision Manager for Containers

Get hands-on experience with IBM Operational Decision Manager in a container environment by following this [Getting started tutorial](https://github.com/DecisionsDev/odm-for-container-getting-started/blob/master/README.md).

# License
[Apache 2.0](/LICENSE)
