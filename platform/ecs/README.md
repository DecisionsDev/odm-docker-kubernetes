# Deploying IBM Operational Decision Manager on Amazon ECS Fargate (BETA)

This tutorial demonstrates how to deploy an IBM® Operational Decision Manager (ODM) topology on Amazon ECS Fargate with the help of ECS Compose-x tool. 

<br><img src="images/ODM-ECS.png"/> <br>
**Table of Contents**
<!-- TOC -->

- [Deploying IBM Operational Decision Manager on Amazon ECS Fargate BETA](#deploying-ibm-operational-decision-manager-on-amazon-ecs-fargate-beta)
    - [Pre-requisite](#1-pre-requisite)
    - [Prepare your environment for the ODM installation](#2-prepare-your-environment-for-the-odm-installation)
        - [Login to AWS](#21-login-to-aws)
        - [Create RDS Database](#22-create-rds-database)
        - [Create a secret for the Entitled registry access](#23-create-a-secret-for-the-entitled-registry-access)
            - [Retrieve your entitled registry key](#231-retrieve-your-entitled-registry-key)
            - [Create a JSON file](#232-create-a-json-file)
            - [Create the secret in ASW Secrets Manager:](#233-create-the-secret-in-asw-secrets-manager)
        - [Create S3 bucket and IAM policy for IBM licensing service](#24-create-s3-bucket-and-iam-policy-for-ibm-licensing-service)
        - [Add Outbound rule to Load balancer's security group](#25-add-outbound-rule-to-load-balancers-security-group)
        - [Initialize ECS Compose-X](#26-initialize-ecs-compose-x)
        - [Store Amazon Root CA For HTTPS mode only](#27-store-amazon-root-ca-for-https-mode-only)
    - [Deploy ODM to AWS ECS Fargate](#3-deploy-odm-to-aws-ecs-fargate)
        - [Edit docker-compose file](#31-edit-docker-compose-file)
            - [HTTP mode](#311-http-mode)
            - [HTTPS mode](#312-https-mode)
        - [Create the AWS CloudFormation stacks](#32-create-the-aws-cloudformation-stacks)
        - [Configure inbound rule on RES security group:](#33-configure-inbound-rule-on-res-security-group)
        - [Access ODM services:](#34-access-odm-services)
        - [Edit Server configurations in Decision Center](#35-edit-server-configurations-in-decision-center)
    - [Cleaup AWS CloudFormation stack](#4-cleaup-aws-cloudformation-stack)
        - [AWS CloudFormation console:](#41-aws-cloudformation-console)
        - [AWS Cli command](#42-aws-cli-command)

<!-- /TOC -->


## 1. Pre-requisite

To deploy ODM containers on AWS ECS Fargate from [docker-compose](docker-compose-http.yaml) file, you must meet the following requirements:

   * Install the latest version of [AWS Cli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).
   * Install the latest version of Podman.
   * Install python3.6+ and later version.
   * Ensure you have an [AWS Account](https://aws.amazon.com/getting-started/). 
   * Install [ECS Compose-x](https://github.com/compose-x/ecs_composex?tab=readme-ov-file#installation), preferably in a virtual environment.
   * Ensure that you have an existing internet-facing Application Elastic Load balancer and a VPC with public subnets [setup](https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/elb-manage-subnets.html) on Amazon Web Services(AWS).
   * If you want to run ODM Decision services in HTTPS mode, you need to have an [ACM public certificate](https://console.aws.amazon.com/acm/home). 

*Note*: The commands and tools have been tested on macOS.

## 2. Prepare your environment for the ODM installation

### 2.1 Login to AWS

```
export REGION=<aws_deployment_region>
export AWSACCOUNTID=<aws_account_id>
aws ecr get-login-password --region ${REGION} | podman login --username AWS --password-stdin ${AWSACCOUNTID}.dkr.ecr.${REGION}.amazonaws.com
```
where
- `REGION`: AWS Regions where you want to deploy your services
- `AWSACCOUNTID`: your AWS account ID

### 2.2 Create RDS Database

In this tutorial, we will create an Amazon RDS database instance that can be used by ODM.

- Run the following command to create the postgres database instance:
```
aws rds create-db-instance \
  --db-instance-identifier "odm-rds" \
  --db-name "odmdb" \
  --engine 'postgres' \
  --engine-version '13' \
  --auto-minor-version-upgrade \
  --allocated-storage 50 \
  --max-allocated-storage 100 \
  --db-instance-class 'db.t3.large' \
  --master-username "odmusername" \
  --master-user-password "odmpassword" \
  --port "5432" \
  --publicly-accessible \
  --storage-encrypted \
  --tags Key=project,Value=odm
```
- Note down the RDS instance endpoint, you will assign it to the `DB_SERVER_NAME` parameter under `environment` section of each ODM service in the docker-compose file.

### 2.3 Create a secret for the Entitled registry access

To get access to the ODM material, you must have an IBM entitlement registry key to pull the images from the IBM Entitled registry. 
It will be used in the next step of this tutorial.

#### 2.3.1 Retrieve your entitled registry key

- Log in to [MyIBM Container Software Library](https://myibm.ibm.com/products-services/containerlibrary) with the IBMid and password that are associated with the entitled software.

- In the Container software library tile, verify your entitlement on the View library page, and then go to *Get entitlement key* to retrieve the key.

#### 2.3.2 Create a JSON file 

- Create a `token.json` file with that format.
```json
{
    "username":"cp",
    "password":"<YOUR_ENTITLED_API_KEY>"
}
```

#### 2.3.3 Create the secret in ASW Secrets Manager

You can proceed to create an AWS Secret containing the `token.json` file. The secret with the pull credential will be assigned in the docker-compose file.

- Create the secret using the following AWS Cli command. For more information, see [Create an AWS Secrets Manager secret](https://docs.aws.amazon.com/secretsmanager/latest/userguide/create_secret.html).

```
aws secretsmanager create-secret \
    --name IBMCPSecret \
    --secret-string file://token.json
```

*Result*:
```
{
    "ARN": "arn:aws:secretsmanager:<aws_deployment_region>:<aws_account_id>:secret:IBMCPSecret-YYYYY",
    "Name": "IBMCPSecret",
    "VersionId": "..."
}
```

- Note down the secret's ARN.  You will assign it to the `x-aws-pull_credentials` custom extension along with the image URI of each ODM service in the docker-compose file. 
For example:
```
  odm-decisioncenter:
    image: cp.icr.io/cp/cp4a/odm/odm-decisioncenter:9.0.0.1-amd64
    x-aws-pull_credentials: "arn:aws:secretsmanager:<aws_deployment_region>:<aws_account_id>:secret:IBMCPSecret-YYYYY"
    ...
  odm-decisionserverruntime:
    image: cp.icr.io/cp/cp4a/odm/odm-decisionserverruntime:9.0.0.1-amd64
    x-aws-pull_credentials: "arn:aws:secretsmanager:<aws_deployment_region>:<aws_account_id>:secret:IBMCPSecret-YYYYY"
    ...
```

### 2.4 Create S3 bucket and IAM policy for IBM licensing service

In this tutorial, we have included IBM Licensing service for tracking license usage of ODM that is deployed on AWS ECS Fargate.

The following steps are needed by IBM Licensing service:

- Create a S3 bucket in AWS for storing the IBM software license usage data. The name of the bucket must follow the `ibm-license-service-<aws_account_id>` pattern. 

- Add a IAM policy with read and write access, and define it on the S3 bucket. 

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Statement1",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject"
            ],
            "Resource": "arn:aws:s3:::ibm-license-service-<aws_account_id>/*"
        }
    ]
}
```

- You will assign this policy to the `x-aws-policies` custom extension of each service in the docker-compose file. 
```
    x-aws-policies:
      - arn:aws:iam::<aws_account_id>:policy/<policy_allow_access_S3_bucket>
```

For more information, see [Tracking license usage on AWS ECS Fargate](https://www.ibm.com/docs/en/cloud-paks/foundational-services/3.23?topic=platforms-tracking-license-usage-aws-ecs-fargate).

### 2.5 Add Outbound rule to Load balancer's security group

Verify that the outbound configuration of the security group of your existing loadbalancer is having "Allow all outbound traffic". However, if you have restricted outbound security group settings, then you must add an addition outbound rule to allow "Custom TCP" port range of `9060 - 9082` . These ports are for ODM Decision services in HTTP mode. For HTTPS mode, the port range should be `9653 - 9953`.

- Access to [EC2 Loadbalancer](https://console.aws.amazon.com/ec2/home?#LoadBalancers:) console.
- Click on the load balancer that you want to define in the docker-compose file.
- Click `Security` tab and then click on the security group.
- Click `Outbound rules` tab, `Edit outbound rules` button and add the outbound rule as shown below:
<br><img src="images/security-group-outbound.png" width="80%"/>

### 2.6 Initialize ECS Compose-X

You will need to setup some permissions to validate the AWS CloudFormation (CFN) templates, Lookup AWS resources and etc when using ECS Compose-X commands. For more information about the configuration, see [AWS Account configuration](https://github.com/compose-x/ecs_composex/blob/main/docs/requisites.rst#aws-account-configuration) and [Permissions to upload files to S3](https://github.com/compose-x/ecs_composex/blob/main/docs/requisites.rst#permissions-to-upload-files-to-s3). If your AWS account has administrator permissions, then it is not required to do so.

Upon setting up the appropriate permissions, run this `ecs-compose-x` command which enables some ECS settings and create a default S3 bucket [required by ECS Compose-X](https://github.com/compose-x/ecs_composex/blob/main/docs/requisites.rst#aws-ecs-settings):
```
ecs-compose-x init  
```

Result:
```
2024-06-19 11:39:37 [    INFO] ECS Setting awsvpcTrunking set to 'enabled'
2024-06-19 11:39:37 [    INFO] ECS Setting serviceLongArnFormat set to 'enabled'
2024-06-19 11:39:37 [    INFO] ECS Setting taskLongArnFormat set to 'enabled'
2024-06-19 11:39:37 [    INFO] ECS Setting containerInstanceLongArnFormat set to 'enabled'
2024-06-19 11:39:37 [    INFO] ECS Setting containerInsights set to 'enabled'
2024-06-19 11:39:38 [    INFO] Bucket ecs-composex-<aws_account_id>-<aws_deployment_region> successfully created.
```

*NOTE*: A S3 bucket will automatically be created. It is used to store the generated CFN templates when running `ecs-compose-x` commands.

### 2.7 Store Amazon Root CA (For HTTPS mode only)

If you want to run ODM Decision services in HTTPS mode, it is required to provide the Amazon Root CA to ODM Decision Center for authentication purposes during ruleApp deployments and also running `Test and Simulation`.

- Go to [Amazon Trust Services](https://www.amazontrust.com/repository/) and download [Amazon Root CA 1](https://www.amazontrust.com/repository/AmazonRootCA1.pem) in `PEM` format.
- Rename the downloaded `AmazonRootCA1.pem` file to `AmazonRootCA1.crt`.
- In the S3 bucket created by `ecs-compose-x init`, create a folder named `certificate`.
- Upload this `AmazonRootCA1.crt` file into this folder. <br><img src="images/S3-certificate.png" width="80%"/>
- Create a new file system name `odm-filesystem` in [Amazon EFS](https://console.aws.amazon.com/efs/home) using the same VPC where you plan to create ECS Fargate cluster with ODM services. This file system will be used as a volume for Decision Center. See :
```
volumes:
  app:
    x-efs:
      Lookup:
        Tags: 
          Name: odm-filesystem
...
  odm-decisioncenter:
    image: cp.icr.io/cp/cp4a/odm/odm-decisioncenter:9.0.0.1-amd64
    x-aws-pull_credentials: "arn:aws:secretsmanager:<aws_deployment_region>:<aws_account_id>:secret:IBMCPSecret-XXXXXX"
    volumes:
      - app:/config/security/trusted-cert-volume
```
- At [AWS DataSync](https://console.aws.amazon.com/datasync), create a new task for data transfer and synchronization between the S3 bucket `certificate` folder and `odm-filesystem`.
    - Step 1: Configure source location. 
        - Select *Location type*: `Amazon S3`, *Region*, *S3 bucket*. In *Folder* field, and enter `/certificate`. Auto-generate the IAM role. Click `Next`.
   <br><img src="images/data-sync1.png" width="50%"/>

    - Step 2: Configure destination location.
        - Select *Location type*: `Amazon EFS file system`, *Region*, *File System*: `odm-filesystem` and *Mount path*: `/`. Choose the appropriate subnet (that this filesystem will be accessed) and the security group (that can access this file system). Click `Next`.
    <br><img src="images/data-sync2.png" width="50%"/>

    - Step 3: Configure settings.
        - Give a name to the datasync. Use the default options and click `Next` to `Review` page.
         <br><img src="images/data-sync3.png" width="50%"/>
    - Step 4: Review
        - Verify the details and click `Create Task` to create the task.

- After the task is created, you can launch data synchronising using `Start with defaults`.
 <br><img src="images/data-sync4.png" width="80%"/>
    - Wait for a few minutes and check the status at `Task history`.  It should be successful. <br><img src="images/data-sync-ok.png" width="50%"/>
    - If the task failed with this following error, the security group that you configured at Step 2 does not allow ingress and egress on port 2049. <br><img src="images/data-sync-ko.png" width="50%"/>
    - Make sure to add an inbound and outbound rule with NFS type at port 2049 to this security group. For example: <br><img src="images/security-group-nfs-2049.png" width="80%"/>

## 3. Deploy ODM to AWS ECS Fargate

ODM can be deployed either in [HTTP](docker-compose-http.yaml) or [HTTPS](docker-compose-https.yaml) mode. Each of the ODM components are configured to be deployed as separate ECS task due to IBM licensing service which logs CPU usage per ECS task. The IBM Licensing service will be deployed to each ECS task for tracking purpose. Inspect the docker-compose file for more details.

### 3.1 Edit docker-compose file

#### 3.1.1 HTTP mode

- Download the [docker-compose-http.yaml](docker-compose-http.yaml) and save this file in your working dir.
- Edit the file and assign the appropriate values in the all `<PLACEHOLDER>`.
- For the parameter `RES_URL` that is defined in `environment` section of `odm-decisionrunner` service, look for the DNS value of your [load balancer](https://console.aws.amazon.com/ec2/home?#LoadBalancers:) and assign it to the parameter as `http://your_loadbalancer_dns/res`. This is required for running Testing and Simulation in Decision Center under ECS Fargate network.

#### 3.1.2 HTTPS mode

- Download the [docker-compose-https.yaml](docker-compose-https.yaml) and save this file in your working dir.
- Edit the file and assign the appropriate values in the all `<PLACEHOLDER>`.
- In this mode, HTTPS listeners for each ODM service will be added to the load balancer. You need to assign the arn of the [ACM public certificate](https://console.aws.amazon.com/acm/home) at `x-elbv2` custom extension. The ssl policy is set to TLS1.3 `ELBSecurityPolicy-TLS13-1-2-2021-06` policy.  For more information, see [Create an HTTPS listener for your Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html#describe-ssl-policies).

```
x-elbv2:
  public-alb:
    Lookup:
      loadbalancer:
        Tags:
          <loadbalancer_tag>: <loadbalancer_tag_value>
...
    Listeners:
    # Declare to use port=443, protocal=HTTPS and the access paths for each ODM components
    # If the port is used, change it to another value. 
      - Port: 443
        Protocol: HTTPS
        # Make sure there is ACM public certificate that can be applied on ELB for HTTPS purpose
        Certificates:
          - CertificateArn: arn:aws:acm:<aws_deployment_region>:<aws_account_id>:certificate/XXXX-YYYY
        SslPolicy: ELBSecurityPolicy-TLS13-1-2-2021-06
  ```
- For the parameter `RES_URL` that is defined in `environment` section of `odm-decisionrunner` service, look for the DNS value of your [load balancer](https://console.aws.amazon.com/ec2/home?#LoadBalancers:) and assign it to the parameter as `https://your_loadbalancer_dns/res`. This is required for running `Testing and Simulation` in Decision Center.


### 3.2 Create the AWS CloudFormation stacks

- Run the following command to generate the CFN templates, validate the templates, and create the stacks in CFN.

```
ecs-compose-x up -n odm-stack -b <generated_s3_bucket> -f docker-compose-http.yaml -d outputdir
```

- Sign in to the [AWS CloudFormation console](https://console.aws.amazon.com/cloudformation/home?) to monitor the stacks (root, CloudMap, IAM, elbv2, service networking, and odm services) creation status. 
<br><img src="images/odm-stack-cfn.png" width="80%"/>
- If all the stacks complete without error, go to [Elastic Container Service](https://console.aws.amazon.com/ecs/v2/home?) to look for the newly created cluster named `odm-stack`.  

### 3.3 Configure inbound rule on RES security group

- Click on the cluster and you will find 4 services with their respective tasks starting up :
<br><img src="images/odm-stack-ecs.png" width="80%"/>

As Decision Server Console and Decision Server Runtime are deployed as separate services for IBM license tracking and scalability, an addition setup is required to allow Decision Server Runtime to connect to the notification server of Decision Server Console.

- Under the `Services` tab, click on `odm-stack-res-XXX` service.

- At the `odm-stack-res-XXX` page, click the `Configuration and networking` tab.

- Under `Network configuration` section, click on the security group `sg-YYYYY`. The security group configuration of the RES service will be displayed.

- Click the `Edit inbound rules` button, and update the rule that defines custom TCP port:1883. 
  - Change the default security group to the security group of Decision Server Runtime. 
  - Update the description to `From runtime to res on port 1883`. 
  - Save the rules.
<br><img src="images/res-inbound-rules.png" width="80%"/><br>
*Tips:* Enter `runtime` in the *Source* field to filter the list of existing security groups

After saving the inbound rules, wait for all the services to be `Active` and that their respective tasks are in running state. Check the logs of the `odm-decisionserverruntime` containers. If the following exception persists, restart the Decision Server Runtime `odm-stack-runtime-YYY` service to be sure that the changes to the security rules are well taken into account.

```
com.ibm.rules.res.notificationserver.internal.ClientConnectionHandler$1 operationComplete GBRXX0102W: Rule Execution Server console : Client 66325de3-3537-4f56-8cc4-ede3460d6427 was unable to perform handshake with the notification server. It will disconnect and then try to reconnect. For details, see the exception trace....
```

Follow these steps to restart:

- Go back to `odm-stack`, click on `odm-stack-runtime-YYY` service.

- Click the `Update service` button and check the `Force new deployment` checkbox on the top of the page.

- Click the `Update` button to restart the service. You should see that the service is updated and a new deployment with `In progress` state as such:
<br><img src="images/restart-runtime.png" width="80%"/>

- When the deployment is complete, verify in the runtime log that the client is connected to the notification server:

```
[10/7/24, 17:17:49:451 CEST] 00000040 mbean I com.ibm.rules.res.notificationserver.internal.DefaultNotificationServerClient$1 serviceActivated GBRXX0119I: Rule Execution Server console : Client d6bcf2c5-26e3-4373-9e3f-3e33baf36b52 is connected to server odm-decisionserverconsole:1883.
...

[10/7/24, 17:17:50:592 CEST] 00000042 mbean I com.ibm.rules.res.notificationserver.internal.ClientConnectionHandler$1 operationComplete GBRXX0103I: Rule Execution Server console : Client d6bcf2c5-26e3-4373-9e3f-3e33baf36b52 performed handshake with the notification server.
```

### 3.4 Access ODM services

- Access to [EC2 Loadbalancer](https://console.aws.amazon.com/ec2/home?#LoadBalancers:) console.
- Click on the load balancer that you have defined in your [docker-compose](docker-compose-http.yaml) file.
- Verify that the listener rules for the ODM services are added and the target groups are in healthy state.
- Copy the load balancer's DNS name.
- Depending on HTTP or HTTPS mode, the URLs for the ODM components are as follows:
    - `http://<loadbalancer_dns>/decisioncenter` or `https://<loadbalancer_dns>/decisioncenter`
    - `http://<loadbalancer_dns>/res` or `https://<loadbalancer_dns>/res`
    - `http://<loadbalancer_dns>/DecisionService` or `https://<loadbalancer_dns>/DecisionService`
    - `http://<loadbalancer_dns>/DecisionRunner` or `https://<loadbalancer_dns>/DecisionRunner`

### 3.5 Edit Server configurations in Decision Center

- Login to Decision Center with `odmAdmin` user.
- Click on `Administration` tab and then `Servers` tab.
- Edit `Decision Service Execution` configuration and update the `Server URL` to `http://<loadbalancer_dns>/res`. If HTTPS mode, use `https://`.
- Test the connection. If the test is successful, save the changes. 
<br><img src="images/test-res-configuration.png" width="40%"/>
- Repeat the same for `Test and Simulation Execution` configuration. Update the `Server URL` to `http://<loadbalancer_dns>/DecisionRunner`. If HTTPS mode, use `https://`. Test and then save the changes.

## 4. Cleaup AWS CloudFormation stack

To remove the base stack and its nested stacks, there are 2 options.

### 4.1 AWS CloudFormation console
- Access to the [AWS CloudFormation console](https://console.aws.amazon.com/cloudformation/home?).
- Select the base stack `odm-stack` and click `Delete` button.

### 4.2 AWS Cli command

```console
aws --region <aws_deployment_region> cloudformation delete-stack \
--stack-name odm-stack
```
