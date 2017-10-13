# IBM-ODM-Kubernetes
IBM Operational Decision Manager on Kubernetes

[![Build Status](https://travis-ci.org/ODMDev/odm-docker-kubernetes.svg?branch=master)](https://travis-ci.org/ODMDev/odm-docker-kubernetes)
[![GitHub release](https://img.shields.io/github/release/ODMDev/odm-docker-kubernetes.svg)](https://github.com/ODMDev/odm-docker-kubernetes/releases)
[![GitHub last commit (branch)](https://img.shields.io/github/last-commit/ODMDev/odm-docker-kubernetes/dev.svg)](https://github.com/ODMDev/odm-docker-kubernetes)
[![Apache 2.0][license-badge]](https://github.com/ODMDev/odm-docker-kubernetes/blob/master/LICENSE)

<p align="center">
  <a href="https://join.slack.com/t/odmdev/shared_invite/enQtMjU0NzIwMjM1MTg0LTQyYTMzNGQ4NzJkMDYxMDU5MDRmYTM4MjcxN2RiMzNmZWZmY2UzYzRhMjk0N2FmZjU2YzJlMTRmN2FhZDY4NmQ">
        Follow us on slack
        <br>
        <img src="https://a.slack-edge.com/436da/marketing/img/meta/favicon-32.png">
  </a>
</p>

#  Deploy IBM Operational Decision Manager Standard on a Kubernetes Cluster

This repository centralizes the material to deploy IBM Operational Decision Manager Standard in Kubernetes. clustered topology using WAS Liberty on a Kubernetes Cluster.

[IBM ODM](https://www.ibm.com/support/knowledgecenter/SSQP76_8.9.0/welcome/kc_welcome_odmV.html) is a decisioning platform to automate your business policies. Business rules are used at the heart of the platform to implement decision logic on a business vocabulary and run it as web decision services.

We leverage the ODM Docker material put available on this repository [odm-ondocker](https://github.com/lgrateau/odm-ondocker). It includes Docker files and Docker compose descriptors. Docker files are used to build images of ODM runtimes. And Docker compose desctiptor can be used to group this build and push to your repository for a Kubernetes provisioning. Nevertheless Docker Compose and Kubernetes are 2 distinct technology paths to provision an contain based topology supported by ODM Standard.

![Flow](images/ODMinKubernetes-DeploymentOverview.png)

## Deploying ODM Rules in the following environments
- [Bluemix Kubernetes Cluster](Bluemix/README.md)
- [MiniKube](MiniKube/README.md)

## References

# Notice
© Copyright IBM Corporation 2017.

# License
```text
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
````

