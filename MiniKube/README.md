# IBM-ODM-Kubernetes
IBM Operational Decision Manager on Kubernetes MiniKube

#  Deploy IBM Operational Decision Manager Standard on Kubernetes MiniKube

This code demonstrates the deployment of an IBM Operational Decision Manager clustered topology using WAS Liberty on a MiniKube Kubernetes Cluster.

We leverage the ODM Docker material put available on this repository [odm-ondocker](https://github.com/lgrateau/odm-ondocker). It includes Docker files and Docker compose descriptors. In this tutorial we will only use the Docker files to build the ODM runtime images that we will instantiate in the Kubernetes cluster.

![Flow](../images/ODMinKubernetes-Flow.png)

## Included Components
- [IBM ODM](https://www.ibm.com/support/knowledgecenter/SSQP76_8.9.0/welcome/kc_welcome_odmV.html)
- [Kubernetes MiniKube](https://github.com/kubernetes/minikube)
- [Docker-compose](https://docs.docker.com/compose/)

## Testing
This tutorial has been tested on MacOS.

## Prerequisite

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
# 2. Interacting With your Cluster

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

When using a single VM of kubernetes it's really handy to reuse the Docker daemon inside the VM; as this means you don't have to build on your host machine and push the image into a docker registry - you can just build inside the same docker daemon as minikube which speeds up local experiments.

To be able to work with the docker daemon on your mac/linux host use the [docker-env command](./docs/minikube_docker-env.md) in your shell:

```
eval $(minikube docker-env)
```
you should now be able to use docker on the command line on your host mac/linux machine talking to the docker daemon inside the minikube VM:
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
$ kubectl get pods
odm-dbserver-3304526855-2lw7t                1/1       Running   0          1m
odm-decisioncenter-360265097-8wg5v           1/1       Running   0          1m
odm-decisioncenter-360265097-t3v74           1/1       Running   0          1m
odm-decisionrunner-2338004611-28tsj          1/1       Running   0          1m
odm-decisionrunner-2338004611-dtr51          1/1       Running   0          1m
odm-decisionserverconsole-1270041048-fcx7l   1/1       Running   0          1m
odm-decisionserverruntime-3164743559-1kwjf   1/1       Running   0          1m
odm-decisionserverruntime-3164743559-4fvcw   1/1       Running   0          1m```
```


Now you can use the link TODO to access your application on browser.

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

