# IBM-ODM-Kubernetes
IBM Operational Decision Manager on Certified Kubernetes

[![GitHub release](https://img.shields.io/github/release/ODMDev/odm-docker-kubernetes.svg)](https://github.com/ODMDev/odm-docker-kubernetes/releases)
![GitHub last commit](https://img.shields.io/github/last-commit/ODMDev/odm-docker-kubernetes)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/ibm-odm-charts)](https://artifacthub.io/packages/search?repo=ibm-odm-charts)


##  Deploying IBM Operational Decision Manager on a Certified Kubernetes Cluster

This repository centralizes materials to deploy [IBM® Operational Decision Manager](https://www.ibm.com/docs/en/odm/9.0.0) ODM on Certified Kubernetes. It is deployed in a clustered topology that uses WebSphere® Application Server Liberty on a Kubernetes cluster.

ODM is a decisioning platform to automate your business policies. Business rules are used at the heart of the platform to implement decision logic on a business vocabulary and run it as web decision services.

The ODM Docker material is used here, which is available in the [odm-ondocker](https://github.com/DecisionsDev/odm-ondocker) repository. It includes Docker files and Docker Compose descriptors. The Docker files are used to build images of ODM runtimes. The Docker Compose descriptors can be used to group these images and push to your repository for a Kubernetes provisioning. Docker Compose and Kubernetes are two distinct technology paths to provision a container-based topology supported by ODM.

![Flow](images/ODMinKubernetes-DeploymentOverview.png)

## Supported Versions  

This repository provides materials for the following versions of IBM ODM:  

| ODM Version      |
|--------------|
| **[9.0.0.1 (Latest)](README.md)**    |
| **[8.12.0.1](https://github.com/DecisionsDev/odm-docker-kubernetes/tree/8.12.0.1)**                               |
| **[8.11.0.1](https://github.com/DecisionsDev/odm-docker-kubernetes/tree/8.11.0.1)**                               |

Each version has dedicated deployment instructions and materials tailored to its release. Select the version that matches your requirements for compatibility and features.  

### Deploying ODM Rules on a specific platform

- [Amazon EKS](platform/eks/README.md)
- [Amazon ECS Fargate](platform/ecs/README.md) (BETA)
- [Azure AKS](platform/azure/README.md)
- [Google Cloud GKE](platform/gcloud/README.md)
- [Redhat OpenShift Kubernetes Service on IBM Cloud (ROKS)](platform/roks/README.md)
- [Minikube](platform/minikube/README.md) - Minikube can be used to evaluate ODM locally.

### Integrating with Third-Party Providers

#### Integration with OpenID Providers

To integrate with OpenID providers for authentication and authorization, follow these steps:
- [Configure ODM with an OpenID Okta service](authentication/Okta/README.md)
- [Configure ODM with an Azure Active Directory service](authentication/AzureAD/README.md)
- [Configure ODM with a Keycloak service](authentication/Keycloak/README.md)
- [Configure ODM with a Cognito User Pool](authentication/Cognito/README.md)

#### Managing Secrets within a Vault

Ensure secure management of secrets within your deployment using one of the following methods:


- [Manage secrets with Secret Store CSI Driver](./contrib/secrets-store/README.md): Use the Secrets Store CSI Driver (e.g., HashiCorp Vault) to securely manage sensitive information such as client secrets and keys. This option is designed to minimize configuration efforts and reduce the workload on your part.
- [Manage secrets with Vault via InitContainer](./contrib/vault-initcontainer/README.md): Use an InitContainer to securely retrieve secrets from a Vault (e.g., HashiCorp Vault) and inject them into your application containers. This option requires more hands-on work but it offers greater flexibility to tailor the secret management to your specific requirements.

We encourage you to explore both configurations to identify which setup aligns better with your operational needs and simplicity preferences. 

#### Integration with Analytics Tools
To enable analytics and monitoring capabilities within your deployment, consider integrating with analytics tools using Decisions' monitoring features:
- [MPMetrics Integration](./contrib/monitor/mpmetrics/README.md) : Use MPMetrics for comprehensive monitoring and performance tracking. 
- [OpenTelemetry Integration](./contrib/monitor/opentelemetry/README.md) : Leverage OpenTelemetry for observability and tracing functionalities. This article with guide you to configure your deployment to work seamlessly with OpenTelemetry.


#### Contribution to customize the deployment

- [Scope the Decision Server Console to a dedicated node with `kustomize`](contrib/kustomize/ds-console-dedicated-node/README.md)

## Issues and contributions

For issues relating specifically to the Dockerfiles and scripts, please use the [GitHub issue tracker](https://github.com/ODMDev/odm-docker-kubernetes/issues). For more general issue relating to IBM Operational Decision Manager you can [get help](https://community.ibm.com/community/user/automation/communities/community-home?communitykey=c0005a22-520b-4181-bfad-feffd8bdc022) through the ODMDev community or, if you have production licenses for Operational Decision Manager, via the usual support channels. We welcome contributions following [our guidelines](https://github.com/ODMDev/odm-docker-kubernetes/blob/master/CONTRIBUTING.md).

# Notice
© Copyright IBM Corporation 2025.

## License
```text
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
````
