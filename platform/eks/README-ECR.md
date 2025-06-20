# Mirroring images to an Amazon Elastic Container Registry from a bastion host
The following steps explain how to use a bastion host to mirror the ODM on Kubernetes images to an [Amazon Elastic Container Registry (Amazon ECR)](https://aws.amazon.com/ecr/).

A bastion host is a host connected to both the private registry (Amazon ECR) and the public container registry.

The related instructions in the online documentation are:
- [Setting up a host to mirror images to a private registry](https://www.ibm.com/docs/en/odm/9.5.0?topic=installation-setting-up-host-mirror-images-private-registry)
- [Setting environment variables and downloading CASE files](https://www.ibm.com/docs/en/odm/9.5.0?topic=installation-setting-environment-variables-downloading-case-files)
- [Option 1: Mirroring images to a private container registry with a bastion server](https://www.ibm.com/docs/en/odm/9.5.0?topic=mipr-option-1-mirroring-images-private-container-registry-bastion-server)

## Prerequisites:

- Install the following tools on your bastion host (if needed, refer to [Setting up a host to mirror images to a private registry](https://www.ibm.com/docs/en/odm/9.5.0?topic=installation-setting-up-host-mirror-images-private-registry)):
  - [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)
  - Docker or Podman
  - OCP CLI (oc)
  - [IBM ibm-pak plugin](https://github.com/IBM/ibm-pak)
  - Helm
    
- The bastion host needs access to the following sites and ports:
  - icr.io:443 for IBM Cloud Container Registry 
  - github.com for CASE files and tools
  - Amazon ECR

- Configure the `aws` CLI environment by running the following command: 
  ```bash
  aws configure 
  ```
  You will be prompted to provide your AWS Access Key ID, AWS Secret Access Key and the Default region name.

- Export the following environment variables (replace the placeholders `<AWS-Region>`, `<AWS-AccountId>`, `<ODM-CaseVersion>` and `<amd64|ppc64le|s390x>` with actual values):

  ```bash
  export REGION=<AWS-Region>
  export AWSACCOUNTID=<AWS-AccountId>
  export TARGET_REGISTRY=${AWSACCOUNTID}.dkr.ecr.${REGION}.amazonaws.com
  export CASE_NAME=ibm-odm-prod
  export CASE_VERSION=<ODM-CaseVersion>
  export ARCHITECTURE=<amd64|ppc64le|s390x>
  ```

  The list of CASE versions for ODM can be found in [IBM: CASE to Application Version](https://ibm.github.io/cloud-pak/assets/html/ibm-odm-prod-table.html).

## Procedure:

### a. Download the CASE files

 - Run the following commands to download the image inventory for Operational Decision Manager to your host:

    ```bash
    oc ibm-pak config locale -l <LOCALE>
    oc ibm-pak get $CASE_NAME --version $CASE_VERSION
    ```

    The ibm-pak plug-in can detect the locale of your environment and provide textual help and messages accordingly. Where `<LOCALE>` can be one of de_DE, en_US, es_ES, fr_FR, it_IT, ja_JP, ko_KR, pt_BR, zh_Hans, zh_Hant.
  
    If you do not specify the CASE version, it downloads the latest CASE.

    The command creates a flat directory structure under `~/.ibm-pak/data/cases/$CASE_NAME/$CASE_VERSION` that contains the ibm-odm-prod.tgz CASE files, a folder that contains the ibm-odm-prod Helm charts, and two CSV files that contain the list of images and the list of charts associated with the CASE.

    For more information about this step, refer to [Setting environment variables and downloading CASE files](https://www.ibm.com/docs/en/odm/9.5.0?topic=installation-setting-environment-variables-downloading-case-files).

### b. Mirror the ODM images to the ECR registry

- Run the following command to generate mirror manifests to be used when mirroring the ODM images to the target registry.

  ```bash
  oc ibm-pak generate mirror-manifests ${CASE_NAME} ${TARGET_REGISTRY} --version ${CASE_VERSION}
  ```

  `TARGET_REGISTRY` refers to the registry where your images are mirrored to and accessed by your cluster.

  This command generates the files `images-mapping.txt` and `image-content-source-policy.yaml` at `~/.ibm-pak/data/mirror/${CASE_NAME}/${CASE_VERSION}`. The `~/.ibm-pak/mirror` directory is also created.

 - Store authentication credentials of the source Docker registry `cp.icr.io` and the target Amazon ECR.

    > NOTE: 
    You must specify the user as `cp` to log in to `cp.icr.io`. The password is your Entitlement key from the [IBM Cloud Container Registry](https://myibm.ibm.com/products-services/containerlibrary).
    
    - If you use Podman:

      > Note: by default Podman reads and stores credentials in `${XDG_RUNTIME_DIR}/containers/auth.json`. Read more [here](https://docs.podman.io/en/stable/markdown/podman-login.1.html).

      ```bash
      export REGISTRY_AUTH_FILE=<your_path/auth.json>
      podman login cp.icr.io -u cp
      aws ecr get-login-password --region ${REGION} | podman login --username AWS --password-stdin ${TARGET_REGISTRY}
      ```
  
    - If you use Docker:
  
      ```bash
      export REGISTRY_AUTH_FILE=$HOME/.docker/config.json
      docker login cp.icr.io -u cp
      aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${TARGET_REGISTRY}
      ```

- Create the [Amazon ECR repository instances](https://docs.aws.amazon.com/AmazonECR/latest/userguide/repository-create.html)

  > NOTE: You must create one repository per image type.

  ```bash
  aws ecr create-repository --repository-name cp/cp4a/odm/dbserver --image-scanning-configuration scanOnPush=true --region ${REGION}
  aws ecr create-repository --repository-name cp/cp4a/odm/odm-decisioncenter --image-scanning-configuration scanOnPush=true --region ${REGION}
  aws ecr create-repository --repository-name cp/cp4a/odm/odm-decisionrunner --image-scanning-configuration scanOnPush=true --region ${REGION}
  aws ecr create-repository --repository-name cp/cp4a/odm/odm-decisionserverruntime --image-scanning-configuration scanOnPush=true --region ${REGION}
  aws ecr create-repository --repository-name cp/cp4a/odm/odm-decisionserverconsole --image-scanning-configuration scanOnPush=true --region ${REGION}
  ```

- Mirror the images to Amazon ECR.

  ```bash
  oc image mirror \
    -f ~/.ibm-pak/data/mirror/$CASE_NAME/$CASE_VERSION/images-mapping.txt \
    --filter-by-os ".*/${ARCHITECTURE}" \
    -a ${REGISTRY_AUTH_FILE}
  ```

  > Note: 
  Only the container images needed for your architecture are uploaded into the registry when specifying the option `--filter-by-os ".*/${ARCHITECTURE}"`

  For more information about these commands, see [Mirroring images to a private container registry](https://www.ibm.com/docs/en/odm/9.5.0?topic=installation-mirroring-images-private-container-registry).

  You can check the repositories and the images available using the commands below :

  ```bash
  # List the repositories
  # expected response: {"repositories":["cp/cp4a/odm/dbserver","cp/cp4a/odm/odm-decisioncenter","cp/cp4a/odm/odm-decisionrunner","cp/cp4a/odm/odm-decisionserverconsole","cp/cp4a/odm/odm-decisionserverruntime"]}
  curl -u AWS:$(aws ecr get-login-password --region ${REGION}) https://$TARGET_REGISTRY/v2/_catalog

  # List the images in each repository
  curl -u AWS:$(aws ecr get-login-password --region ${REGION}) https://$TARGET_REGISTRY/v2/cp/cp4a/odm/dbserver/tags/list
  curl -u AWS:$(aws ecr get-login-password --region ${REGION}) https://$TARGET_REGISTRY/v2/cp/cp4a/odm/odm-decisioncenter/tags/list
  curl -u AWS:$(aws ecr get-login-password --region ${REGION}) https://$TARGET_REGISTRY/v2/cp/cp4a/odm/odm-decisionrunner/tags/list
  curl -u AWS:$(aws ecr get-login-password --region ${REGION}) https://$TARGET_REGISTRY/v2/cp/cp4a/odm/odm-decisionserverruntime/tags/list
  curl -u AWS:$(aws ecr get-login-password --region ${REGION}) https://$TARGET_REGISTRY/v2/cp/cp4a/odm/odm-decisionserverconsole/tags/list
  ```

### c. Create a pull secret for the ECR registry

- The command below creates a secret named `ecrodm` that will be used to pull the images in EKS.

  ```bash
  kubectl create secret docker-registry ecrodm \
    --docker-server=${TARGET_REGISTRY} \
    --docker-username=AWS --docker-password=$(aws ecr get-login-password --region ${REGION})
  ```

### d. Install ODM

- Refer to [Install an IBM Operational Decision Manager release](README.md#5-install-an-ibm-operational-decision-manager-release-10-min) to choose the relevant `.yaml` file to use in the `helm install` command below depending on 
  - the Ingress controller used (NGINX or ALB), 
  - the database used (internal database or the RDS PostgreSQL database).

- Find the Helm Chart version related to your CASE version:

    For instance, if you choose the CASE version `2.0.0`, then the Helm chart version should be `25.0.0` and you should set:
    ```bash
    export CHART_VERSION=25.0.0
    ```

    You can find the Helm chart version related to a given CASE version:

    - For a release: in the page [Upgrading ODM releases on Certified Kubernetes](https://www.ibm.com/docs/en/odm/9.5.0?topic=950-upgrading-odm-releases-certified-kubernetes).

    - For an interim fix: click the link for your version of ODM in the page [Operational Decision Manager Interim Fixes](https://www.ibm.com/support/pages/operational-decision-manager-interim-fixes) and then check the table "Interim fix for ODM on Certified Kubernetes".

    - Alternatively, you can also run the command `tree  ~/.ibm-pak/data/cases/ibm-odm-prod/` (on the bastion host), and you can find the chart version number corresponding to the file `ibm-odm-prod-<CHART_VERSION>.tgz`. Below is an example for CASE version `2.0.0` that corresponds to Helm chart version `25.0.0` :

      ```bash
      /home/user/.ibm-pak/data/cases/ibm-odm-prod/
      └── 2.0.0
          ├── caseDependencyMapping.csv
          ├── charts
          │   └── ibm-odm-prod-25.0.0.tgz
          ├── component-set-config.yaml
          ├── ibm-odm-prod-2.0.0-airgap-metadata.yaml
          ├── ibm-odm-prod-2.0.0-charts.csv
          ├── ibm-odm-prod-2.0.0-images.csv
          ├── ibm-odm-prod-2.0.0.tgz
          └── resourceIndexes
              └── ibm-odm-prod-resourcesIndex.yaml
      ```
- Run the `helm install` command below to install ODM:

  ```bash
  helm install mycompany ibm-helm/ibm-odm-prod --version ${CHART_VERSION} \
      --set image.pullSecrets=ecrodm \
      --set image.repository=${TARGET_REGISTRY}/cp/cp4a/odm \
      --values eks-values.yaml
  ```

  > **Note:**
  > By using `eks-values.yaml`, ODM with a PostgreSQL internal database will be installed. It requires an ALB ingress controller and a server certificate. For more information, see [Provision an AWS Load Balancer Controller](README.md#d-provision-an-aws-load-balancer-controller) and [Manage a digital certificate](README.md#4-manage-a-digital-certificate-10-min).
