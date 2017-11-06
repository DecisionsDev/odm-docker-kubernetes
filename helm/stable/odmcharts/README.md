*-+
# IBM Operational Decision Manager

[IBM® Operational Decision Manager (ODM)](https://www.ibm.com/support/knowledgecenter/SSQP76_8.9.0/welcome/kc_welcome_odmV.html)  is a platform for capturing, automating, and governing repeatable business decisions. You can identify situations to form insights and act with business rules.

## Usages

```console
$ helm install stable/odmcharts
```

## Introduction

This chart bootstraps an IBM ODM deployment on a [Kubernetes](http://kubernetes.io) cluster by using the [Helm](https://helm.sh) package manager.

## Prerequisites

- Kubernetes 1.4+ with Beta APIs enabled
- PV provisioner support in the underlying infrastructure

## Install the Chart

To install the chart with the release name `my-release`:

```console
$ helm install --name my-release stable/odmcharts
```

The command deploys odmcharts on the Kubernetes cluster in the default configuration. The [configuration](#configuration) section lists the parameters that can be configured during installation.

> **Tip**: List all releases using `helm list`

## Uninstall the Chart

To uninstall/delete the `my-release` deployment:

```console
$ helm delete my-release
```

The command removes all the Kubernetes components associated with the chart and deletes the release.

## Configuration

The following tables lists the configurable parameters of the Drupal chart and their default values.

| Parameter                         | Description                           | Default                                                   |
| --------------------------------- | ------------------------------------- | --------------------------------------------------------- |
| `image.repository`                | Specify the Repository                | `odmdocker`                                               |
| `image.tag`                       | Specify the tag image version         | `8.9.0`                                                   |
| `image.pullSecrets`               | Specify the image pull secrets        | `nil` (does not add image pull secrets to deployed pods)  |
| `image.pullPolicy`                | Image pull policy                     | `IfNotPresent`                                            |
| `service.type`                    | Kubernetes Service type               | `NodePort`                                                |
| `persistence.enabled`             | Enable persistence using PVC          | `false`                                                   |
| `persistence.postgresql.user` | This parameter is used in conjunction with 'persistence.postgresql.password' to set a user and its password. This parameter will create the specified user with superuser power and a database with the same name.  | `odm`                                                   |
| `persistence.postgresql.password` | This parameter sets the superuser password for PostgreSQL. The default superuser is defined by the 'persistence.postgresql.user' environment variable.  | `odm`                                                   |
| `persistence.postgresql.databasename` | This parameter can be used to define a different name for the default database that is created when the image is first started.   | `odmdb` |
| `decisionServerRuntime.replicaCount`| Number of the desired runtime       | `2`                                             |
| `decisionCenter.replicaCount`     | Number of the desired Decision Center | `1`                                                     |
| `decisionRunner.replicaCount`     | Number of the desired Decision Runner | `1`                      |


Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`. For example,

```console
$ helm install  odmcharts --set image.pullSecrets=admin.registryKey --set image.repository=mycluster.icp:8500/odmdocker
```

Alternatively, a YAML file that specifies the values for the above parameters can be provided while installing the chart. For example,

```console
$ helm install --name my-release -f values.yaml stable/odmcharts
```

> **Tip**: You can use the default [values.yaml](values.yaml)

## Image

The `image` parameter allows specifying which image will be pulled for the chart.

### Private registry

If you configure the `image` value to one in a private registry, you will need to [specify an image pull secret](https://kubernetes.io/docs/concepts/containers/images/#specifying-imagepullsecrets-on-a-pod).

1. Manually create image pull secret(s) in the namespace. See [this YAML example reference](https://kubernetes.io/docs/concepts/containers/images/#creating-a-secret-with-a-docker-config). Consult your image registry's documentation about getting the appropriate secret.
1. The parameter to configure the SECRET_NAME is in the value.yaml file.
```yaml
image:
  pullSecrets: SECRET_NAME
```
1. Install the chart use the --set image.pullSecrets parameter.
```console
helm install --name my-release odmcharts --set image.pullSecrets=admin.registryKey
```
