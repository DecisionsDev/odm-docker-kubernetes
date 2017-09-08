#  Deploy IBM Operational Decision Manager Standard on IBM Private Cloud

This tutorial explains the deployment of an IBM Operational Decision Manager clustered topology on a IBM Private Cloud Kubernetes cluster.

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
2. [Interacting with your cluster](#2-interacting-with-your-cluster)
3. [Setup your environment](#3-setup-your-environment)
5. [Create services and deployments](#5-create-services-and-deployments)

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

# 4. Deploy an ODM topology with admin console.
  - Logon in the IBM Cloud Private console.
  - Add the ODM Charts repository (System->Repositories) if needed.
  - Go to the App Center. 
  	- You should see the ODM Chart in the package List.
![AppCenter](../images/ODM-IBMPrivateCloud-AppCenter.jpg)
	- Click install button in the ODM Chart
![AppCenter-Inst](../images/ODM-IBMPrivateCloud-AppCenterInst.jpg)


The URL is accessible TODO.

# 5. Deploy a topology with the Kubectl command line tool.

# 5.1. Interacting with your cluster

To interact with kubectl tool you need to set environment variable.

This setting is available in the IBM Private console (username->configure client) or explain in the [IBM Cloud Private knowledge center](https://www.ibm.com/support/knowledgecenter/en/SSBS6K_1.2.0/manage_cluster/cfc_cli.html)  



# 5.2 Deploy the ODM Helm Chart:
```bash
	cd IBM-ODM-Kubernetes/helm/incubator
	helm install odmchart
 ```

To install Helm client please follow this [guide](https://github.com/kubernetes/helm/blob/master/docs/install.md).
```bash
This should display something like that : 
NAME:   zooming-tuatara
LAST DEPLOYED: Tue Sep  5 16:19:10 2017
NAMESPACE: default
STATUS: DEPLOYED

RESOURCES:
==> v1/ConfigMap
NAME                       DATA  AGE
zooming-tuatara-configmap  1     1s

==> v1/Service
NAME                       CLUSTER-IP  EXTERNAL-IP  PORT(S)         AGE
odm-decisionrunner         10.0.0.13   <nodes>      9080:30492/TCP  1s
dbserver                   10.0.0.31   <nodes>      1527:32713/TCP  1s
odm-decisionserverconsole  10.0.0.2    <nodes>      9080:32448/TCP  1s
odm-decisioncenter         10.0.0.241  <nodes>      9060:30573/TCP  1s
odm-decisionserverruntime  10.0.0.205  <nodes>      9080:31173/TCP  1s

==> v1beta1/Deployment
NAME                       DESIRED  CURRENT  UP-TO-DATE  AVAILABLE  AGE
odm-decisionrunner         1        1        1           0          1s
dbserver                   1        1        1           0          1s
odm-decisionserverruntime  2        2        2           0          1s
odm-decisionserverconsole  1        1        1           0          1s
odm-decisioncenter         1        1        1           0          1s


NOTES:
Thank you for installing odmcharts.

Your release is named zooming-tuatara.

To learn more about the release, try:

  $ helm status zooming-tuatara
  $ helm get zooming-tuatara



You can list the deployed helm by using this command : helm list
You remove the previous installed chart by this command : helm delete zooming-tuatara

1. Get the application URL by running these commands:
  export NODE_PORT=$(kubectl get --namespace default -o jsonpath="{.spec.ports[0].nodePort}" services zooming-tuatara-odmcharts)
  export NODE_IP=$(kubectl get nodes --namespace default -o jsonpath="{.items[0].status.addresses[0].address}")
  echo http://$NODE_IP:$NODE_PORT


For more informations about this template you can take a look in this github https://github.com/PierreFeillet/IBM-ODM-Kubernetes
 ```



Now you can use the link to access your application on your browser.

TODO TODO TODO


* For Decision Server Runtime:
```bash
minikube service odm-decisionserverruntime  --url
http://192.168.99.100:31204/ 
```
Then, open your browser to this URL : http://192.168.99.100:31204/**_DecisionService_**

* For Decision Server Console:
```bash
minikube service odm-decisionserverconsole  --url
http://192.168.99.100:32519 
```
Then, open your browser to this URL Ex: http://192.168.99.100:31204/*****res*****

* For Decision Runner:
```bash
minikube service odm-decisionrunner  --url
http://192.168.99.100:32519 
```
Then, open your browser to this URL Ex: http://192.168.99.100:31204/*****testing*****

* For Decision Center:
```bash
minikube service odm-decisioncenter  --url
http://192.168.99.100:32519 
```
Then, open your browser to this URL Ex:
   * Decision Center Console : http://192.168.99.100:31204/**_decisioncenter/t/library_**
   * TeamServer : http://192.168.99.100:31204/*****teamserver*****

If you want to delete the ODM standard images use this command:
```bash
$ kubectl delete -f odm-standard-minikube.yml
deployment "odm-dbserver" deleted
service "dbserver" deleted
deployment "odm-decisionserverconsole" deleted
service "odm-decisionserverconsole" deleted
deployment "odm-decisionserverruntime" deleted
service "odm-decisionserverruntime" deleted
deployment "odm-decisioncenter" deleted
service "odm-decisioncenter" deleted
deployment "odm-decisionrunner" deleted
service "odm-decisionrunner" deleted
```


# License
[Apache 2.0](LICENSE)

