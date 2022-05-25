# Deploying IBM Operational Decision Manager on Amazon EKS

This project demonstrates how to deploy an IBM® Operational Decision Manager (ODM) clustered topology on the Amazon Elastic Kubernetes Service (EKS) cloud service. This deployment implements Kubernetes and Docker technologies.

<img src="./images/eks-schema.jpg" alt="Flow" width="2050" height="600" />

The ODM on Kubernetes material is available in [IBM Entitled Registry](https://www.ibm.com/cloud/container-registry) for the Docker images, and the [IBM Helm charts repository](https://github.com/IBM/charts) for the ODM Helm chart.

## Included components
The project uses the following components:
- [IBM Operational Decision Manager](https://www.ibm.com/docs/en/odm/8.11.0)
- [Amazon Elastic Kubernetes Service (Amazon EKS)](https://aws.amazon.com/eks/)
- [Amazon Elastic Container Registry (Amazon ECR)](https://aws.amazon.com/ecr/)
- [Amazon Relational Database Service (Amazon RDS)](https://aws.amazon.com/rds/)
- [AWS Application Load Balancer (ALB)](https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html)

## Tested environment
The commands and tools have been tested on Linux and macOS.

## Prerequisites
First, install the following software on your machine:
* [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)
* [Helm v3](https://helm.sh/docs/intro/install/)
* [Kubectl](https://kubernetes.io/docs/tasks/tools/)

Then, create an [AWS Account](https://aws.amazon.com/getting-started/).

## Steps to deploy ODM on Kubernetes from Amazon EKS

1. [Prepare your environment (40 min)](#1-prepare-your-environment-40-min)
2. [Prepare your environment for the ODM installation (25 min)](#2-prepare-your-environment-for-the-odm-installation-25-min)
3. [(Optional) Create an RDS database (Optional 20 min)](#3-optional-create-an-rds-database-20-min)
4. [Manage a  digital certificate (10 min)](#4-manage-a-digital-certificate-10-min)
5. [Install an ODM release (10 min)](#5-install-an-ibm-operational-decision-manager-release-10-min)
6. [Access the ODM services](#6-access-the-odm-services)
7. [Install the IBM License Service](#7-install-the-ibm-license-service)

For more information, see [Getting started with Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html)

### 1. Prepare your environment (40 min)

#### a. Create an EKS cluster (30 min)

Create an EKS cluster following [this documentation](https://docs.aws.amazon.com/eks/latest/userguide/create-cluster.html)

Follow the configuration steps by taking into account the following points :
- Choose *Public* as **Cluster endpoint access** as we need an internet access to at least the Decision Center and RES consoles
- As explained in [Application load balancing on Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html), the selected subnets must also enable a public access as the AWS service will be available from internet.
  At least 1 subnet should be tagged with the following tags:
  ```bash
  key: kubernetes.io/cluster/<cluster-name> | Value: shared
  key: kubernetes.io/role/elb | Value: 1
  ```

When the EKS cluster is created and active, add a *Node Group*:
- From the EKS dashboard, select the cluster and click on the **Add Node Group** button from the **Configuration** > **Compute** tab
- For this demo, we selected as **Instance types** a `t3.xlarge` instance (vCPU: Up to 4 vCPUs / Memory: 16.0 GiB / Network: Moderate / MaxENI:4 / Max IPs: 60) obviously, the capacity must be adapted to your usage

> NOTE: Use Kubernetes version 1.21 or higher.
 
#### b. Set up your environment (10 min)
 - [Configure the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html)

   ```bash
   aws configure 
   ```

 - [Create a kubeconfig for Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/create-kubeconfig.html)

   ```bash
   aws eks --region <region> update-kubeconfig --name odm
   ```

 - Check your environment

   If your environment is set up correctly, you should be able to get the cluster information by running the following command:

   ```bash
   kubectl cluster-info
   Kubernetes master is running at https://xxxxxx.yl4.<region>.eks.amazonaws.com
   CoreDNS is running at https://xxxxx.yl4.<region>.eks.amazonaws.com/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

   Metrics-server is running at https://xxxxx.yl4.<region>.eks.amazonaws.com/api/v1/namespaces/kube-system/services/https:metrics-server:/proxy
   ```

To further debug and diagnose cluster problems, run the command:
```
kubectl cluster-info dump
```
#### c. Provision an AWS Load Balancer Controller

Provision an AWS Load Balancer Controller to your EKS cluster following this [documentation](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html).

The AWS Load Balancer Controller creates Application Load Balancers (ALBs) and the necessary supporting AWS resources whenever a Kubernetes Ingress resource is created on the cluster with the `kubernetes.io/ingress.class: alb` annotation.

> NOTE: If you prefer to use the NGINX Ingress Controller instead of the AWS Load Balancer Controller, refer to [Deploying IBM Operational Decision Manager with NGINX Ingress Controller on Amazon EKS](README-NGINX.md)

### 2. Prepare your environment for the ODM installation (25 min)

To get access to the ODM material, you must have an IBM entitlement registry key to pull the images from the IBM Entitled registry. 
It's what will be used in the next step of this tutorial.

But, you can also download the ODM on Kubernetes package (.tgz file) from Passport Advantage® (PPA) and then push the contained images to the EKS Container Registry (ECR). If you prefer to manage ODM images this way, find the explanation [here](README-ECR-REGISTRY.md) 

#### a. Retrieve your entitled registry key
  - Log in to [MyIBM Container Software Library](https://myibm.ibm.com/products-services/containerlibrary) with the IBMid and password that are associated with the entitled software.

  - In the Container software library tile, verify your entitlement on the View library page, and then go to *Get entitlement key* to retrieve the key.

#### b. Create a pull secret by running a kubectl create secret command.

```console
kubectl create secret docker-registry my-odm-docker-registry --docker-server=cp.icr.io \
    --docker-username=cp --docker-password="<API_KEY_GENERATED>" --docker-email=<USER_EMAIL>
```

where:
* <API_KEY_GENERATED> is the entitlement key from the previous step. Make sure you enclose the key in double-quotes.
* <USER_EMAIL> is the email address associated with your IBMid.

> Note: The `cp.icr.io` value for the docker-server parameter is the only registry domain name that contains the images. You must set the docker-username to `cp` to use an entitlement key as docker-password.

The my-odm-docker-registry secret name is already used for the `image.pullSecrets` parameter when you run a helm install of your containers. The `image.repository` parameter is also set by default to `cp.icr.io/cp/cp4a/odm`.

#### c. Add the public IBM Helm charts repository:

```console
helm repo add ibmcharts https://raw.githubusercontent.com/IBM/charts/master/repo/entitled
helm repo update
```

#### d. Check you can access ODM's chart

```console
helm search repo ibm-odm-prod
NAME                  	CHART VERSION	APP VERSION	DESCRIPTION                     
ibmcharts/ibm-odm-prod	22.1.0       	8.11.0.1   	IBM Operational Decision Manager
```

### 3. (Optional) Create an RDS database (20 min)

ODM on K8s is provided with a ready to use internal database based on PostgreSQL that can be used empty or with pre-populated samples.
If you want to install an ODM demo quickly, you can use this internal database.

But, if you prefer to be more on a entreprise mode, follow the next step explaining how to use an AWS RDS database.   

This following step is using PostgreSQL but the procedure is valid for any database supported by ODM.

To set up the database, follow the procedure described here [RDS PostgreSQL database](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_CreateDBInstance.html).

> NOTE:  Make sure to:
> - Create the RDS database in the same cluster region for performance reason (mainly for Decision Center schema creation time)
> - Take a PostgreSQL v13.X version (tutorial was realized with v13.6)
> - Set up incoming traffic to allow connection from EKS (set vpc inboud rule to anywhere)
> - Create a database instance by setting an *Initial database name*
> - Set a database *Master password*

Once the RDS PostgreSQL database is available, take a note of the database endpoint. It will be referred as `RDS_POSTGRESQL_SERVERNAME` in the next sections.

To secure access to the database, you must create a secret that encrypts the database user and password before you install the Helm release.

```bash
kubectl create secret generic <odm-db-secret> \
--from-literal=db-user=<rds-postgresql-user-name> \
--from-literal=db-password=<rds-postgresql-password>
```

Example:
```
kubectl create secret generic odm-db-secret \
--from-literal=db-user=postgres \
--from-literal=db-password=postgres
```

### 4. Manage a  digital certificate (10 min)

#### a. (Optional) Generate a self-signed certificate

If you do not have a trusted certificate, you can use OpenSSL and other cryptography and certificate management libraries to generate a `.crt` certificate file and a private key, to define the domain name, and to set the expiration date.
The following command creates a self-signed certificate (.crt file) and a private key (.key file) that accept the domain name *.mycompany.com*. The expiration is set to 1000 days:

```bash
openssl req -x509 -nodes -days 1000 -newkey rsa:2048 -keyout mycompany.key \
  -out mycompany.crt -subj "/CN=*.mycompany.com/OU=it/O=mycompany/L=Paris/C=FR"
```

#### b. Upload the certificate to AWS IAM service

Run the following command:
```bash
aws iam upload-server-certificate --server-certificate-name mycompany \
  --certificate-body file://mycompany.crt --private-key file://mycompany.key
```

The output of the command is:
```yaml
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

> NOTE: "Arn": "arn:aws:iam::\<AWS-AccountId>:server-certificate/mycompany" is used later to configure the Ingress ALB certificate annotation.

### 5. Install an IBM Operational Decision Manager release (10 min)

Install a Kubernetes release with the default configuration and a name of `mycompany`.  

If you want to install ODM as a demo mode with the ODM postgreSQL internal data base :

- Get the [eks-values.yaml](./eks-values.yaml) file and replace the following keys:
  - `<AWS-AccountId>` is your AWS Account Id

```bash
helm install mycompany ibmcharts/ibm-odm-prod --version 22.1.0 -f eks-values.yaml
```

If you want to install ODM with the AWS RDS postgreSQL database created in [step 3](#3-optional-create-an-rds-database-20-min) :

- Get the [eks-rds-values.yaml](./eks-rds-values.yaml) file and replace the following keys:
  - `<AWS-AccountId>` is your AWS Account Id
  - `<RDS_DB_ENDPOINT>` is your database server endpoint (of the form: `db-server-name-1.********.<region>.rds.amazonaws.com`)
  - `<RDS_DATABASE_NAME>` is the initial database name defined when creating the RDS database


```bash
helm install mycompany ibmcharts/ibm-odm-prod --version 22.1.0 -f eks-rds-values.yaml
```

> NOTE: If you choose to use the NGINX Ingress Controller, refer to [Install an ODM release with NGINX Ingress Controller](README-NGINX.md#install-an-odm-release-with-nginx-ingress-controller).


#### c. Check the topology
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

Table 1. Status of pods


### 6. Access the ODM services  

This section explains how to implement an Application Load Balancer (ALB) to expose the ODM services to Internet connectivity.
After a couple of minutes, the  ALB reflects the ingress configuration. Then you can access the ODM services by retrieving the URL with this command:

```bash
export ROOTURL=$(kubectl get ingress mycompany-odm-ingress | awk '{print $4}' | tail -1)
```
If ROOTURL is empty take a look the [troubleshooting](#troubleshooting) section.

With this ODM topology in place, you can access web applications to author, deploy, and test your rule-based decision services.

The services are accessible from the following URLs:

| *Component* | *URL* | *Username/Password* |
|---|---|---|
| Decision Center | https://$ROOTURL/decisioncenter | odmAdmin/odmAdmin |
| Decision Center Swagger | https://$ROOTURL/decisioncenter-api | odmAdmin/odmAdmin |
| Decision Server Console |https://$ROOTURL/res| odmAdmin/odmAdmin |
| Decision Server Runtime | https://$ROOTURL/DecisionService | odmAdmin/odmAdmin |
| Decision Runner | https://$ROOTURL/DecisionRunner | odmAdmin/odmAdmin |

### 7. Track ODM usage with the IBM License Service

#### a. Install the IBM License Service

Follow the **Installation** section of the [Manual installation without the Operator Lifecycle Manager (OLM)](https://github.com/IBM/ibm-licensing-operator/blob/latest/docs/Content/Install_without_OLM.md)

> NOTE: The instance created in the documentation is configured to use ngnix and **will not work** in this example using ALB.

#### b. Create an IBM Licensing instance using ALB

Get the [alb-ibmlicensing-instance.yaml](./alb-ibmlicensing-instance.yaml) file and execute the command :
```bash
kubectl apply -f alb-ibmlicensing-instance.yaml
```

#### c. Retrieving license usage

After a couple of minutes, the ALB reflects the ingress configuration and you will be able to access the IBM License Service by retrieving the URL with this command:
```bash
export LICENSING_URL=$(kubectl get ingress ibm-licensing-service-instance -n ibm-common-services | awk '{print $4}' | tail -1)
export TOKEN=$(oc get secret ibm-licensing-token -o jsonpath={.data.token} -n ibm-common-services | base64 -d)
```
If LICENSING_URL is empty take a look the [troubleshooting](#troubleshooting) section.

You can access the `http://$LICENSING_URL/status?token=$TOKEN` url to view the licensing usage or retrieve the licensing report zip file by running:
```bash
curl -v http://$LICENSING_URL/snapshot?token=$TOKEN --output report.zip
```

## Troubleshooting

If your ODM instances are not running properly, check the logs by running the following command:
```
kubectl logs <your-pod-name>
```

If the ROOTURL is empty, it means there is no address delivered to the ODM ingress instance (mycompany-odm-ingress) by the ALB controller.
So, you can check the ALB controller logs with :
```
kubectl logs -n kube-system deployment.apps/aws-load-balancer-controller
```

Check the ALB configuration if you get a message like :
"msg"="Reconciler error" "error"="failed to reconcile ...

## References
https://aws.amazon.com/blogs/opensource/network-load-balancer-nginx-ingress-controller-eks/

# License
[Apache 2.0](/LICENSE)
