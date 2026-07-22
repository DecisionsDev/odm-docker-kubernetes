# REST Connector for ODM on Kubernetes

## Table of Contents

- [Introduction](#introduction)
  - [What the `restConnector` feature does](#what-the-restconnector-feature-does)
  - [Why it matters for ODM monitoring](#why-it-matters-for-odm-monitoring)
- [Prerequisites](#prerequisites)
- [How to expose ODM restConnector in OCP](#how-to-expose-odm-restconnector-in-ocp)
  - [Create a secret to use the Entitled Registry](#create-a-secret-to-use-the-entitled-registry)
  - [Create a secret to configure rest-connector](#create-a-secret-to-configure-rest-connector)
- [Install your ODM Helm release](#install-your-odm-helm-release)
  - [1. Add the public IBM Helm charts repository](#1-add-the-public-ibm-helm-charts-repository)
  - [2. Check that you can access the ODM chart](#2-check-that-you-can-access-the-odm-chart)
  - [3. Run the `helm install` command](#3-run-the-helm-install-command)
  - [4. Check the /IBMJMXConnectorREST endpoints](#4-check-the-ibmjmxconnectorrest-endpoints)
    - [List all available MBeans](#list-all-available-mbeans)
    - [Read all attributes of a single MBean](#read-all-attributes-of-a-single-mbean)
  - [5. Use-Cases](#5-use-cases)
    - [Generate a JVM dump file](#generate-a-jvm-dump-file)
      - [Thread dump (javacore)](#thread-dump-javacore)
      - [Heap dump](#heap-dump)
      - [Retrieve the dump file](#retrieve-the-dump-file)
    - [Read a JVM metric — FreeMemory from JvmStats](#read-a-jvm-metric--freememory-from-jvmstats)
      - [Read all JvmStats attributes](#read-all-jvmstats-attributes)
      - [Read only the FreeMemory attribute](#read-only-the-freememory-attribute)
      - [Convert to megabytes with jq](#convert-to-megabytes-with-jq)

## Introduction

The [Open Liberty – restConnector-2.0](https://openliberty.io/docs/latest/reference/feature/restConnector-2.0.html) feature is an Open Liberty feature that exposes a **JMX-over-REST** endpoint on your Liberty server. It enables remote monitoring and management of Liberty runtime components — including IBM Operational Decision Manager (ODM) — through standard HTTP/HTTPS calls, without requiring a native JMX connection or an open RMI port.

## Prerequisites

- [Helm 3.1](https://helm.sh/docs/intro/install/)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl)
- Access to an Operational Decision Manager product
- Access to an Openshift cluster

### What the `restConnector` feature does

When enabled in your Liberty `server.xml`, the feature:

- Starts a secure REST endpoint at `https://<host>:<httpsPort>/IBMJMXConnectorREST/`
- Exposes all registered MBeans (e.g. JVM memory, thread pools, datasources, ODM rule session metrics) via that endpoint
- Accepts standard HTTP Basic authentication (Liberty user registry) or client certificates
- Works across network boundaries where raw JMX/RMI ports would be blocked by firewalls

### Why it matters for ODM monitoring

ODM on Kubernetes publishes MBeans for key runtime metrics such as rule execution counts, execution time, and Decision Server status. By exposing those MBeans through the REST Connector you can:

- Scrape ODM metrics from **outside** the container without cluster-level JMX port exposure
- Integrate with monitoring agents (Prometheus JMX exporter, Instana, Dynatrace) that speak HTTP
- Query or invoke MBean operations from scripts and CI pipelines using plain `curl` or any HTTP client

## How to expose ODM restConnector in OCP

### Create a secret to use the Entitled Registry

1. To get your entitlement key, log in to [MyIBM Container Software Library](https://myibm.ibm.com/products-services/containerlibrary) with the IBMid and password that are associated with the entitled software.

    In the **Container software library** tile, verify your entitlement on the **View library** page, and then go to **Get entitlement key**  to retrieve the key.

2. Create a pull secret by running a `kubectl create secret` command.

    ```
    kubectl create secret docker-registry ibm-entitlement-key \
        --docker-server=cp.icr.io \
        --docker-username=cp \
        --docker-password="<API_KEY_GENERATED>"
    ```

    Where:

    - *API_KEY_GENERATED* is the entitlement key from the previous step. Make sure you enclose the key in double-quotes.

    > Note: 
    > 1. The **cp.icr.io** value for the docker-server parameter is the only registry domain name that contains the images. You must set the *docker-username* to **cp** to use an entitlement key as *docker-password*.
    > 2. The `ibm-entitlement-key` secret name will be used for the `image.pullSecrets` parameter when you run a Helm install of your containers. The `image.repository` parameter is also set by default to `cp.icr.io/cp/cp4a/odm`.


### Create a secret to configure rest-connector

Get the [monitor.xml](./monitor.xml) file that is containing a minimal liberty configuration to allow access to restConnector capabilities. You can add your own configuration using [liberty documentation](https://openliberty.io/docs/26.0.0.6/reference/feature/restConnector-2.0.html#_examples)
A role-protected user must also be mapped to the `administrator-role` for the endpoint to accept connections.
We will use the odmAdmin default administrator user for this role.
Create a monitor.xml file with :

```xml
<administrator-role>
    <user>odmAdmin</user>
</administrator-role>
```

Create a secret with the monitor.xml file :

```xml
kubectl create secret generic rest-connector-secret --from-file=monitor.xml
```

## Install your ODM Helm release

### 1. Add the public IBM Helm charts repository

  ```shell
  helm repo add ibm-helm https://raw.githubusercontent.com/IBM/charts/master/repo/ibm-helm
  helm repo update
  ```

### 2. Check that you can access the ODM chart

  ```shell
  helm search repo ibm-odm-prod
  NAME                  	CHART VERSION	APP VERSION	DESCRIPTION
  ibm-helm/ibm-odm-prod	  26.0.0       	9.6.0.0   	IBM Operational Decision Manager
  ```

### 3. Run the `helm install` command

You can now install the product. We will use the PostgreSQL internal database and disable data persistence (`internalDatabase.persistence.enabled=false`) to avoid any platform complexity with persistent volume allocation.

See the [Preparing to install](https://www.ibm.com/docs/en/odm/9.6.0?topic=production-preparing-install-operational-decision-manager) documentation for more information.

Set <password> in [rest-connector-values.yaml](rest-connector-values.yaml) and run:

```shell
helm install my-odm-release ibm-helm/ibm-odm-prod -f rest-connector-values.yaml
```

> [!NOTE]
> **customization.monitorRef** is installing /IBMJMXConnectorREST endpoint on all components. 
> If you would like to install /IBMJMXConnectorREST on a specific component, you can replace usage of **customization.monitorRef** by **decisionCenter.monitorRef** , **decisionServerConsole.monitorRef** , **decisionRunner.monitorRef** or **decisionServerRuntime.monitorRef**
> This command installs the **latest available version** of the chart.  
> If you want to install a **specific version**, add the `--version` option:
>
> ```bash
> helm install my-odm-release ibm-helm/ibm-odm-prod --version <version> -f monitor-values.yaml
> ```
>
> You can list all available versions using:
>
> ```bash
> helm search repo ibm-helm/ibm-odm-prod -l
> ```

### 4. Check the /IBMJMXConnectorREST endpoints

As the installation has been done using **customization.monitorRef**, all ODM components are exposing /IBMJMXConnectorREST endpoints by the routes.
On OpenShift you can get the route names and hosts with:

```
kubectl get routes --no-headers --output custom-columns=":metadata.name,:spec.host"
```

You get the following hosts:

```
my-odm-release-odm-dc-route           <DC_HOST>
my-odm-release-odm-dr-route           <DR_HOST>
my-odm-release-odm-ds-console-route   <DS_CONSOLE_HOST>
my-odm-release-odm-ds-runtime-route   <DS_RUNTIME_HOST>
```

Check all metrics endpoints using the following URL in a browser or with command line:

```
curl -k -u odmAdmin:<password> https://<DC_HOST>/IBMJMXConnectorREST
curl -k -u odmAdmin:<password> https://<DR_HOST>/IBMJMXConnectorREST
curl -k -u odmAdmin:<password> https://<DS_CONSOLE_HOST>/IBMJMXConnectorREST
curl -k -u odmAdmin:<password> https://<DS_RUNTIME_HOST>/IBMJMXConnectorREST
```

The JSON response as an example:

```json
{
"version":"6",
"mbeans":"/IBMJMXConnectorREST/mbeans",
"createMBean":"/IBMJMXConnectorREST/mbeans/factory",
"mbeanCount":"/IBMJMXConnectorREST/mbeanCount",
"defaultDomain":"/IBMJMXConnectorREST/defaultDomain",
"domains":"/IBMJMXConnectorREST/domains",
"notifications":"/IBMJMXConnectorREST/notifications",
"instanceOf":"/IBMJMXConnectorREST/instanceOf",
"fileTransfer":"/IBMJMXConnectorREST/file",
"api":"/IBMJMXConnectorREST/api",
"graph":"/IBMJMXConnectorREST/graph"
}
```

#### List all available MBeans

```bash
curl -k -u odmAdmin:<password> https://<ROUTE>/IBMJMXConnectorREST/mbeans | jq
```

The response is a JSON array of every registered MBean ObjectName, for example:

```json
[
  {
    "objectName": "com.ibm.lang.management:type=JvmCpuMonitor",
    "className": "com.ibm.lang.management.internal.JvmCpuMonitor",
    "URL": "/IBMJMXConnectorREST/mbeans/com.ibm.lang.management%3Atype%3DJvmCpuMonitor"
  },
  {
    "objectName": "WebSphere:type=JvmStats",
    "className": "com.ibm.ws.monitors.helper.JvmStats",
    "URL": "/IBMJMXConnectorREST/mbeans/WebSphere%3Atype%3DJvmStats"
  },
  {
    "objectName": "java.lang:type=Memory",
    "className": "com.ibm.lang.management.internal.ExtendedMemoryMXBeanImpl",
    "URL": "/IBMJMXConnectorREST/mbeans/java.lang%3Atype%3DMemory"
  },
  ...
  {
    "objectName": "WebSphere:service=com.ibm.websphere.application.ApplicationMBean,name=res",
    "className": "com.ibm.ws.app.manager.internal.ApplicationConfigurator$NamedApplication$2",
    "URL": "/IBMJMXConnectorREST/mbeans/WebSphere%3Aname%3Dres%2Cservice%3Dcom.ibm.websphere.application.ApplicationMBean"
  },
]
```

#### Read all attributes of a single MBean

URL-encode the full ObjectName and call its `/attributes` sub-resource:

```bash
MBEAN="WebSphere%3Atype%3DJvmStats"

curl -k -u odmAdmin:<password> \
  "https://<ROUTE>/IBMJMXConnectorREST/mbeans/${MBEAN}/attributes"
```

> **Tip:** Add `-v` to any `curl` call to see the full TLS handshake and HTTP exchange — useful for diagnosing authentication or certificate errors.

### 5. Use-Cases

#### Generate a JVM dump file

ODM on Liberty runs on the **OpenJ9 JVM**. All dump types (thread, heap, system) are triggered through the same `triggerDump` operation on the `openj9.lang.management:type=OpenJ9Diagnostics` MBean.

The only accepted parameter is the dump type name. OpenJ9 chooses the output path automatically — it **cannot** be set through this operation.

| Parameter | Dump type | Output file |
|---|---|---|
| `"java"` | Thread dump | `javacore.*.txt` — all JVM thread states |
| `"heap"` | Heap dump | `heapdump.*.phd` — all live objects in memory |
| `"system"` | System dump | `core.*.dmp` — full process memory image |

##### Thread dump (javacore)

Useful for diagnosing hangs and high-CPU issues.

```bash
export MBEAN="openj9.lang.management%3Atype%3DOpenJ9Diagnostics"
curl -k -u odmAdmin:<password> \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"params":[{"value":"java","type":"java.lang.String"}],"signature":["java.lang.String"]}' \
  "https://<ROUTE>/IBMJMXConnectorREST/mbeans/${MBEAN}/operations/triggerDump"
```

##### Heap dump

Useful for diagnosing memory leaks and `OutOfMemoryError` conditions.

```bash
export MBEAN="openj9.lang.management%3Atype%3DOpenJ9Diagnostics"
curl -k -u odmAdmin:<password> \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"params":[{"value":"heap","type":"java.lang.String"}],"signature":["java.lang.String"]}' \
  "https://<ROUTE>/IBMJMXConnectorREST/mbeans/${MBEAN}/operations/triggerDump"
```

Both operations return `{"value":null,"type":null}` — `triggerDump` is `void`. The dump **has been triggered**. Retrieve the file path from the pod log:

```bash
# Thread dump
kubectl logs <pod-name> | grep "JVMDUMP010I Java dump written"
# JVMDUMP010I Java dump written to /opt/ibm/wlp/output/defaultServer/javacore.20260722.121515.1.0002.txt

# Heap dump
kubectl logs <pod-name> | grep "JVMDUMP010I Heap dump written"
# JVMDUMP010I Heap dump written to /opt/ibm/wlp/output/defaultServer/heapdump.20260722.121515.1.0003.phd
```

##### Retrieve the dump file

Use the `fileTransfer` endpoint (`/IBMJMXConnectorREST/file`) to download the dump from the container to your local machine:

```bash
# 1. Get the path from the pod log (adjust grep for heap vs thread)
REMOTE_PATH=$(kubectl logs <pod-name> | grep "JVMDUMP010I Java dump written" | tail -1 | awk '{print $NF}')

# 2. URL-encode it
ENCODED_PATH=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$REMOTE_PATH")

# 3. Download
curl -k -u odmAdmin:<password> \
  -o dump.txt \
  "https://<ROUTE>/IBMJMXConnectorREST/file/${ENCODED_PATH}"
```

> **Note:** The dump file is written inside the container. If the pod is ephemeral (no persistent volume), retrieve the file immediately after the dump before the pod restarts.

#### Read a JVM metric — FreeMemory from JvmStats

The `WebSphere:type=JvmStats` MBean exposes live JVM memory metrics. Reading its `FreeMemory` attribute gives the current amount of free heap memory in bytes — useful for alerting and health checks without a full heap dump.

##### Read all JvmStats attributes

```bash
MBEAN="WebSphere%3Atype%3DJvmStats"

curl -k -u odmAdmin:<password> \
  "https://<ROUTE>/IBMJMXConnectorREST/mbeans/${MBEAN}/attributes" | jq
```

Example response :

```json
[
  {
    "name": "Heap",
    "value": {
      "value": "288292864",
      "type": "java.lang.Long"
    }
  },
  {
    "name": "FreeMemory",
    "value": {
      "value": "139614920",
      "type": "java.lang.Long"
    }
  },
  {
    "name": "ProcessCPU",
    "value": {
      "value": "0.9142000000000001",
      "type": "java.lang.Double"
    }
  },
  {
    "name": "UsedMemory",
    "value": {
      "value": "148677944",
      "type": "java.lang.Long"
    }
  },
  {
    "name": "GcTime",
    "value": {
      "value": "2406",
      "type": "java.lang.Long"
    }
  },
  {
    "name": "UpTime",
    "value": {
      "value": "17674142",
      "type": "java.lang.Long"
    }
  },
  {
    "name": "GcCount",
    "value": {
      "value": "135",
      "type": "java.lang.Long"
    }
  }
]
```

##### Read only the FreeMemory attribute

```bash
MBEAN="WebSphere%3Atype%3DJvmStats"

curl -k -u odmAdmin:<password> \
  "https://<ROUTE>/IBMJMXConnectorREST/mbeans/${MBEAN}/attributes/FreeMemory" | jq
```

Response:

```json
{
  "value": "88742240",
  "type": "java.lang.Long"
}
```

##### Convert to megabytes with jq

```bash
curl -k -u odmAdmin:<password> \
  "https://<ROUTE>/IBMJMXConnectorREST/mbeans/${MBEAN}/attributes/FreeMemory" \
  | jq '.value | tonumber / 1024 / 1024 | floor | tostring + " MB"'
# "488 MB"
```