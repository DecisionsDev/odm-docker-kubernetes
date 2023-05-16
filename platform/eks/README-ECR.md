The following steps explain how to download the ODM on Kubernetes images (.tgz file) from Passport Advantage® (PPA), and then push them to the [Amazon Elastic Container Registry (Amazon ECR)](https://aws.amazon.com/ecr/).

Prerequisites:

- Install Docker

- Export the following environment variables as they will be used all along this procedure:

    ```bash
    export REGION=<REGION>
    export AWSACCOUNTID=<AWS-AccountId>
    ```

#### a. Log in to the [ECR registry](https://docs.aws.amazon.com/AmazonECR/latest/userguide/Registries.html)

```bash
aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${AWSACCOUNTID}.dkr.ecr.${REGION}.amazonaws.com
```

#### b. Create the [ECR repository instances](https://docs.aws.amazon.com/AmazonECR/latest/userguide/repository-create.html)

> NOTE: You must create one repository per image.

```bash
aws ecr create-repository --repository-name dbserver --image-scanning-configuration scanOnPush=true --region ${REGION}
aws ecr create-repository --repository-name odm-decisioncenter --image-scanning-configuration scanOnPush=true --region ${REGION}
aws ecr create-repository --repository-name odm-decisionrunner --image-scanning-configuration scanOnPush=true --region ${REGION}
aws ecr create-repository --repository-name odm-decisionserverruntime --image-scanning-configuration scanOnPush=true --region ${REGION}
aws ecr create-repository --repository-name odm-decisionserverconsole --image-scanning-configuration scanOnPush=true --region ${REGION}
```

#### c. Load the ODM images locally

 - Download the latest IBM Operational Decision Manager chart and images from [IBM Passport Advantage (PPA)](https://www-01.ibm.com/software/passportadvantage/pao_customer.html).

   Refer to the [ODM download document](https://www.ibm.com/support/pages/node/310661) to view the list of Passport Advantage eAssembly installation images.

 - Extract the .tgz archives to your local file system.

    Extract the file that contains both the Helm chart and the images. The name of the file includes the chart version number:

    ```
    $ mkdir ODM-PPA
    $ cd ODM-PPA
    $ tar zxvf PPA_NAME.tar.gz
    charts/ibm-odm-prod-23.1.0.tgz
    images/odm-decisionserverconsole_8.12.0.0-amd64.tar.gz
    images/odm-decisionserverruntime_8.12.0.0-amd64.tar.gz
    images/odm-decisionrunner_8.12.0.0-amd64.tar.gz
    images/odm-decisioncenter_8.12.0.0-amd64.tar.gz
    images/dbserver_8.12.0.0-amd64.tar.gz
    manifest.json
    manifest.yaml
    ```

- Check that you can run a docker command.
    ```bash
    docker ps
    ```

- Load the images to your local registry.

    ```bash
    for name in images/*.tar.gz; do docker image load --input ${name}; done
    ```

   For more information, refer to the [ODM knowledge center](hhttps://www.ibm.com/docs/en/odm/8.11.1?topic=production-installing-helm-release-odm).

#### d. Tag and push the images to the ECR registry

- Tag the images to the ECR registry previously created

    ```bash
    docker tag dbserver:8.12.0.0-amd64 ${AWSACCOUNTID}.dkr.ecr.${REGION}.amazonaws.com/dbserver:8.12.0.0-amd64
    docker tag odm-decisioncenter:8.12.0.0-amd64 ${AWSACCOUNTID}.dkr.ecr.${REGION}.amazonaws.com/odm-decisioncenter:8.12.0.0-amd64
    docker tag odm-decisionserverruntime:8.12.0.0-amd64 ${AWSACCOUNTID}.dkr.ecr.${REGION}.amazonaws.com/odm-decisionserverruntime:8.12.0.0-amd64
    docker tag odm-decisionserverconsole:8.12.0.0-amd64 ${AWSACCOUNTID}.dkr.ecr.${REGION}.amazonaws.com/odm-decisionserverconsole:8.12.0.0-amd64
    docker tag odm-decisionrunner:8.12.0.0-amd64 ${AWSACCOUNTID}.dkr.ecr.${REGION}.amazonaws.com/odm-decisionrunner:8.12.0.0-amd64
    ```

- Push the images to the ECR registry

    ```bash
    docker push ${AWSACCOUNTID}.dkr.ecr.${REGION}.amazonaws.com/dbserver:8.12.0.0-amd64
    docker push ${AWSACCOUNTID}.dkr.ecr.${REGION}.amazonaws.com/odm-decisioncenter:8.12.0.0-amd64
    docker push ${AWSACCOUNTID}.dkr.ecr.${REGION}.amazonaws.com/odm-decisionserverconsole:8.12.0.0-amd64
    docker push ${AWSACCOUNTID}.dkr.ecr.${REGION}.amazonaws.com/odm-decisionserverruntime:8.12.0.0-amd64
    docker push ${AWSACCOUNTID}.dkr.ecr.${REGION}.amazonaws.com/odm-decisionrunner:8.12.0.0-amd64
    ```

#### e. Create a pull secret for the ECR registry

```bash
kubectl create secret docker-registry ecrodm \
    --docker-server=${AWSACCOUNTID}.dkr.ecr.${REGION}.amazonaws.com \
    --docker-username=AWS --docker-password=$(aws ecr get-login-password --region ${REGION})
```

> NOTE: `ecrodm` is the name of the secret that will be used to pull the images in EKS.

#### f. Install ODM with the following parameters

When you reach the step [Install an IBM Operational Decision Manager release](README.md#5-install-an-ibm-operational-decision-manager-release-10-min), if you want to move the ODM pulled images from the IBM Entitled Registry to the ECR registry, choose the relevant .yaml file depending on whether you want to try the NGINX or the ALB Ingress controller, the internal database or the RDS PostgreSQL database. All you have to do is to override the `image.pullSecrets` and `image.repository` properties when you install the Helm chart:

```bash
helm install mycompany ibm-helm/ibm-odm-prod --version 23.1.0 \
             --set image.pullSecrets=ecrodm \
             --set image.repository=${AWSACCOUNTID}.dkr.ecr.${REGION}.amazonaws.com \
             --values eks-values.yaml
```
