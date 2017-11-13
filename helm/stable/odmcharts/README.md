# Installing the IBM Operational Decision Manager chart

[IBM® Operational Decision Manager (ODM)](https://www.ibm.com/support/knowledgecenter/SSQP76_8.9.0/welcome/kc_welcome_odmV.html) is a platform for capturing, automating, and governing repeatable business decisions. You can identify situations to form insights and act with business rules.

The ODM chart (`odmchart`) bootstraps an IBM ODM deployment on a [Kubernetes](http://kubernetes.io) cluster by using the [Helm](https://helm.sh) package manager.

## Prerequisites

- Kubernetes 1.4+ with Beta APIs enabled
- PV provisioner support in the underlying infrastructure

## Installing the ODM chart

Install the chart with a release name (for example: `my-release`) by using the following command:

```console
$ helm install --name my-release stable/odmcharts
```

This command deploys `odmcharts` on the Kubernetes cluster in the default configuration. 
For information about the parameters that can be configured during the installation, see the [Configuration parameters](#configuration-parameters) section.

> **Tip**: You can list all releases by using the `helm list` command.

## Uninstalling the chart

You can uninstall and delete the `my-release` deployment by using the following command:

```console
$ helm delete my-release
```

This command removes all the Kubernetes components that are associated with the chart, and deletes the release.

## Configuration parameters

The following tables shows the configurable parameters of the Drupal chart and their default values.

| Parameter                         | Description                           | Default value                                                   |
| --------------------------------- | ------------------------------------- | --------------------------------------------------------- |
| `image.repository`                | Specify the repository                | `odmdocker`                                               |
| `image.tag`                       | Specify the tag image version         | `8.9.0`                                                   |
| `image.pullSecrets`               | Specify the image pull secrets        | `nil` (does not add image pull secrets to deployed pods)  |
| `image.pullPolicy`                | Image pull policy                     | `IfNotPresent`                                            |
| `service.type`                    | Kubernetes service type               | `NodePort`                                                |
| `persistence.enabled`             | Enable persistence by using PVC       | `false`                                                   |
| `persistence.postgresql.user` | This parameter is used in conjunction with `persistence.postgresql.password` to set a user and his password. This parameter will create the specified user with superuser power and a database with the same name.  | `odm`                                                   |
| `persistence.postgresql.password` | This parameter sets the superuser password for PostgreSQL. The default superuser is defined by the `persistence.postgresql.user` environment variable.  | `odm`                                                   |
| `persistence.postgresql.databasename` | This parameter can be used to define a different name for the default database that is created when the image is first started.   | `odmdb` |
| `decisionServerRuntime.replicaCount`| Number of desired runtime       | `2`                                             |
| `decisionCenter.replicaCount`     | Number of desired Decision Center | `1`                                                     |
| `decisionRunner.replicaCount`     | Number of desired Decision Runner | `1`                      |


You can specify each parameter by using the `--set key=value[,key=value]` argument in the `helm install` command. 
For example:

```console
$ helm install  odmcharts --set image.pullSecrets=admin.registryKey --set image.repository=mycluster.icp:8500/odmdocker
```

Alternatively, you can provide a YAML file that specifies the values of these parameters when you install the chart. 
For example:

```console
$ helm install --name my-release -f values.yaml stable/odmcharts
```

> **Tip**: You can use the default [values.yaml](values.yaml) file.

## Image

The `image` parameter can be used to specify which image will be pulled for the chart.

### Private registry

If you set the `image` value to one in a private registry, you must [specify an image pull secret](https://kubernetes.io/docs/concepts/containers/images/#specifying-imagepullsecrets-on-a-pod).

1. Manually create image pull secrets in the namespace. For more information, see [this example about YAML reference](https://kubernetes.io/docs/concepts/containers/images/#creating-a-secret-with-a-docker-config). For information about getting an appropriate secrete, see the documentation of your image registry.

   The parameter to configure the SECRET_NAME is in the value.yaml file:
   ```yaml
   image:
     pullSecrets: SECRET_NAME
   ```
2. Install the chart by using the `--set image.pullSecrets` parameter:
   ```console
   $ helm install --name my-release odmcharts --set image.pullSecrets=admin.registryKey
   ```
