#  Deploy IBM Operational Decision Manager Standard on Kubernetes MiniKube

This tutorial explains the deployment of an IBM Operational Decision Manager clustered topology on a MiniKube Kubernetes cluster.

We leverage the ODM Docker material put available on this repository [odm-ondocker](https://github.com/lgrateau/odm-ondocker). It includes Docker files and Docker compose descriptors. ODM containers are based on IBM WAS Liberty. In this tutorial we will only use the Docker files to build the ODM runtime images that we will instantiate in the Kubernetes cluster.

![Flow](../images/ODMinKubernetes-Flow.png)

## Included Components
- [IBM ODM](https://www.ibm.com/support/knowledgecenter/SSQP76_8.9.0/welcome/kc_welcome_odmV.html)
- [Kubernetes MiniKube](https://github.com/kubernetes/minikube)
- [Docker-compose](https://docs.docker.com/compose/)

## Testing
This tutorial has been tested on MacOS.

## Prerequisites

* Install a Git client to obtain the sample code.
* Install a [Docker](https://docs.docker.com/engine/installation/) engine.
* [Docker-compose](https://docs.docker.com/compose/) tool.


## Steps

1. [Install MiniKube](#1-install-minikube)
2. [Interacting With your Cluster](#2-interacting-with-your-cluster)
3. [Setup your environment](#3-setup-your-environment)
4. [Get the ODM Docker material](#4-get-the-odm-docker-material)
5. [Create Services and Deployments](#5-create-services-and-deployments)
# 1. Install MiniKube


First, install [MiniKube](https://github.com/kubernetes/minikube).

Then, start minikube.

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

Once MiniKube is installed you can interact with the kubectl tool.

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
# 2. Interacting With your cluster

### Kubectl

The `minikube start` command creates a "[kubectl context](https://kubernetes.io/docs/user-guide/kubectl/v1.6/#-em-set-context-em-)" called "minikube".
This context contains the configuration to communicate with your minikube cluster.

Minikube sets this context to default automatically, but if you need to switch back to it in the future, run:

`kubectl config use-context minikube`,

or pass the context on each command like this: `kubectl get pods --context=minikube`.

### Dashboard

To access the [Kubernetes Dashboard](http://kubernetes.io/docs/user-guide/ui/), run this command in a shell after starting minikube to get the address:
```shell
minikube dashboard
```


# 3. Setup your environment 

When using a single VM Kubernetes it's really handy to reuse the Docker daemon inside the VM. It means that you don't have to build on your host machine and push the images into a docker registry - you can just build inside the same docker daemon as minikube which speeds up the user experience.

To be able to work with the docker daemon on your mac/linux host use the [docker-env command](./docs/minikube_docker-env.md) in your shell:

```
eval $(minikube docker-env)
```
you should now be able to use Docker on the command line on your host mac/linux machine talking to the docker daemon inside the minikube VM:
```
docker ps
```

On Centos 7, docker may report the following error:

```
Could not read CA certificate "/etc/docker/ca.pem": open /etc/docker/ca.pem: no such file or directory
```

The fix is to update /etc/sysconfig/docker to ensure that minikube's environment changes are respected:

```
< DOCKER_CERT_PATH=/etc/docker
---
> if [ -z "${DOCKER_CERT_PATH}" ]; then
>   DOCKER_CERT_PATH=/etc/docker
> fi
```

Remember to turn off the imagePullPolicy:Always, as otherwise kubernetes won't use images you built locally.
# 4. Get the ODM Docker material

* Go to the ODM Install directory, clone the odm docker repository.
```bash
      cd <ODM_INSTALLATION>
      git clone https://github.com/lgrateau/odm-ondocker
      cp odm-ondocker/src/main/resources/.dockerignore ./
      docker-compose build
  ```

you should now be able to use the odm docker images:
```
$ docker images
REPOSITORY                                             TAG                   IMAGE ID            CREATED             SIZE
odmdocker/decisionserverruntime                        8.9.0                 021f34b7a79c        54 minutes ago      482 MB
odmdocker/decisioncenter                               8.9.0                 eaae4b9b4903        57 minutes ago      616 MB
odmdocker/decisionrunner                               8.9.0                 f4a763608c65        58 minutes ago      498 MB
odmdocker/decisionserverconsole                        8.9.0                 d7358780fbde        59 minutes ago      463 MB
odmdocker/dbserver                                     8.9.0                 364f06111328        About an hour ago   658 MB
```
# 5. Create Services and Deployments

Get the public ip of the node

```bash
$ kubectl get nodes
NAME             STATUS    AGE
169.47.241.106   Ready     23h
```
Deploy the odm standard topology from the manifests directory with deployment manifest file :
```bash
$ kubectl create -f odm-standard-minikube.yml
deployment "odm-dbserver" created
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

After few seconds/minutes the following commands to get the ODM Standard containers running in Kubernetes.

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


Now you can use the link to access your application on your browser.

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

