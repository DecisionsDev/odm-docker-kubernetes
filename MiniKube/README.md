#  Deploying IBM Operational Decision Manager Standard on Kubernetes Minikube

This tutorial explains the deployment of an IBM® Operational Decision Manager (ODM) clustered topology on a Minikube Kubernetes cluster.

Use the ODM Docker material that is available in the [odm-ondocker](https://github.com/lgrateau/odm-ondocker) repository. It includes Docker files and Docker compose descriptors. ODM containers are based on IBM WebSphere® Application Server Liberty. In this tutorial, we use only the Docker files to build the ODM runtime images that will be instantiated in the Kubernetes cluster.

![Flow](../images/ODMinKubernetes-Flow.png)

## Included Components
- [IBM ODM](https://www.ibm.com/support/knowledgecenter/SSQP76_8.9.0/welcome/kc_welcome_odmV.html)
- [Kubernetes Minikube](https://github.com/kubernetes/minikube)
- [Docker-compose](https://docs.docker.com/compose/)

## Test environment
This tutorial was tested on MacOS.

## Prerequisites

* Install a Git client to obtain the sample code.
* Install a [Docker](https://docs.docker.com/engine/installation/) engine.
* [Docker-compose](https://docs.docker.com/compose/) tool.


## Steps

1. [Installing Minikube](#1-installing-minikube)
2. [Interacting with your cluster](#2-interacting-with-your-cluster)
3. [Setting up your environment](#3-setting-up-your-environment)
4. [Getting the ODM Docker material](#4-getting-the-odm-docker-material)
5. [Creating services and deployments](#5-creating-services-and-deployments)

# 1. Installing Minikube


Install [Minikube](https://github.com/kubernetes/minikube).

Start Minikube.

```bash
$ minikube start
Starting local Kubernetes v1.6.0 cluster...
Starting VM...
SSH-ing files into VM...
Setting up certs...
Starting cluster components...
Connecting to cluster...
Setting up kubeconfig...
Kubectl is now configured to use the cluster.
```

After Minikube is installed, you can interact with the kubectl tool.

```bash
$ kubectl run hello-minikube --image=gcr.io/google_containers/echoserver:1.4 --port=8080
deployment "hello-minikube" created
$ kubectl expose deployment hello-minikube --type=NodePort
service "hello-minikube" exposed

# We have now launched an echoserver pod but we have to wait until the pod is up before curling/accessing it
# via the exposed service.
# To check whether the pod is up and running we can use the following:
$ kubectl get pod
NAME                              READY     STATUS              RESTARTS   AGE
hello-minikube-3383150820-vctvh   1/1       ContainerCreating   0          3s
# We can see that the pod is still being created from the ContainerCreating status
$ kubectl get pod
NAME                              READY     STATUS    RESTARTS   AGE
hello-minikube-3383150820-vctvh   1/1       Running   0          13s
# We can see that the pod is now Running and we will now be able to curl it:
$ curl $(minikube service hello-minikube --url)
CLIENT VALUES:
client_address=192.168.99.1
command=GET
real path=/
```
# 2. Interacting with your cluster

### Kubectl

The `minikube start` command creates a "[kubectl context](https://kubernetes.io/docs/user-guide/kubectl/v1.6/#-em-set-context-em-)" called "minikube". This context contains the configuration to communicate with your minikube cluster.

This context is also set as default automatically. If you want to change it to another context, run the following command:
```
kubectl config use-context minikube
```

Here is another way to set the context: 
```
kubectl get pods --context=minikube
```

### Dashboard

To access the [Kubernetes Dashboard](http://kubernetes.io/docs/user-guide/ui/), run the following command in a shell after starting Minikube to get the address:
```shell
minikube dashboard
```


# 3. Setting up your environment

When you use a single VM Kubernetes, it is handy to reuse the Docker daemon inside the VM. It means that you do not have to build on your host machine and push the images into a Docker registry. You can just build inside the same Docker daemon as Minikube, which speeds up the user experience.

To work with the docker daemon on your Mac/Linux host, use the [docker-env command](./docs/minikube_docker-env.md) in your shell:

```
eval $(minikube docker-env)
```
You are now able to use Docker in the command line on your host Mac/Linux machine that is talking to the Docker daemon inside the Minikube VM:
```
docker ps
```

On Centos 7, Docker might report the following error:

```
Could not read CA certificate "/etc/docker/ca.pem": open /etc/docker/ca.pem: no such file or directory
```

To fix this error, update /etc/sysconfig/docker to ensure that changes in the Minikube's environment are respected:

```
< DOCKER_CERT_PATH=/etc/docker
---
> if [ -z "${DOCKER_CERT_PATH}" ]; then
>   DOCKER_CERT_PATH=/etc/docker
> fi
```

Remember to turn off `imagePullPolicy:Always`, otherwise Kubernetes will not use the images that you built locally.

# 4. Getting the ODM Docker material

Go to the ODM installation directory, and clone the ODM Docker repository:
```bash
$ cd <ODM_INSTALLATION>
$ git clone https://github.com/lgrateau/odm-ondocker
$ cp odm-ondocker/src/main/resources/.dockerignore ./
$ docker-compose build
  ```

You are now able to use the ODM Docker images:
```
$ docker images
REPOSITORY                                         TAG                   IMAGE ID            CREATED             SIZE
ibmcom/odm-decisionserverruntime                   8.9.0                 021f34b7a79c        54 minutes ago      482 MB
ibmcom/odm-decisioncenter                          8.9.0                 eaae4b9b4903        57 minutes ago      616 MB
ibmcom/odm-decisionrunner                          8.9.0                 f4a763608c65        58 minutes ago      498 MB
ibmcom/odm-decisionserverconsole                   8.9.0                 d7358780fbde        59 minutes ago      463 MB
ibmcom/dbserver                                    8.9.0                 364f06111328        About an hour ago   658 MB
```
# 5. Creating services and deployments

Get the public IP of the node:

```bash
$ kubectl get nodes
NAME             STATUS    AGE
169.47.241.106   Ready     23h
```
Deploy the ODM Standard topology from the manifests directory with the deployment manifest file:
```bash
$ kubectl create -f odm-standard-minikube.yml
deployment "dbserver" created
service "dbserver" created
deployment "odm-decisionserverconsole" created
service "odm-decisionserverconsole" created
deployment "odm-decisionserverruntime" created
service "odm-decisionserverruntime" created
deployment "odm-decisioncenter" created
service "odm-decisioncenter" created
deployment "odm-decisionrunner" created
service "odm-decisionrunner" created
```

After a few seconds/minutes, run the following command to get the ODM Standard containers that are running in Kubernetes:

```bash
$ kubectl get services
NAME                        CLUSTER-IP   EXTERNAL-IP   PORT(S)          AGE
dbserver                    10.0.0.182   <nodes>       1527:31096/TCP   20m
kubernetes                  10.0.0.1     <none>        443/TCP          2h
odm-decisioncenter          10.0.0.137   <nodes>       9060:32425/TCP   20m
odm-decisionrunner          10.0.0.192   <nodes>       9070:32063/TCP   20m
odm-decisionserverconsole   10.0.0.220   <nodes>       9080:32519/TCP   20m
odm-decisionserverruntime   10.0.0.112   <nodes>       9080:31204/TCP   20m
```


Now you can use the following links to access your application on your browser.

* Decision Server runtime:
```bash
$ minikube service odm-decisionserverruntime  --url
http://192.168.99.100:31204/
```
   Then, open this URL in your browser. For example: http://192.168.99.100:31204/**_DecisionService_**

* Decision Server console:
```bash
$ minikube service odm-decisionserverconsole  --url
http://192.168.99.100:32519
```
   Then, open this URL in your browser. For example: http://192.168.99.100:31204/*****res*****

* Decision Runner:
```bash
$ minikube service odm-decisionrunner  --url
http://192.168.99.100:32519
```
   Then, open this URL in your browser. For example: http://192.168.99.100:31204/*****testing*****

* Decision Center:
```bash
$ minikube service odm-decisioncenter  --url
http://192.168.99.100:32519
```
   Then, open this URL in our browser. For example:
   * Decision Center console : http://192.168.99.100:31204/**_decisioncenter/t/library_**
   * TeamServer : http://192.168.99.100:31204/*****teamserver*****

If you want to delete the ODM Standard images, use the following command:
```bash
$ kubectl delete -f odm-standard-minikube.yml
deployment "dbserver" deleted
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
