# IBM-ODM-Kubernetes
IBM Operational Decision Manager on Kubernetes

[![Build Status](https://travis-ci.org/PierreFeillet/IBM-ODM-Kubernetes.svg?branch=master)](https://travis-ci.org/PierreFeillet/IBM-ODM-Kubernetes)


#  Deploy IBM Operational Decision Manager Standard on Kubernetes Cluster

This code demonstrates the deployment of an IBM Operational Decision Manager clustered topology using WAS Liberty on a Bluemix Kubernetes Cluster.

We leverage the ODM Docker material put available on this repository [odm-ondocker](https://github.com/lgrateau/odm-ondocker). It includes Docker files and Docker compose descriptors. In this tutorial we will only use the Docker files to build the ODM runtime images that we will instantiate in the Kubernetes cluster.

![Flow](../images/ODMinKubernetes-Flow.png)

## Included Components
- [IBM ODM](https://www.ibm.com/support/knowledgecenter/SSQP76_8.9.0/welcome/kc_welcome_odmV.html)
- [Kubernetes Cluster](https://console.ng.bluemix.net/docs/containers/cs_ov.html#cs_ov)
- [Bluemix Container Service](https://console.ng.bluemix.net/catalog/?taxonomyNavigation=apps&category=containers)
- [Bluemix DevOps Toolchain Service](https://console.ng.bluemix.net/catalog/services/continuous-delivery)

## Testing
This tutorial has been tested on MacOS.

## Prerequisite

* Create a Kubernetes cluster with either [Minikube](https://kubernetes.io/docs/getting-started-guides/minikube) for local testing, or with [IBM Bluemix Container Service](https://github.com/IBM/container-journey-template) to deploy in cloud. For deploying on Minikube follow the instructions [here](https://github.com/WASdev/sample.microservicebuilder.docs/blob/master/dev_test_local_minikube.md)
* The code in this particular repository is regularly tested against [Kubernetes Cluster from Bluemix Container Service](https://console.ng.bluemix.net/docs/containers/cs_ov.html#cs_ov) using Travis.
* Install a Git client to obtain the sample code.
* Install [Maven](https://maven.apache.org/download.cgi) and a Java 8 JDK.
* Install a [Docker](https://docs.docker.com/engine/installation/) engine.

Web application home page

![Web-app Home Page](images/ui1.png)

When you click on speaker name

![Speaker Info](images/ui2.png)

## Troubleshooting

* If your microservice instance is not running properly, you may check the logs using
	* `kubectl logs <your-pod-name>`
* To delete a microservice
	* `kubectl delete -f manifests/<microservice-yaml-file>`
* To delete everything
	* `kubectl delete -f manifests`


## References
* This java microservices example is based on Kubernete's [Microprofile Showcase Application](https://github.com/WASdev/sample.microservicebuilder.docs).

# License
[Apache 2.0](LICENSE)

