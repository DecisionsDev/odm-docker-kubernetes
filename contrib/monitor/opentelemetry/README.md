# Enable ODM distributed tracing with Microprofile telemetry

When applications are observable, operations teams can identify and understand the root causes of bugs, bottlenecks, and other inefficiencies. Liberty provides a robust framework for developing observable applications and integrates with numerous third-party monitoring tools. On the [Monitor ODM liberty metrics with mpMetrics and Prometheus](https://github.com/DecisionsDev/odm-docker-kubernetes/blob/opentelemetry/contrib/monitor/mpmetrics/README.md) tutorial, we explained how to activate liberty metrics that describe the internal state of many Liberty components. Here, we will describe how to use MicroProfile Telemetry that helps to collect data data on the paths that application requests take through services. You can get more details on liberty documentation about the [Microprofile Telemetry usage](https://openliberty.io/docs/latest/microprofile-telemetry.html)

The aim of this tutorial is to explain how to configure ODM on k8s to make it communicate with an opentelemetry collector that can consume generated traces. It's not an in-deep opentelemetry tutorial.

## Install Jaeger to display traces

Jaeger will be used to display traces that will be emitted by the Open Telemetry java agent, collected by the OpenTelemetry (OTEL) collector.
You can get [here](https://access.redhat.com/documentation/en-us/openshift_container_platform/4.5/html/jaeger/index) more details about Jaeger on OCP.
 
![Architecture](./images/architecture.png)

We will install Jaeger using the [OpenShift Jaeger Operator](https://access.redhat.com/documentation/en-us/openshift_container_platform/4.5/html/jaeger/jaeger-installation#jaeger-operator-install_jaeger-install).

## Deploy the OpenTelemetry Collector

We used the following [descriptor](https://github.com/open-telemetry/opentelemetry-go/blob/main/example/otel-collector/k8s/otel-collector.yaml) as a basis for the OTEL Collector deployment
However, you will certainly encounter an error like :

 ```
2023-07-06T17:28:37.520Z        debug   jaegerexporter@v0.80.0/exporter.go:106  failed to push trace data to Jaeger     {"kind": "exporter", "data_type": "traces", "name": "jaeger", "error": "rpc error: code = Unimplemented desc = unknown service jaeger.api_v2.CollectorService"}
 ```

The following [article](https://cloudbyt.es/blog/switching-to-jaeger-otel-collector) is providing the solution.

You can also use the [otel-collector.yaml](./otel-collector.yaml) file that we used for the tutorial.

 ```
kubectl apply -f otel-collector.yaml
 ```

Verify that the the OpenTelemetry Collector is up and running, by executing :

 ```
kubectl logs deployment/otel-collector
 ```

You should get the message :

"Everything is ready. Begin running and processing data."

## Install ODM with the Open Telemetry agent

In this tutorial, we will inject the OpenTelemetry java agent inside the Decision Server Runtime and configure it to communicate with the OTEL Collector using JVM options. Then, we will manage some execution to generate traces and inspect them with the Jaeger UI.

### Prepare your environment for the ODM installation (5 min)

To get access to the ODM material, you must have an IBM entitlement key to pull the images from the IBM Cloud Container registry.
This is what will be used in the next step of this tutorial.

#### a. Retrieve your entitled registry key

- Log in to [MyIBM Container Software Library](https://myibm.ibm.com/products-services/containerlibrary) with the IBMid and password that are associated with the entitled software.

- In the **Container Software and Entitlement Keys** tile, verify your entitlement on the **View library page**, and then go to *Entitlement keys* to retrieve the key.

#### b. Create a pull secret by running the kubectl create secret command

```bash
kubectl create secret docker-registry my-odm-docker-registry --docker-server=cp.icr.io \
    --docker-username=cp --docker-password="<ENTITLEMENT_KEY>" --docker-email=<USER_EMAIL>
```

Where:
* `<ENTITLEMENT_KEY>` is the entitlement key from the previous step. Make sure you enclose the key in double-quotes.
* `<USER_EMAIL>` is the email address associated with your IBMid.

> **Note**
> The `cp.icr.io` value for the docker-server parameter is the only registry domain name that contains the images. You must set the docker-username to `cp` to use an entitlement key as docker-password.

The my-odm-docker-registry secret name is already used for the `image.pullSecrets` parameter when you run a helm install of your containers. The `image.repository` parameter is also set by default to `cp.icr.io/cp/cp4a/odm`.

#### c. Add the public IBM Helm charts repository

```bash
helm repo add ibm-helm https://raw.githubusercontent.com/IBM/charts/master/repo/ibm-helm
helm repo update
```

#### d. Check your access to the ODM chart

```bash
$ helm search repo ibm-odm-prod
NAME                             	CHART VERSION	APP VERSION	DESCRIPTION
ibm-helm/ibm-odm-prod           	23.2.0       	8.12.0.1   	IBM Operational Decision Manager
```

### Install an IBM Operational Decision Manager release (10 min)

Install a Kubernetes release with the default configuration and a name of otel-odm-release, but injecting the OTEL java agent with the relevant JVM configuration.

We will use the **downloadUrl** parameter to download the [OTEL java agent](https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v1.32.1/opentelemetry-javaagent.jar) that will be injected inside the container at the /config/download/opentelemetry-javaagent.jar path.

To configure the OTEL java agent, we need to setup some JVM Options like :

```
    -javaagent:/config/download/opentelemetry-javaagent.jar
    -Dotel.sdk.disabled=false
    -Dotel.exporter.otlp.endpoint=http://otel-collector.otel.svc.cluster.local:4317
    -Dotel.service.name=odm
    -Dotel.traces.exporter=otlp
    -Dotel.logs.exporter=none
    -Dotel.metrics.exporter=none
```

To do this, create the **otel-runtime-jvm-options-configmap** configmap :

```
kubectl create -f otel-runtime-jvm-options-configmap.yaml
```

Then, install the ODM release :

```
helm install otel-odm-release ibm-helm/ibm-odm-prod \
        --set image.repository=cp.icr.io/cp/cp4a/odm --set image.pullSecrets=icregistry-secret \
        --set license=true --set usersPassword=odmAdmin \
        --set internalDatabase.persistence.enabled=false --set internalDatabase.populateSampleData=true \
        --set internalDatabase.runAsUser='' --set customization.runAsUser='' --set service.enableRoute=true \
        --set decisionServerRuntime.downloadUrl='{https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v1.32.1/opentelemetry-javaagent.jar}' \
        --set decisionServerRuntime.jvmOptionsRef=otel-runtime-jvm-options-configmap
```




 
