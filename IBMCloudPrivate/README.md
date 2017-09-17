#  Deploy IBM Operational Decision Manager Standard on IBM Private Cloud

This tutorial explains the deployment of an IBM Operational Decision Manager clustered topology on IBM Private Cloud , based on Kubernetes technology.

We leverage the ODM Docker material put available on this repository [odm-ondocker](https://github.com/ODMDev/odm-ondocker). It includes Docker files and Docker compose descriptors. ODM containers are based on IBM WAS Liberty. In this tutorial we will only use the Docker files to build the ODM runtime images that we will instantiate in the Kubernetes cluster.

![Flow](../images/ODMinKubernetes-Flow.png)

## Included Components
- [IBM ODM](https://www.ibm.com/support/knowledgecenter/SSQP76_8.9.0/welcome/kc_welcome_odmV.html)
- [IBM Private Cloud](https://www.ibm.com/cloud-computing/products/ibm-cloud-private/)
- [Docker-compose](https://docs.docker.com/compose/)

## Testing
This tutorial has been tested on MacOS.

## Prerequisites

* Install a Git client to obtain the sample code.
* Install a [Docker](https://docs.docker.com/engine/installation/) engine.
* [Docker-compose](https://docs.docker.com/compose/) tool.

## Steps

1. [Install and configure IBM Private Cloud](#1-install-and-configure-ibm-private-cloud)
2. [Get the ODM Docker material](#2-get-the-odm-docker-material)
3. [Tag and deploy ODM Docker material in the IBM Cloud Private Docker Registry](#3-tag-and-deploy-odm-docker-material-in-the-ibm-cloud-private-docker-registry)
4. [Deploy an ODM topology with the admin console](#4-deploy-an-odm-topology-with-the-admin-console)
5. [Deploy an ODM topology with a command line](#5-deploy-an-odm-topology-with-a-command-line)
6. [Create services and deployments](#5-create-services-and-deployments)

# 1. Install and configure IBM Private Cloud


First, install [IBM Private Cloud](https://www.ibm.com/support/knowledgecenter/en/SSBS6K_1.2.0/installing/installing.html).


Once IBM Private Cloud is installed you can interact with the admin console.


# 2. Get the ODM Docker material

* Go to the ODM Install directory, clone the odm docker repository.
```bash
      cd <ODM_INSTALLATION>
      git clone https://github.com/ODMDev/odm-ondocker
      cp odm-ondocker/src/main/resources/.dockerignore ./
      docker-compose build
  ```

# 3. Tag and deploy ODM Docker material in the IBM Cloud Private Docker Registry.

In this usecase, we will the [IBM Cloud Private Docker Registry]

```bash
    docker login mycluster:8500 (username/password)  -> admin/admin by default.
    
    docker tag odmdocker/dbserver:8.9.0 mycluster:8500/odmdocker/dbserver:8.9.0
    docker push mycluster:8500/odmdocker/dbserver:8.9.0
    
    docker tag odmdocker/decisionserverconsole:8.9.0 mycluster:8500/odmdocker/decisionserverconsole:8.9.0
    docker push  mycluster:8500/odmdocker/decisionserverconsole:8.9.0
    
    docker tag odmdocker/decisionrunner:8.9.0  mycluster:8500/odmdocker/decisionrunner:8.9.0
    docker push  mycluster:8500/odmdocker/decisionrunner:8.9.0
    
    docker tag odmdocker/decisionserverruntime:8.9.0 mycluster:8500/odmdocker/decisionserverruntime:8.9.0
    docker push mycluster:8500/odmdocker/decisionserverruntime:8.9.0
    
    docker tag odmdocker/decisioncenter:8.9.0 mycluster:8500/odmdocker/decisioncenter:8.9.0
    docker push mycluster:8500/odmdocker/decisioncenter:8.9.0
  ```


More informations could be found [here](https://www.ibm.com/developerworks/community/blogs/fe25b4ef-ea6a-4d86-a629-6f87ccf4649e/entry/Working_with_the_local_docker_registry_from_Spectrum_Conductor_for_Containers?lang=en)

# 4. Deploy an ODM topology with the admin console.
  - Logon in the IBM Cloud Private console.
  - Add the ODM Charts repository (System->Repositories) 
 ![AppCenter](../images/ODM-IBMPrivateCloud-AddRepository.jpg)
    - Click Add Repository
    - Name: odmcharts
    - URL : https://odmdev.github.io/odm-docker-kubernetes/
 
  - Go to the App Center. 
  	- You should see the ODM Chart in the package List.
![AppCenter](../images/ODM-IBMPrivateCloud-AppCenter.jpg)
	- Click install button in the ODM Chart
![AppCenter-Inst](../images/ODM-IBMPrivateCloud-AppCenterInst.jpg)
https://odmdev.github.io/odm-docker-kubernetes/


# 5. Deploy an ODM topology with the helm command line tool.

# 5.1. Interacting with your cluster

To interact with kubectl and helm tools you need to set environment variable.

This setting is available in the IBM Private console (username->configure client) 

![AppCenter-Username](../images/ODM-IBMPrivateCloud-SetupVariable.jpg)
  - Click *Configure Client*
  - Open a command line and copy paste the instructions.

 [IBM Cloud Private knowledge center](https://www.ibm.com/support/knowledgecenter/en/SSBS6K_1.2.0/manage_cluster/cfc_cli.html)  

Installation instruction for helm tool can be found here : 

# 5.2 Deploy the ODM Helm Chart:
```bash
	cd IBM-ODM-Kubernetes/IBMCloudPrivate
	helm install odmcharts
 ```

To install Helm client please follow this [guide](https://github.com/kubernetes/helm/blob/master/docs/install.md).
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

