# 1. Pre-requisite 

To deploy ODM containers on AWS ECS Fargate from docker-compose files, you must meet the following requirements:

   * Install the latest version of [AWS Cli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).
   * Install the latest version of Podman.
   * Ensure you have an [AWS Account](https://aws.amazon.com/getting-started/). 
   * Ensure that you have python3.6+ and later version.
   * Install [ECS Compose-x](https://github.com/compose-x/ecs_composex?tab=readme-ov-file#installation), preferably in a virtual environment.
   * Ensure that you have an existing internet-facing Elastic Load balancer and a VPC with public subnets [setup](https://docs.aws.amazon.com/elasticloadbalancing/latest/classic/elb-manage-subnets.html).

# 2. Prepare your environment for the ODM installation

##  Login to AWS

```
export REGION=<aws_deployment_region>
export AWSACCOUNTID=<aws_account_id>
aws ecr get-login-password --region ${REGION} | podman login --username AWS --password-stdin ${AWSACCOUNTID}.dkr.ecr.${REGION}.amazonaws.com
```

## Create RDS Database
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

## Create a secret for the Entitled registry
To get access to the ODM material, you must have an IBM entitlement registry key to pull the images from the IBM Entitled registry. 
It will be used in the next step of this tutorial.

### a. Retrieve your entitled registry key
  - Log in to [MyIBM Container Software Library](https://myibm.ibm.com/products-services/containerlibrary) with the IBMid and password that are associated with the entitled software.

  - In the Container software library tile, verify your entitlement on the View library page, and then go to *Get entitlement key* to retrieve the key.

### b. Create a JSON file 

Create a `token.json` file with that format.
```json
{
    "username":"cp",
    "password":"<YOUR_ENTITLED_API_KEY>"
}
```

### c. Create the secret in ASW Secrets Manager:

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
- Note down the secret's ARN.  You will assign it to the `x-aws-pull_credentials` custom extension along with the image URI of the ODM service in the docker-compose file. 
For example:
```
  my-odm-decisioncenter:
    image: cp.icr.io/cp/cp4a/odm/odm-decisioncenter:8.12.0.1-amd64
    x-aws-pull_credentials: "arn:aws:secretsmanager:<aws_deployment_region>:<aws_account_id>:secret:IBMCPSecret-YYYYY"
    ...
```
## Create S3 bucket and IAM policy for IBM licensing service

- Make sure to create a S3 buckets in AWS for storing the IBM software license usage data. The name of the bucket must follow the `ibm-license-service-<aws_account_id>` pattern. 

- Add a new IAM policy with read and write access, and define it on the S3 bucket. 

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


## Initialize ECS Compose-X

You will need to setup some permissions to validate the templates with AWS CloudFormation, Lookup AWS resources and etc when using ECS Compose-X commands. For more information about the configuration, see [AWS Account configuration](https://github.com/compose-x/ecs_composex/blob/main/docs/requisites.rst#aws-account-configuration) and [Permissions to upload files to S3](https://github.com/compose-x/ecs_composex/blob/main/docs/requisites.rst#permissions-to-upload-files-to-s3). If your AWS account has administrator permissions, then it is not required to do so.

Upon setting up the appropriate permissions, run this command which enables some ECS settings and create a default S3 bucket [required by ECS Compose-X](https://github.com/compose-x/ecs_composex/blob/main/docs/requisites.rst#aws-ecs-settings):
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

# 3. Deploy ODM to AWS ECS Fargate

## a. Edit docker-compose.yaml

- Download the [docker-compose.yaml](docker-compose.yaml) and save this content in your working dir.
- Edit the file and assign the appropriate values in the all `<PLACEHOLDER>`.

## b. Create the AWS CloudFormation stacks

- Run the following command to generate the AWS CloudFormation (CFN) templates, validate the templates, and create the stacks in CFN.

```
ecs-compose-x up -n <your_stack_name> -b <generated_s3_bucket> -f docker-compose-http-service-connect.yaml -d outputdir
```

- Sign in to the [AWS CloudFormation console](https://console.aws.amazon.com/cloudformation/home?) to monitor the stacks (root, CloudMap, IAM, elbv2, service networking, and ODM) creation status. 

- If all the stacks complete without error, access to [Elastic Container Service](https://console.aws.amazon.com/ecs/v2/home?) to look for the newly created cluster named `<your_stack_name>`.  

- Click on the cluster and you shall find the service with ODM and IBM licensing service containers running:

## c. Access ODM services:

- Access to [EC2 Loadbalancer](https://console.aws.amazon.com/ec2/home?#LoadBalancers:) console.
- Click on the load balancer that you have defined in your docker-compose file.
- Verify that the listener rules for the ODM services are added and the target groups are in healthy state.
- Copy the loadbalancer DNS name.
- The URLs for the ODM components are as follows:
    - http://<loadbalance_dns>:81/decisioncenter
    - http://<loadbalance_dns>:81/res
    - http://<loadbalance_dns>:81/DecisionService
    - http://<loadbalance_dns>:81/DecisionRunner


## 4. Cleaup AWS CloudFormation stack

To remove the base stack and its nested stack, there are 2 options.

### 1. AWS CloudFormation console:
- Access to the [AWS CloudFormation console](https://console.aws.amazon.com/cloudformation/home?).
- Select the base stack `<your_stack_name>` and click `Delete` button.

### 2. AWS Cli command

```console
aws --region <aws_deployment_region> cloudformation delete-stack \
--stack-name <your_stack_name>
```



