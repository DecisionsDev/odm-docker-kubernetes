The following steps are explaining how to download ODM images on Kubernetes package (.tgz file) from Passport Advantage® (PPA) and then push the contained images to the EKS Container Registry (ECR).

Prerequisites:
- Install Docker

Here we are using the [ECR registry](https://docs.aws.amazon.com/AmazonECR/latest/userguide/what-is-ecr.html).
If you use another public registry, skip this section and go to [step c](#c-load-the-odm-images-locally).

#### a. Log in to the [ECR registry](https://docs.aws.amazon.com/AmazonECR/latest/userguide/Registries.html)

```bash
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <aws_account_id>.dkr.ecr.<region>.amazonaws.com
```

#### b. Create the [ECR repository instances](https://docs.aws.amazon.com/AmazonECR/latest/userguide/repository-create.html)

> NOTE: You must create one repository per image.

```bash
export REGION=<region>
aws ecr create-repository --repository-name odm-decisioncenter --image-scanning-configuration scanOnPush=true --region $REGION
aws ecr create-repository --repository-name odm-decisionrunner --image-scanning-configuration scanOnPush=true --region $REGION
aws ecr create-repository --repository-name odm-decisionserverruntime --image-scanning-configuration scanOnPush=true --region $REGION
aws ecr create-repository --repository-name odm-decisionserverconsole --image-scanning-configuration scanOnPush=true --region $REGION
```

#### c. Load the ODM images locally

 - Download the latest IBM Operational Decision Manager chart and images from [IBM Passport Advantage (PPA)](https://www-01.ibm.com/software/passportadvantage/pao_customer.html).

   Refer to the [ODM download document](https://www.ibm.com/support/pages/node/310661) to view the list of Passport Advantage eAssembly installation images.

 - Extract the .tgz archives to your local file system.

    Extract the file that contains both the Helm chart and the images. The name of the file includes the chart version number:

    ```console
    $ mkdir ODM-PPA
    $ cd ODM-PPA
    $ tar zxvf PPA_NAME.tar.gz
    charts/ibm-odm-prod-22.1.0.tgz
    images/odm-decisionserverconsole_8.11.0.1-amd64.tar.gz
    images/odm-decisionserverruntime_8.11.0.1-amd64.tar.gz
    images/odm-decisionrunner_8.11.0.1-amd64.tar.gz
    images/odm-decisioncenter_8.11.0.1-amd64.tar.gz
    images/dbserver_8.11.0.1-amd64.tar.gz
    manifest.json
    manifest.yaml
    ```

- Check that you can run a docker command.
    ```bash
    docker ps
    ```

- Load the images to your local registry.

    ```bash
    for name in images/*.tar.gz; do echo $name && docker image load --input $name; done
    ```

   For more information, refer to the [ODM knowledge center](hhttps://www.ibm.com/docs/en/odm/8.11.0?topic=production-installing-helm-release-odm).

#### d. Tag and push the images to the ECR registry

- Tag the images to the ECR registry previously created

    ```bash
    export REGION=<region>
    export AWSACCOUNTID=<AWS-AccountId>
    docker tag odm-decisioncenter:8.11.0.1-amd64 $AWSACCOUNTID.dkr.ecr.$REGION.amazonaws.com/odm-decisioncenter:8.11.0.1-amd64
    docker tag odm-decisionserverruntime:8.11.0.1-amd64 $AWSACCOUNTID.dkr.ecr.$REGION.amazonaws.com/odm-decisionserverruntime:8.11.0.1-amd64
    docker tag odm-decisionserverconsole:8.11.0.1-amd64 $AWSACCOUNTID.dkr.ecr.$REGION.amazonaws.com/odm-decisionserverconsole:8.11.0.1-amd64
    docker tag odm-decisionrunner:8.11.0.1-amd64 $AWSACCOUNTID.dkr.ecr.$REGION.amazonaws.com/odm-decisionrunner:8.11.0.1-amd64
    ```

- Push the images to the ECR registry

    ```bash
    docker push $AWSACCOUNTID.dkr.ecr.$REGION.amazonaws.com/odm-decisioncenter:8.11.0.1-amd64
    docker push $AWSACCOUNTID.dkr.ecr.$REGION.amazonaws.com/odm-decisionserverconsole:8.11.0.1-amd64
    docker push $AWSACCOUNTID.dkr.ecr.$REGION.amazonaws.com/odm-decisionserverruntime:8.11.0.1-amd64
    docker push $AWSACCOUNTID.dkr.ecr.$REGION.amazonaws.com/odm-decisionrunner:8.11.0.1-amd64
    ```

#### e. Create a pull secret for the ECR registry

```bash
kubectl create secret docker-registry ecrodm --docker-server=<AWS-AccountId>.dkr.ecr.<region>.amazonaws.com --docker-username=AWS --docker-password=$(aws ecr get-login-password --region <region>)
```
> NOTE: `ecrodm` is the name of the secret that will be used to pull the images in EKS.

#### f. Install ODM with the following parameters
  
When reaching the step [Install an IBM Operational Decision Manager release](README.md#5-install-an-ibm-operational-decision-manager-release-10-min), to change the ODM pull images from the IBM Entitled Registry by the ECR registry, choose the relevant yaml file provided according if you want to try NGINX or ALB ingress controller, internal or RDS postgreSQL database, and you just have to override the image.pullSecrets and image.repository properties when installing the helm chart like :

```bash
helm install mycompany ibmcharts/ibm-odm-prod --version 22.1.0 \
             --set image.pullSecrets=ecrodm \
             --set image.repository=<AWS-AccountId>.dkr.ecr.<region>.amazonaws.com \
             -f eks-values.yaml
```
