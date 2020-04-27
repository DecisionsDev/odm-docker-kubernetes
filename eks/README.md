# Deploying IBM Operational Decision Manager on Amazon EKS

This project demonstrates how to deploy an IBM® Operational Decision Manager (ODM) clustered topology on the Amazon Elastic Kubernetes Service (EKS) cloud service. This deployment implements Kubernetes and Docker technologies. 

![Flow](./images/eks-schema.jpg)

The ODM Docker material is available in Passport Advantage. It includes Docker container images and Helm chart descriptors. 

## Included components
The project comes with the following components:
- [IBM Operational Decision Manager](https://www.ibm.com/support/knowledgecenter/en/SSQP76_8.10.x/com.ibm.odm.kube/kc_welcome_odm_kube.html)
- [Amazon Elastic Kubernetes Service (Amazon EKS)](https://aws.amazon.com/eks/)
- [Amazon Elastic Container Registry (Amazon ECR) ](https://aws.amazon.com/ecr/)
- [Amazon Relational Database Service (Amazon RDS) ](https://aws.amazon.com/rds/)
- [Amazon Application Load Balancer(ALB)](https://aws.amazon.com/elasticloadbalancing/?nc=sn&loc=0)

## Tested environment
The commands and tools have been tested on MacOS.

## Prerequisites
First, install the following software on your machine:
* [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)
* [Helm](https://github.com/helm/helm/releases)
* [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

Then, create an  [AWS Account](https://aws.amazon.com/getting-started/?sc_icontent=awssm-evergreen-getting_started&sc_iplace=2up&trk=ha_awssm-evergreen-getting_started&sc_ichannel=ha&sc_icampaign=evergreen-getting_started)

## Steps to deploy ODM on Kubernetes from Amazon EKS

1. [Prepare your environment (40 min)](#1-preparing-yourenvironment-40-min)
2. [Push the ODM images to the ECR registry - Optional (25 min)](#2-optional-push-odm-images-in-the-ecr-registry-25-min)
3. [Create an RDS database (20 min)](#3-create-an-rds-database-20-min)
4. [Manage a  digital certificate (10 min)](#4-manage-a-digital-certificate-10-min)
5. [Install an ODM release (10 min)](#5-install-an-ibm-operational-decision-manager-release-10-min)
6. [Access the ODM services](#6-accessing-services)

For more information, see [Getting started with Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html) 


### 1. Prepare your environment (40 min)
#### a. Create an EKS cluster (30 min)
    Follow the documentation [here](https://docs.aws.amazon.com/eks/latest/userguide/create-cluster.html)
     
> NOTE: Use Kubernetes version 1.15 or higher.
       
 
#### b. Set up your environment (10 min)
 - [Configure the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html)
    
   Example: 
   ```bash
   $ aws configure 
   ```

 - [Create a kubeconfig for Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/create-kubeconfig.html)
   
   Example:
   ```bash
   $  aws eks --region eu-west-3 update-kubeconfig --name odm
   ```

 - Check your environment
 
   If your environment is set up correctly, get the cluster information by running the following command:
   ```bash
   $ kubectl cluster-info
   ```
   
   Kubernetes master is running at https://xxxxxx.yl4.eu-west-3.eks.amazonaws.com
   
   CoreDNS is running at https://xxxxx.yl4.eu-west-3.eks.amazonaws.com/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
   
   Metrics-server is running at https://xxxxx.yl4.eu-west-3.eks.amazonaws.com/api/v1/namespaces/kube-system/services/https:metrics-server:/proxy

To further debug and diagnose cluster problems, run the command:
```
kubectl cluster-info dump
```

### 2. (Optional) Push the ODM images to the ECR registry (25 min)
The ODM images must be pushed to a registry that the EKS cluster can access. 

Here we use the [ECR registry](https://docs.aws.amazon.com/AmazonECR/latest/userguide/what-is-ecr.html).
If you use another public registry, skip this section and go to step 3.
 
#### a. Log in to the [ECR registry](https://docs.aws.amazon.com/AmazonECR/latest/userguide/Registries.html)
 
Example: 
```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin aws_account_id.dkr.ecr.us-east-1.amazonaws.com
```

#### b. Create the [ECR repository instances](https://docs.aws.amazon.com/AmazonECR/latest/userguide/repository-create.html)
 
> NOTE: You must create one repository per image.

Example:
```bash 
    $ aws ecr create-repository --repository-name odm-decisionrunner --image-scanning-configuration scanOnPush=true --region eu-west-3
    $ aws ecr create-repository --repository-name odm-decisionserverruntime --image-scanning-configuration scanOnPush=true --region eu-west-3
    $ aws ecr create-repository --repository-name odm-decisionserverconsole --image-scanning-configuration scanOnPush=true --region eu-west-3
    $ aws ecr create-repository --repository-name dbserver --image-scanning-configuration scanOnPush=true --region eu-west-3
```

#### c. Load the ODM images locally

 - Download one or more packages (.tgz archives) from [IBM Passport Advantage (PPA)](https://www-01.ibm.com/software/passportadvantage/pao_customer.html).  To view the full list of eAssembly installation images, refer to the [8.10.3 download document](https://www.ibm.com/support/pages/ibm-operational-decision-manager-v8103-download-document).
 
 - Extract the .tgz archives to your local file system.
     ```bash
     $ tar xzf <PPA-ARCHIVE>.tar.gz
     ```

- Check that you can run a docker command.
    ```bash
    $ docker ps
    ```

- Load the images to your local registry.
    ```bash
    $ foreach name ( `ls`)  echo $name && docker image load --input $name && end
    ```
  
   For more information, refer to the [ODM knowledge center](https://www.ibm.com/support/knowledgecenter/SSQP76_8.10.x/com.ibm.odm.kube/topics/tsk_config_odm_prod_kube.html).  
     
#### d. Tag and push the images to the ECR registry

- Tag the images to the ECR registry previously created

Example:
```bash
    $ docker tag odm-decisioncenter:8.10.3.0-amd64 <AWS-AccountId>.dkr.ecr.eu-west-3.amazonaws.com/odm/odm-decisioncenter:8.10.3.0-amd64
    $ docker tag odm-decisionserverruntime:8.10.3.0-amd64 <AWS-AccountId>.dkr.ecr.eu-west-3.amazonaws.com/odm-decisionserverruntime:8.10.3.0-amd64
    $ docker tag odm-decisionserverconsole:8.10.3.0-amd64 <AWS-AccountId>.dkr.ecr.eu-west-3.amazonaws.com/odm-decisionserverconsole:8.10.3.0-amd64
    $ docker tag odm-decisionrunner:8.10.3.0-amd64 <AWS-AccountId>.dkr.ecr.eu-west-3.amazonaws.com/odm-decisionrunner:8.10.3.0-amd64
    $ docker tag dbserver:8.10.3.0-amd64 <AWS-AccountId>.dkr.ecr.eu-west-3.amazonaws.com/dbserver:8.10.3.0-amd64
```
- Push the images to the ECR registry

Example: 
```bash
    $ docker push <AWS-AccountId>.dkr.ecr.eu-west-3.amazonaws.com/odm-decisioncenter:8.10.3.0-amd64
    $ docker push <AWS-AccountId>.dkr.ecr.eu-west-3.amazonaws.com/odm-decisionserverconsole:8.10.3.0-amd64
    $ docker push <AWS-AccountId>.dkr.ecr.eu-west-3.amazonaws.com/odm-decisionserverruntime:8.10.3.0-amd64
    $ docker push <AWS-AccountId>.dkr.ecr.eu-west-3.amazonaws.com/odm-decisionrunner:8.10.3.0-amd64
    $ docker push <AWS-AccountId>.dkr.ecr.eu-west-3.amazonaws.com/dbserver:8.10.3.0-amd64
```

#### e. Create a pull secret for the ECR registry  

```bash
$ kubectl create secret docker-registry ecrodm --docker-server=<AWS-AccountId>.dkr.ecr.eu-west-3.amazonaws.com --docker-username=AWS --docker-password=$(aws ecr get-login-password --region eu-west-3)
```
> NOTE: `ecrodm` is the name of the secret that is used to pull the images from EKS.


### 3. Create an RDS database (20 min)

This project uses PostgreSQL but the procedure is valid for any database supported by ODM.
 
To set up the database, follow the procedure described here [RDS PostgreSQL database](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Welcome.html). (?? give a more precise link)

> NOTE:  Make sure to:
> - Set up incoming trafic to allow connection from EKS (set vpc inboud rule to anywhere)
> - Create a database instance
> - Set the database password 

After the creation of the RDS PostgreSQL database, an endpoint gives access to this database instance. The enpoint is named  RDS_POSTGRESQL_SERVERNAME in the next sections.


### 4. Manage a  digital certificate (10 min)

#### a. (Optional) Generate a self-signed certificate 

If you do not have a trusted certificate, you can use OpenSSL and other cryptography and certificate management libraries to generate a .crt certificate file and a private key, to define the domain name, and to set the expiration date. The following command creates a self-signed certificate (.crt file) and a private key (.key file) that accept the domain name *.mycompany.com*. The expiration is set to 1000 days:

```bash
$ openssl req -x509 -nodes -days 1000 -newkey rsa:2048 -keyout mycompany.key -out mycompany.crt -subj "/CN=*.mycompany.com/OU=it/O=mycompany/L=Paris/C=FR"
```

#### b. Upload the certificate to the cluster on Amazon 

Run the following command:
```bash
$ aws iam upload-server-certificate --server-certificate-name mycompany --certificate-body file://mycompany.crt --private-key file://mycompany.key
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

> NOTE: "Arn": "arn:aws:iam::<AWS-AccountId>:server-certificate/mycompany" is used later to configure the Application Load Balancer (ALB).

#### c. Generate a JKS version of the certificate to be used in the ODM container 

```bash
$ openssl pkcs12 -export -passout pass:password -passin pass:password -inkey mycompany.key -in mycompany.crt -name mycompany -out mycompany.p12
$ keytool -importkeystore -srckeystore mycompany.p12 -srcstoretype PKCS12 -srcstorepass password -destkeystore mycompany.jks -deststoretype JKS -deststorepass password
$ keytool -import -v -trustcacerts -alias mycompany -file mycompany.crt -keystore truststore.jks -storepass password -noprompt
```


### 5. Install an IBM Operational Decision Manager release (10 min)


#### a. Prerequisites

- Create a database secret

To secure access to the database, you must create a secret that encrypts the database user and password before you install the Helm release.

```bash
$ kubectl create secret generic <odm-db-secret> --from-literal=db-user=<rds-postgresql-user-name> --from-literal=db-password=<rds-postgresql-password> 
```


Example:
```
$ kubectl create secret generic odm-db-secret --from-literal=db-user=postgres --from-literal=db-password=postgres
```

- Create a Kubernetes secret from the certificate generated in step 4.

```bash
$ kubectl create secret generic mycompany-secret --from-file=keystore.jks=mycompany.jks --from-file=truststore.jks=truststore.jks --from-literal=keystore_password=password --from-literal=truststore_password=password
```

The certificate must be the same as the one you used to enable TLS connections in your ODM release. For more information, see [Defining the security certificate](https://www.ibm.com/support/knowledgecenter/SSQP76_8.10.x/com.ibm.odm.icp/topics/tsk_replace_security_certificate.html?view=kc) and [Working with certificates and SSL](https://www.ibm.com/links?url=https%3A%2F%2Fdocs.oracle.com%2Fcd%2FE19830-01%2F819-4712%2Fablqw%2Findex.html).

#### b. Install an ODM Helm release

Install a Kubernetes release with the default configuration and a name of `my-odm-prod-release`.  

- Generate the template file

```bash
$ helm template <RELEASENAME> ibm-odm-prod --set image.repository=<IMAGE_REPOSITORY> --set image.tag=8.10.3.0 --set image.pullSecrets=ecrodm --set image.arch=amd64  --set externalDatabase.type=postgres --set externalDatabase.serverName=<RDS_POSTGRESQL_SERNAME>   --set externalDatabase.secretCredentials=<odm-db-secret> --set externalDatabase.port=5432  --set customization.securitySecretRef=mycompany-secret charts/ibm-odm-prod-2.3.0.tar.gz > postgresql.yaml 
```

Example:
```bash
helm template mycompany charts/ibm-odm-prod-2.3.0.tgz --set image.arch=amd64 --set image.repository=<AWS-AccountId>.dkr.ecr.eu-west-3.amazonaws.com --set image.tag=8.10.3.0 --set image.pullSecrets=ecrodm --set image.arch=amd64  --set externalDatabase.type=postgres --set externalDatabase.serverName=database-1.cv8ecjiejtnt.eu-west-3.rds.amazonaws.com   --set externalDatabase.secretCredentials=odm-db-secret --set externalDatabase.port=5432 --set customization.securitySecretRef=mycompany1-secret --set externalDatabase.databaseName=postgres > postgresql.yaml
```

> NOTES:
>  In ODM 8.10.3.0, a bug prevents the instanciation of the topology. To fix this problem:
> - Edit the postgresql.yaml file
> - Search "dc-jvm-options"
> - Delete the block: 
>  resources: 
> ```yaml
>   limits:
>       cpu: 2
>       memory: 4096Mi
>     requests:
>       cpu: 500m
>       memory: 1500Mi
> ```
> below
> ```yaml 
>   - name: lib-workarea-volume
>        emptyDir: {}
> ```


- Apply the template file

```bash
 $ kubectl apply -f postgresql.yaml
```

#### c. Check the topology
Run the following command to check the status of the pods that have been created: 
```bash
$ kubectl get pods
```


| *NAME* | *READY* | *STATUS* | *RESTARTS* | *AGE* |
|---|---|---|---|---|
| mycompany-odm-decisioncenter-*** | 1/1 | Running | 0 | 44m |  
| mycompany-odm-decisionrunner-*** | 1/1 | Running | 0 | 44m | 
| mycompany-odm-decisionserverconsole-*** | 1/1 | Running | 0 | 44m | 
| mycompany-odm-decisionserverruntime-*** | 1/1 | Running | 0 | 44m | 

Table 1. Status of pods


### 6. Access the ODM services  

This section explains how to implement an  Application Load Balancer (ALB) to expose the ODM services to Internet connectivity.

* Create an Application Load Balancer
* Implement an ingress for ODM services

#### a. Create an Application Load Balancer
Find more information about ALB here
https://docs.aws.amazon.com/elasticloadbalancing/latest/userguide/load-balancer-getting-started.html

The following steps allow you to create the ALB. Follow this [documentation](https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html#w243aac23b7c17c10b3b1)

- Create an IAM OIDC provider and associate it with your cluster. 

- Create an IAM policy called `ALBIngressControllerIAMPolicy` for the ALB Ingress Controller pod. 

- Create a Kubernetes service account named `alb-ingress-controller` in the kube-system namespace, a cluster role, and a cluster role binding for the ALB Ingress Controller.

- Create an IAM role for the ALB ingress controller and attach the role to the service account created in the previous step

- Deploy the ALB Ingress Controller with the following command:

```bash
$ curl  
https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/v1.1.4/docs/examples/alb-ingress-controller.yaml
  > alb-ingress-controller.yaml
```

Edit alb-ingress-controller.yaml and change at least
```yaml
  - --cluster-name=<EKS>
  - --ingress-class=alb"
```
For more information, refer to the https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html#w243aac23b7c17c10b3b1. 

Then, deploy the ALB ingress controller.
```bash
$ kubectl apply -f alb-ingress-controller.yaml 
```

#### b. Deploy the ingress service for ODM

- Write the ingress descriptor

You must define an ingress to route your request to the ODM services.

Here is a sample descriptor to implement the ingress:

Ingress descriptor:
```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: mycompany
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS":443}]'
    alb.ingress.kubernetes.io/actions.ssl-redirect: '{"Type": "redirect", "RedirectConfig": { "Protocol": "HTTPS", "Port": "443", "StatusCode": "HTTP_301"}}'
    alb.ingress.kubernetes.io/backend-protocol: "HTTPS"
    alb.ingress.kubernetes.io/certificate-arn: "arn:aws:iam::<AWS-AccountId>:server-certificate/mycompany"
spec:
  rules:
  - http:
      paths:
      - path: /*
        backend:
          serviceName: ssl-redirect
          servicePort: use-annotation
      - path: /res/*
        backend:
          serviceName: mycompany-odm-decisionserverconsole
          servicePort: 9443
      - path: /decisioncenter*/*
        backend:
          serviceName: mycompany-odm-decisioncenter
          servicePort: 9453
      - path: /DecisionService/*
        backend:
          serviceName: mycompany-odm-decisionserverruntime
          servicePort: 9443
      - path: /DecisionRunner/*
        backend:
          serviceName: mycompany-odm-decisionrunner
          servicePort: 9443
```
Source file [ingress-mycompany.yaml](ingress-mycompany.yaml)

- Deploy the ingress controller 
```bash
kubectl apply -f ingress-mycompany.yaml 
```

After a couple of minutes, the  ALB reflects the ingress configuration. Then you can access the ODM services by retrieving the URL with this command:

```bash
kubectl get ingress mycompany| awk '{print $3}' | tail -1)
```

With this ODM topology in place, you can access web applications to author, deploy, and test your rule-based decision services.


The services are accessible from the following URLs:

| *Component* | *URL* | *Username/Password* |
|---|---|---|
| Decision Center | https://$ROOTURL/decisioncenter/ | odmAdmin/odmAdmin | 
| Decision Server Console |https://$ROOTURL/res/| odmAdmin/odmAdmin |
| Decision Server Runtime | https://$ROOTURL/DecisionService/ | odmAdmin/odmAdmin | 



## Troubleshooting

If your microservice instances are not running properly, check the logs by running the following command:
```
kubectl logs <your-pod-name>
```


## References
https://aws.amazon.com/blogs/opensource/network-load-balancer-nginx-ingress-controller-eks/


# License
[Apache 2.0](LICENSE)
