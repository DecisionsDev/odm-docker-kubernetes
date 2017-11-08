#  Deploy IBM Operational Decision Manager Standard on IBM Private cloud

This tutorial explains the deployment of an IBM® Operational Decision Manager clustered topology on IBM Cloud private, based on Kubernetes technology.

We use ODM Docker materials and make them available in the repository [odm-ondocker](https://github.com/ODMDev/odm-ondocker). It includes Docker files and Docker Compose descriptors. ODM containers are based on IBM WebSphere® Application Server Liberty. In this tutorial, we use only the Docker files to build ODM runtime images that will be instantiated in the Kubernetes cluster.

![Flow](../images/ODMinKubernetes-Flow.png)

## Included Components
- [IBM ODM](https://www.ibm.com/support/knowledgecenter/SSQP76_8.9.0/welcome/kc_welcome_odmV.html)
- [IBM Private Cloud](https://www.ibm.com/cloud-computing/products/ibm-cloud-private/)
- [Docker-compose](https://docs.docker.com/compose/)

## Test environment
This tutorial was tested on MacOS.

## Prerequisites

* Install a Git client to obtain the sample code.
* Install a [Docker](https://docs.docker.com/engine/installation/) engine.
* [Docker-compose](https://docs.docker.com/compose/) tool.

## Steps

1. [Install and configure IBM Cloud private](#1-install-and-configure-ibm-private-cloud)
2. [Get the ODM Docker material](#2-get-the-odm-docker-material)
3. [Tag and deploy the ODM Docker material in the IBM Cloud private Docker registry](#3-tag-and-deploy-odm-docker-material-in-the-ibm-cloud-private-docker-registry)
4. [Deploy an ODM topology with the admin console](#4-deploy-an-odm-topology-with-the-admin-console)
5. [Deploy an ODM topology with the Helm command line tool](#5-deploy-an-odm-topology-with-a-command-line)
6. [Create services and deployments](#5-create-services-and-deployments)

# 1. Install and configure IBM Cloud private


Install [IBM Cloud private](https://www.ibm.com/support/knowledgecenter/en/SSBS6K_1.2.0/installing/installing.html).


You can interact with the admin console when IBM Cloud private is installed.


# 2. Get the ODM Docker material

* Go to the ODM installation directory and clone the ODM docker repository.
```bash
      cd <ODM_INSTALLATION>
      git clone https://github.com/ODMDev/odm-ondocker
      cp odm-ondocker/resources/.dockerignore ./
      cd odm-ondocker
      docker-compose build
  ```

# 3. Tag and deploy the ODM Docker material in the IBM Cloud private Docker registry

In this use case, we use the [IBM Cloud private Docker registry]

```bash
    docker login mycluster.icp:8500 (username/password)  -> admin/admin by default.

    docker tag ibmcom/dbserver:8.9.0 mycluster.icp:8500/ibmcom/dbserver:8.9.0
    docker push mycluster.icp:8500/ibmcom/dbserver:8.9.0

    docker tag ibmcom/odm-decisionserverconsole:8.9.0 mycluster.icp:8500/ibmcom/odm-decisionserverconsole:8.9.0
    docker push  mycluster.icp:8500/ibmcom/odm-decisionserverconsole:8.9.0

    docker tag ibmcom/odm-decisionrunner:8.9.0  mycluster.icp:8500/ibmcom/odm-decisionrunner:8.9.0
    docker push  mycluster.icp:8500/ibmcom/odm-decisionrunner:8.9.0

    docker tag ibmcom/odm-decisionserverruntime:8.9.0 mycluster.icp:8500/ibmcom/odm-decisionserverruntime:8.9.0
    docker push mycluster.icp:8500/ibmcom/odm-decisionserverruntime:8.9.0

    docker tag ibmcom/odm-decisioncenter:8.9.0 mycluster.icp:8500/ibmcom/odm-decisioncenter:8.9.0
    docker push mycluster.icp:8500/ibmcom/odm-decisioncenter:8.9.0
  ```


For more information, see [Working with your IBM Cloud private Docker registry](https://www.ibm.com/developerworks/community/blogs/fe25b4ef-ea6a-4d86-a629-6f87ccf4649e/entry/Working_with_the_local_docker_registry_from_Spectrum_Conductor_for_Containers?lang=en)

# 4. Deploy an ODM topology with the admin console
  - Log on to the IBM Cloud private console.
  - Go to System > Repositories, and add an ODM charts repository.
 ![AppCenter](../images/ODM-IBMPrivateCloud-AddRepository.jpg)
    - Click Add Repository
    - Name: odmcharts
    - URL :  https://odmdev.github.io/odm-helm-charts-repo/

  - Go to App Center.
  	- You can see the ODM chart in the package list.
![AppCenter](../images/ODM-IBMPrivateCloud-AppCenter.jpg)
	- Click Install Package in the ODM chart
![AppCenter-Inst](../images/ODM-IBMPrivateCloud-AppCenterInst.jpg)
https://odmdev.github.io/odm-helm-charts-repo/

Descriptions of ODM charts parameters are available in the Helm [README](../helm/stable/odmcharts/README.md) file.
# 5. Deploy an ODM topology with the Helm command line tool

# 5.1. Interact with your cluster

You must set environment variables to interact with kubectl and Helm tools.

Click the user name, and select Configure Client in the IBM Cloud private console.

![AppCenter-Username](../images/ODM-IBMPrivateCloud-SetupVariable.jpg)
  - Click Configure Client.
  - Open a command line, and follow the instructions in the topic [Accessing your IBM Cloud private cluster by using the kubectl CLI](https://www.ibm.com/support/knowledgecenter/en/SSBS6K_1.2.0/manage_cluster/cfc_cli.html) in IBM Knowledge Center.

For more information about installating the Helm tool, see [].

# 5.2 Verify the secret of the registry

You verify that the secret of the registry is available.

For more information, see [Identifying the imagePullSecrets value for your namespace](
https://www.ibm.com/support/knowledgecenter/en/SSBS6K_2.1.0/manage_images/imagepullsecret.html) in IBM Knowledge Center.

```bash
  kubect get secrets
 ```   
You can see your private key.

  - If you do not see it, create a new one.
```bash
  kubectl create secret docker-registry  admin.registrykey --docker-server=mycluster.icp:8500 --docker-username=admin --docker-password=admin --docker-email=laurent.grateau@fr.ibm.com
 ```   

# 5.3 Deploy the ODM Helm chart:
```bash
	cd IBM-ODM-Kubernetes/IBMCloudPrivate
	helm install  odmcharts --set image.pullSecrets=admin.registrykey --set image.repository=mycluster.icp:8500/ibmcom
 ```

To install the Helm client, follow this [instructions](https://github.com/kubernetes/helm/blob/master/docs/install.md).
```bash
NAME:   snug-dog
LAST DEPLOYED: Sun Sep 17 11:10:33 2017
NAMESPACE: default
STATUS: DEPLOYED

RESOURCES:
==> v1/Service
NAME                       CLUSTER-IP  EXTERNAL-IP  PORT(S)         AGE
odm-decisionserverconsole  10.0.0.93   <nodes>      9080:30686/TCP  1s
odm-decisionrunner         10.0.0.137  <nodes>      9080:30533/TCP  1s
odm-decisioncenter         10.0.0.102  <nodes>      9060:31040/TCP  1s
dbserver                   10.0.0.99   <nodes>      1527:32359/TCP  1s
odm-decisionserverruntime  10.0.0.154  <nodes>      9080:32072/TCP  1s

==> v1beta1/Deployment
NAME                       DESIRED  CURRENT  UP-TO-DATE  AVAILABLE  AGE
odm-decisionserverruntime  2        2        2           0          1s
odm-decisionrunner         1        1        1           0          1s
dbserver                   1        1        1           0          1s
odm-decisioncenter         1        1        1           0          1s
odm-decisionserverconsole  1        1        1           0          1s


NOTES:
Thank you for installing odmcharts.

For more informations about this template you can take a look in this github https://github.com/ODMDev/odm-docker-kubernetes

ODM Informations
-----------------

Username/Password :
  - For Business Console : rtsAdmin/rtsAdmin
  - For RES : resAdmin/resAdmin
  - For Decision Runner: resDeployer/resDeployer

1. Get the application URL by running these commands:

-- Decision Center / Business Console
  export NODE_PORT_DC=$(kubectl get --namespace default -o jsonpath="{.spec.ports[0].nodePort}" services odm-decisioncenter)
  export NODE_IP=$(kubectl get nodes --namespace default -o jsonpath="{.items[0].status.addresses[0].address}")
  * Decision Center / Business Console
  echo http://$NODE_IP:$NODE_PORT_DC/decisioncenter

  * Team Server
  echo http://$NODE_IP:$NODE_PORT_DC/teamserver

-- Testing and Simulation
  export NODE_PORT_DR=$(kubectl get --namespace default -o jsonpath="{.spec.ports[0].nodePort}" services odm-decisionrunner)
  export NODE_IP=$(kubectl get nodes --namespace default -o jsonpath="{.items[0].status.addresses[0].address}")
  * Decision Runner
  echo http://$NODE_IP:$NODE_PORT_DR/DecisionRunner


-- Decision Service Console (RES Console)
  export NODE_PORT_DSC=$(kubectl get --namespace default -o jsonpath="{.spec.ports[0].nodePort}" services odm-decisionserverconsole)
  export NODE_IP=$(kubectl get nodes --namespace default -o jsonpath="{.items[0].status.addresses[0].address}")
  * Decision Service Console (RES Console)
  echo http://$NODE_IP:$NODE_PORT_DSC/res


-- Decision Service Runtime (Htds)
 export NODE_PORT_DSC=$(kubectl get --namespace default -o jsonpath="{.spec.ports[0].nodePort}" services odm-decisionserverruntime)
  export NODE_IP=$(kubectl get nodes --namespace default -o jsonpath="{.items[0].status.addresses[0].address}")
  * Decision Service Runtime
  echo http://$NODE_IP:$NODE_PORT_DSC/DecisionService



Your release is named snug-dog.

To learn more about the release, try:

  $ helm status snug-dog
  $ helm get snug-dog
  ````



# License
[Apache 2.0](LICENSE)
