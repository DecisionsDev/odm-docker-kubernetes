# Deploying IBM Operational Decision Manager on Amazon EKS

This project demonstrates how to deploy an IBM® Operational Decision Manager (ODM) clustered topology on the Amazon Elastic Kubernetes Service (EKS) cloud service. This deployment implements Kubernetes and Docker technologies. 

The ODM Docker material is available in Passport Advantage. It includes Docker container images and Helm chart descriptors. 

![Flow](./images/eks-schema.jpg)

## Included components
This project comes with the following components:
- [IBM Operational Decision Manager](https://www.ibm.com/support/knowledgecenter/en/SSQP76_8.10.x/com.ibm.odm.kube/kc_welcome_odm_kube.html)
- [Amazon Elastic Kubernetes Service (Amazon EKS)](https://aws.amazon.com/eks/)
- [Amazon Elastic Container Registry (ECR) ](https://aws.amazon.com/ecr/)
- [Amazon Relational Database Service (Amazon RDS) ](https://aws.amazon.com/rds/)
- [Application Load Balancer(ELB)](https://aws.amazon.com/elasticloadbalancing/?nc=sn&loc=0)

## Tested environment
The commands and tools were tested on MacOS.

## Prerequisites
First, install the following software on your machine:
* [AWS Cli](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)
* [Helm](https://github.com/helm/helm/releases)
* [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

Then, create an  [AWS Account](https://aws.amazon.com/getting-started/?sc_icontent=awssm-evergreen-getting_started&sc_iplace=2up&trk=ha_awssm-evergreen-getting_started&sc_ichannel=ha&sc_icampaign=evergreen-getting_started)

## Steps to deploy ODM on Kubernetes from AWS EKS

1. [Prepare your environment (40 min)](#1-preparing-yourenvironment-40-min)
2. [Push ODM images to the ECR Registry - Optional (25 min)](#2-optional-push-odm-images-in-the-ecr-registry-25-min)
3. [Create an RDS Database (20 min)](#3-create-an-rds-database-20-min)
4. [Manage a  digital certificate (10 min)](#4-manage-a-digital-certificate-10-min)
5. [Install an ODM release (10 min)](#5-install-an-ibm-operational-decision-manager-release-10-min)
6. [Access the ODM service](#6-accessing-services)

For more informations about EKS, see getting https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html 

-----

### 1. Prepare your environment (40 min)
#### Create an EKS cluster (30 min)
     To set up an EKS cluster, follow the documentation https://docs.aws.amazon.com/eks/latest/userguide/create-cluster.html  

> NOTE: Use Kubernetes version (equal or up to??)  1.15
       
 
#### Set up your environment (10 min)
 - [Configure the aws cli](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html)
   ```bash 
   Example: 
   $ aws configure 
   ```

 - [Create a kubeconfig for Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/create-kubeconfig.html)
   ```bash 
   Example: 
   $  aws eks --region eu-west-3 update-kubeconfig --name odm
   ```

 - Check your environment
 
   If your environment is set up correctly, you get the cluster information by running the following command line:
    
```bash
     $ kubectl cluster-info
Kubernetes master is running at https://xxxxxx.yl4.eu-west-3.eks.amazonaws.com
CoreDNS is running at https://xxxxx.yl4.eu-west-3.eks.amazonaws.com/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
Metrics-server is running at https://xxxxx.yl4.eu-west-3.eks.amazonaws.com/api/v1/namespaces/kube-system/services/https:metrics-server:/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```
-----
### 2. (Optional) Push ODM images in the ECR Registry (25 min)
The ODM images must be pushed to a registry that the EKS cluster can access. 

Here we use the [ECR registry](https://docs.aws.amazon.com/AmazonECR/latest/userguide/what-is-ecr.html).
If you use another public registry, skip this section and go to the next step.
 
#### Log in to the [ECR Registry](https://docs.aws.amazon.com/AmazonECR/latest/userguide/Registries.html)
```bash 
Example: 
    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin aws_account_id.dkr.ecr.us-east-1.amazonaws.com
```

#### Create the [ECR Repositories instances](https://docs.aws.amazon.com/AmazonECR/latest/userguide/repository-create.html)
 
> NOTE: You need to create one repository per image.


```bash 
Example: 
    $ aws ecr create-repository --repository-name odm-decisionrunner --image-scanning-configuration scanOnPush=true --region eu-west-3
    $ aws ecr create-repository --repository-name odm-decisionserverruntime --image-scanning-configuration scanOnPush=true --region eu-west-3
    $ aws ecr create-repository --repository-name odm-decisionserverconsole --image-scanning-configuration scanOnPush=true --region eu-west-3
    $ aws ecr create-repository --repository-name dbserver --image-scanning-configuration scanOnPush=true --region eu-west-3
```

#### Load the ODM images locally

 
 1. Download one or more packages (.tgz archives) from [IBM Passport Advantage (PPA)](https://www-01.ibm.com/software/passportadvantage/pao_customer.html).  To view the full list of eAssembly installation images, refer to the [8.10.3 download document](https://www.ibm.com/support/pages/ibm-operational-decision-manager-v8103-download-document).
 2. Extract the .tgz archives to your local filesystem.
     ```bash
     $ tar xzf <PPA-ARCHIVE>.tar.gz
     ```
 2. Check that you can run a docker command.
    ```bash
    $ docker ps
    ```
 3. Load the images to your local registry.
    ```bash
    $ foreach name ( `ls`)  echo $name && docker image load --input $name && end
    ```
  
   For more information, see the [knowledge center](https://www.ibm.com/support/knowledgecenter/SSQP76_8.10.x/com.ibm.odm.kube/topics/tsk_config_odm_prod_kube.html).  
     
#### Tag and push images in the ECR Repository.

You should tag image to the ECR registry previously created.  
- Tag the images
```bash
Exemple: 
    $ docker tag odm-decisioncenter:8.10.3.0-amd64 <AWS-AccountId>.dkr.ecr.eu-west-3.amazonaws.com/odm/odm-decisioncenter:8.10.3.0-amd64
    $ docker tag odm-decisionserverruntime:8.10.3.0-amd64 <AWS-AccountId>.dkr.ecr.eu-west-3.amazonaws.com/odm-decisionserverruntime:8.10.3.0-amd64
    $ docker tag odm-decisionserverconsole:8.10.3.0-amd64 <AWS-AccountId>.dkr.ecr.eu-west-3.amazonaws.com/odm-decisionserverconsole:8.10.3.0-amd64
    $ docker tag odm-decisionrunner:8.10.3.0-amd64 <AWS-AccountId>.dkr.ecr.eu-west-3.amazonaws.com/odm-decisionrunner:8.10.3.0-amd64
    $ docker tag dbserver:8.10.3.0-amd64 <AWS-AccountId>.dkr.ecr.eu-west-3.amazonaws.com/dbserver:8.10.3.0-amd64
```
- Push it to the ECR Registry:
```bash
Exemple: 
    $ docker push <AWS-AccountId>.dkr.ecr.eu-west-3.amazonaws.com/odm-decisioncenter:8.10.3.0-amd64
    $ docker push <AWS-AccountId>.dkr.ecr.eu-west-3.amazonaws.com/odm-decisionserverconsole:8.10.3.0-amd64
    $ docker push <AWS-AccountId>.dkr.ecr.eu-west-3.amazonaws.com/odm-decisionserverruntime:8.10.3.0-amd64
    $ docker push <AWS-AccountId>.dkr.ecr.eu-west-3.amazonaws.com/odm-decisionrunner:8.10.3.0-amd64
    $ docker push <AWS-AccountId>.dkr.ecr.eu-west-3.amazonaws.com/dbserver:8.10.3.0-amd64
```

#### Create a pull secret for  the Registry ECR 

```bash
$ kubectl create secret docker-registry ecrodm --docker-server=<AWS-AccountId>.dkr.ecr.eu-west-3.amazonaws.com --docker-username=AWS --docker-password=$(aws ecr get-login-password --region eu-west-3)
```
> NOTE: ecrodm is the name of the secret that will be used to pull the images from EKS
-----
### 3. Create an RDS Database (20 min)

For this tutorial we have choose postgresql but the procedure should be the same for any others ODM supported database.
 
- Follow this procedure to setup the [RDS Postgresql database](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Welcome.html). 

> NOTE:  Pay attention to:
> - Setup incoming trafic to let connexion from EKS possible (setup vpc inboud rule to anywhere)
> - Ensure you have create a database instance. 
> - Set the dababase password. 

After the creation of the RDS Postgresql database an endpoint will be created to access this instance. This enpoint will be called  RDS_POSTGRESQL_SERVERNAME in the next sections.


-----
### 4. Manage a  digital certificate (10 min)

#### Generate an untrusted certficiate (Optional)

If you have not a trusted certificate  OpenSSL and other crypto and certificate management libraries can be used to generate a certificate .crt file, a private key, define the domain name, and set its expiration date. The following command creates a self-signed certificate (.crt file) and a private key (.key file) that accept the domain name *.mycompany.com. The expiration is set to 1000 days:

```bash
$ openssl req -x509 -nodes -days 1000 -newkey rsa:2048 -keyout mycompany.key -out mycompany.crt -subj "/CN=*.mycompany.com/OU=it/O=mycompany/L=Paris/C=FR"
```

#### Create AWS Server Certificate 

```bash
$ aws iam upload-server-certificate --server-certificate-name mycompany --certificate-body file://mycompany.crt --private-key file://mycompany.key
```

This will output:
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

> Note the "Arn": "arn:aws:iam::<AWS-AccountId>:server-certificate/mycompany" this will be used late for configuring the ALB.

#### Generate a JKS format to be used in the ODM container 

```bash
$ openssl pkcs12 -export -passout pass:password -passin pass:password -inkey mycompany.key -in mycompany.crt -name mycompany -out mycompany.p12
$ keytool -importkeystore -srckeystore mycompany.p12 -srcstoretype PKCS12 -srcstorepass password -destkeystore mycompany.jks -deststoretype JKS -deststorepass password
$ keytool -import -v -trustcacerts -alias mycompany -file mycompany.crt -keystore truststore.jks -storepass password -noprompt
```

-----
### 5. Install an IBM Operational Decision Manager release (10 min)


#### Prepare to install IBM Operational Decision Manager


#### Create Database secret.

To secure access to the database, you must create a secret that encrypts the database user and password before you install the Helm release.

```bash
$ kubectl create secret generic <odm-db-secret> --from-literal=db-user=<rds-postgresql-user-name> --from-literal=db-password=<rds-postgresql-password> 
```

```
Example:
$ kubectl create secret generic odm-db-secret --from-literal=db-user=postgres --from-literal=db-password=postgres
```

#### Create the Kubernetes secret with certificate 

```bash
$ kubectl create secret generic mycompany-secret --from-file=keystore.jks=mycompany.jks --from-file=truststore.jks=truststore.jks --from-literal=keystore_password=password --from-literal=truststore_password=password
```

The certificate must be the same as the one you used to enable TLS connections in your ODM release. For more information, see Defining the security certificate and Working with certificates and SSL.

#### Installing an ODM helm release

Install a Kubernetes release with the default configuration and a name of my-odm-prod-release by using the following command.  

#### Generate the template file

```bash
$ helm template <RELEASENAME> ibm-odm-prod --set image.repository=<IMAGE_REPOSITORY> --set image.tag=8.10.3.0 --set image.pullSecrets=ecrodm --set image.arch=amd64  --set externalDatabase.type=postgres --set externalDatabase.serverName=<RDS_POSTGRESQL_SERNAME>   --set externalDatabase.secretCredentials=<odm-db-secret> --set externalDatabase.port=5432  --set customization.securitySecretRef=mycompany-secret charts/ibm-odm-prod-2.3.0.tar.gz > postgresql.yaml 
```

```bash
Example:
Ex: helm template mycompany charts/ibm-odm-prod-2.3.0.tgz --set image.arch=amd64 --set image.repository=<AWS-AccountId>.dkr.ecr.eu-west-3.amazonaws.com --set image.tag=8.10.3.0 --set image.pullSecrets=ecrodm --set image.arch=amd64  --set externalDatabase.type=postgres --set externalDatabase.serverName=database-1.cv8ecjiejtnt.eu-west-3.rds.amazonaws.com   --set externalDatabase.secretCredentials=odm-db-secret --set externalDatabase.port=5432 --set customization.securitySecretRef=mycompany1-secret --set externalDatabase.databaseName=postgres > postgresql.yaml
```



>Notes:
>  In 8.10.3.0 there is a bug that avoid the instantiation of the topology. To fix this pb.
> - Edit the postgresql.yaml file
> - Search "dc-jvm-options"
> - Delete the block : 
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



#### Apply the template file

```bash
 $ kubectl apply -f postgresql.yaml
```

#### Check the topology.
Check the status of the pods that have been created by running the following command. 
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

-----
### 6. Accessing services  

In this section we will explain how put in place an  Application Load Balancer to expose ODM service.


This following steps expose the Service to internet for others connectivity please refer to AWS documentation.

* Create an Application Load Balancer (ALB)
* Put in place an ingress for ODM services

#### Create an Application Load Balancer (ALB)
More informations about ALB can be found here
https://docs.aws.amazon.com/elasticloadbalancing/latest/userguide/load-balancer-getting-started.html

This following steps allow you to create the ALB. You need to follow this [userguide](https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html#w243aac23b7c17c10b3b1)
* Create an IAM OIDC provider and associate it with your cluster. 
* Create an IAM policy called ALBIngressControllerIAMPolicy for the ALB Ingress Controller pod 
* Create a Kubernetes service account named alb-ingress-controller in the kube-system namespace, a cluster role, and a cluster role binding for the ALB Ingress Controller. Refer to the documentation for the cmd to use.
* Create an IAM role for the ALB ingress controller and attach the role to the service account created in the previous step

then you shloud deploy the ALB Ingress Controller with the following command.

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
 For more information take a look in the https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html#w243aac23b7c17c10b3b1 user guide. 

then deploy the Alb ingress controller.
```bash
$ kubectl apply -f alb-ingress-controller.yaml 
```

#### Deploy the ingress service for ODM.

##### Write the ingress descriptor
You need to define an ingress to route your request to the ODM service.

Here is a sample descriptor to be able to put in place the ingress.

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

##### Deploy the ingress controller 
```bash
kubectl apply -f ingress-mycompany.yaml 
```

After a couple of minute the  ALB reflect the ingress configuration then you will access to the ODM service by retrieving the url with this cmd line:


With this ODM topology in place, you can access to web applications to author, deploy, and test your rule-based decision services.
```bash
$ export ROOTURL=$(kubectl get ingress mycompany| awk '{print $3}' | tail -1)
```

The service will be accessible at this following URL:

| *Component* | *URL* | *Username/Password* |
|---|---|---|
| Decision Center | https://$ROOTURL/decisioncenter/ | odmAdmin/odmAdmin | 
| Decision Server Console |https://$ROOTURL/res/| odmAdmin/odmAdmin |
| Decision Server Runtime | https://$ROOTURL/DecisionService/ | odmAdmin/odmAdmin | 

------

## Troubleshooting

* If your microservice instances are not running properly, you can check the logs by using the following command:
	* `kubectl logs <your-pod-name>`


## References
-  https://aws.amazon.com/blogs/opensource/network-load-balancer-nginx-ingress-controller-eks/


# License
[Apache 2.0](LICENSE)
