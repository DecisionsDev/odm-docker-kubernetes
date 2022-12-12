# Deploying ODM from images in Azure Container Registry

If you can't use IBM Entitled registry, then you have to download the ODM on Kubernetes package (.tgz file) from Passport Advantage® (PPA) and then push it to the Azure Container Registry.

#### Using the download archives from IBM Passport Advantage (PPA)

Prerequisites:  You must install Docker.

Download the IBM Operational Decision Manager chart and images from [IBM Passport Advantage (PPA)](https://www.ibm.com/software/passportadvantage/pao_customer.html).

Refer to the [ODM download document](https://www.ibm.com/support/pages/node/310661) to view the list of Passport Advantage eAssembly installation images.

Extract the file that contains both the Helm chart and the images.  The name of the file includes the chart version number:

```
$ mkdir ODM-PPA
$ cd ODM-PPA
$ tar zxvf PPA_NAME.tar.gz
charts/ibm-odm-prod-22.2.0.tgz
images/odm-decisionserverconsole_8.11.1.0-amd64.tar.gz
images/odm-decisionserverruntime_8.11.1.0-amd64.tar.gz
images/odm-decisionrunner_8.11.1.0-amd64.tar.gz
images/odm-decisioncenter_8.11.1.0-amd64.tar.gz
images/dbserver_8.11.1.0-amd64.tar.gz
manifest.json
manifest.yaml
```

In order to load the container images from the extracted folder into your Docker registry, you must:

1. Create an [ACR registry](https://docs.microsoft.com/en-US/azure/container-registry/container-registry-get-started-azure-cli):

   ```
   az acr create --resource-group <resourcegroup> --name <registryname> --sku Basic
   ```

   Make a note of the `loginServer` that will be displayed in the JSON output (e.g.: "loginServer": "<registryname>.azurecr.io"):

   ```
   export DOCKER_REGISTRY=<registryname>.azurecr.io
   ```

   > Note: The registry name must be unique within Azure.

2. Log in to the ACR registry

   ```
   az acr login --name <registryname>
   ```

3. Load the container images into your internal Docker registry.

    ```
    $ for name in images/*.tar.gz; do echo $name; docker image load --input $name; done
    ```

4. Tag the images loaded locally with your registry name.

    ```
    export IMAGE_TAG_NAME=${ODM_VERSION:-8.11.1.0}-amd64
    docker tag odm-decisionserverconsole:${IMAGE_TAG_NAME} ${DOCKER_REGISTRY}/odm-decisionserverconsole:${IMAGE_TAG_NAME}
    docker tag dbserver:${IMAGE_TAG_NAME} ${DOCKER_REGISTRY}/dbserver:${IMAGE_TAG_NAME}
    docker tag odm-decisioncenter:${IMAGE_TAG_NAME} ${DOCKER_REGISTRY}/odm-decisioncenter:${IMAGE_TAG_NAME}
    docker tag odm-decisionserverruntime:${IMAGE_TAG_NAME} ${DOCKER_REGISTRY}/odm-decisionserverruntime:${IMAGE_TAG_NAME}
    docker tag odm-decisionrunner:${IMAGE_TAG_NAME} ${DOCKER_REGISTRY}/odm-decisionrunner:${IMAGE_TAG_NAME}
    ```

5. Push the images to your registry.

    ```
    docker push ${DOCKER_REGISTRY}/odm-decisioncenter:${IMAGE_TAG_NAME}
    docker push ${DOCKER_REGISTRY}/odm-decisionserverconsole:${IMAGE_TAG_NAME}
    docker push ${DOCKER_REGISTRY}/odm-decisionserverruntime:${IMAGE_TAG_NAME}
    docker push ${DOCKER_REGISTRY}/odm-decisionrunner:${IMAGE_TAG_NAME}
    docker push ${DOCKER_REGISTRY}/dbserver:${IMAGE_TAG_NAME}
    ```

6. Create a registry key to access the ACR registry.  Refer to the [documentation](https://docs.microsoft.com/en-US/azure/container-registry/container-registry-tutorial-prepare-registry#enable-admin-account) to enable the registry's admin account and get the credentials in the Container registry portal, then:

    ```
    kubectl create secret docker-registry <registrysecret> --docker-server="${DOCKER_REGISTRY}" \
                                                           --docker-username="<adminUsername>" \
                                                           --docker-password="<adminPassword>" \
                                                           --docker-email=<email>
    ```

  Make a note of the secret name so that you can set it for the image.pullSecrets parameter when you run a helm install of your containers. The image.repository parameter must be set to \<loginServer\> (ie ${DOCKER_REGISTRY}).

You can now proceed to the [datasource secret's creation](README.md#create-the-datasource-secrets-for-azure-postgresql).

Note that instead of using

```
helm install <release> ibmcharts/ibm-odm-prod --version 22.2.0 --set image.repository=cp.icr.io/cp/cp4a/odm [...]
```

in later steps, you will have to use

```
helm install <release> charts/ibm-odm-prod-22.2.0.tgz --set image.repository=${DOCKER_REGISTRY} [...]
```

instead.
