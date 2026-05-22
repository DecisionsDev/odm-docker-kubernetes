# Enable ODM distributed tracing with Microprofile telemetry

When applications are made observable, operations teams can more easily identify and understand the root causes of bugs, bottlenecks, and other inefficiencies. Liberty offers a robust framework for developing such observable applications and integrates seamlessly with numerous third-party monitoring tools. 

In the [Monitor ODM liberty metrics with mpMetrics and Prometheus](../mpmetrics/README.md) tutorial, we detailed how to enable Liberty metrics that depict the internal state of various Liberty components. In this document, we will discuss how to utilize MicroProfile Telemetry, which assists in collecting data on the paths that application requests take through services. More details on the usage of Microprofile Telemetry can be found in the [Liberty documentation](https://openliberty.io/docs/latest/microprofile-telemetry.html).

The goal of this tutorial is to demonstrate how to configure ODM on Kubernetes to enable communication with an OpenTelemetry collector that can process generated traces. This is not an in-depth OpenTelemetry tutorial. Therefore, it is advisable to familiarize yourself with the [Open Telemetry liberty configuration](https://openliberty.io/docs/latest/microprofile-telemetry.html#ol-config) before proceeding with this tutorial.
We will explain how to configure the OpenTelemetry collector to receive traces from the ODM instance. However, we will not manage the traces visulaization using the OpenTelemetry UI like Tempo or Graphana.

![Architecture](./images/otel_architecture.png) 


## Install the Red Hat build of OpenTelemetry Operator

The Red Hat build of OpenTelemetry Operator isn't just an installer; it's a management engine. The easiest way to get started is via the OpenShift web console. Follow these steps to install the operator:

* Log in to your OpenShift web console with administrator privileges.
* Navigate to Operators > OperatorHub.
* Search for the Red Hat build of OpenTelemetry.
* Select Install.
* On the installation page:
    * Update channel: Select stable.
    * Installation mode: Choose All namespaces on the cluster.
    * Approval strategy: Automatic
* Select Install and wait for the status to show "Succeeded."


### Create a collector instance

Once the operator is active, you must define an OpenTelemetryCollector Custom Resource (CR). This acts as the central hub for your telemetry data.

For a standard starting point, we recommend the deployment mode. This creates a centralized service to receive, process, and export data. Use the following configuration to set up a receiver that logs data for debug:

* Create a new project: oc new-project otel-demo.
* Go to Operators > Installed Operators > Red Hat build of OpenTelemetry.
* Select the OpenTelemetry collector tab and select Create OpenTelemetryCollector.
* Switch to the YAML view and use this basic deployment mode configuration:

This configuration ensures your collector is ready to ingest data via the OpenTelemetry protocol (OTLP). Use oc logs to see your traces appearing in real time during the testing phase.

### Verify the collector

Verify that the OpenTelemetry Collector is up and running by executing:

 ```bash
kubectl logs deployment/otel-collector
 ```

You should get the message :

 ```console
"Everything is ready. Begin running and processing data."
 ```



## Install ODM with the Open Telemetry agent

In this tutorial, we will inject the OpenTelemetry java agent inside the Decision Server Runtime and configure it to communicate with the OTEL Collector using JVM options. Then, we will manage some execution to generate traces and inspect them with Grafana.


### Prepare your environment for the ODM installation (5 min)

To access the ODM material, you need an IBM entitlement key to pull images from the IBM Cloud Container registry. 
This key will be utilized in the subsequent step of this tutorial.

#### a. Retrieve your entitled registry key

- Log in to [MyIBM Container Software Library](https://myibm.ibm.com/products-services/containerlibrary) with the IBMid and password that are associated with the entitled software.

- In the **Container Software and Entitlement Keys** tile, verify your entitlement on the **View library page**, and then go to *Entitlement keys* to retrieve the key.

#### b. Create a pull secret by running the kubectl create secret command

```bash
kubectl create secret docker-registry ibm-entitlement-key --docker-server=cp.icr.io \
    --docker-username=cp --docker-password="<ENTITLEMENT_KEY>"
```

Where:
* `<ENTITLEMENT_KEY>` is the entitlement key from the previous step. Make sure you enclose the key in double-quotes.

> Note: 
> 1. The **cp.icr.io** value for the docker-server parameter is the only registry domain name that contains the images. You must set the *docker-username* to **cp** to use an entitlement key as *docker-password*.
> 2. The `ibm-entitlement-key` secret name will be used for the `image.pullSecrets` parameter when you run a Helm install of your containers. The `image.repository` parameter is also set by default to `cp.icr.io/cp/cp4a/odm`.

#### c. Add the public IBM Helm charts repository

```bash
helm repo add ibm-helm https://raw.githubusercontent.com/IBM/charts/master/repo/ibm-helm
helm repo update
```

#### d. Check your access to the ODM chart

```bash
$ helm search repo ibm-odm-prod
NAME                             	CHART VERSION	APP VERSION	DESCRIPTION
ibm-helm/ibm-odm-prod           	26.0.0       	9.6.0.0   	IBM Operational Decision Manager
```

### Install an IBM Operational Decision Manager release (10 min)

Install a Kubernetes release with the default configuration named `otel-odm-release`, injecting the OTEL Java agent with the relevant JVM configuration.

We'll use the **decisionServerRuntime.downloadUrl** parameter to download the [OTEL Java agent](https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases), which will be injected into the container at the `/config/download/opentelemetry-javaagent.jar` path.

To configure the OTEL Java agent, we need to set up some JVM options, such as:

```bash
    -javaagent:/config/download/opentelemetry-javaagent.jar
    -Dotel.sdk.disabled=false
    -Dotel.exporter.otlp.protocol=grpc
    -Dotel.exporter.otlp.endpoint=http://otel-collector.otel-demo.svc.cluster.local:4317
    -Dotel.service.name=odm
    -Dotel.traces.exporter=otlp
    -Dotel.logs.exporter=none
    -Dotel.metrics.exporter=none
```

> [!NOTE]
> If you are installing in a different project than the **otel** project, don't forget to adapt the otlp endpoint. Also ensure the Tempo endpoint matches your Tempo installation namespace (default: **tempo-system**).

To do this, create the **otel-runtime-jvm-options-configmap** configmap that will be associated to the **decisionServerRuntime.jvmOptionsRef** parameter :

```bash
kubectl create -f otel-runtime-jvm-options-configmap.yaml
```

We will also add a parameter to add some liberty configurations that could be increase some traces using the **decisionServerRuntime.monitorRef** parameter.
You can find more details about how to configure the [monitor.xml file](https://www.ibm.com/docs/en/was-liberty/core?topic=environment-monitoring-monitor-10). 
Create the following secret using the monitor.xml file :

```bash
kubectl create secret generic runtime-monitor-configuration --from-file=monitor.xml
```


Then, install the ODM release :

```bash
helm install otel-odm-release ibm-helm/ibm-odm-prod -f otel-values.yaml
```

> [!NOTE]
> This command installs the **latest available version** of the chart.  
> If you want to install a **specific version**, add the `--version` option:
>
> ```bash
> helm install otel-odm-release ibm-helm/ibm-odm-prod --version <version> -f otel-values.yaml 
> ```
>
> You can list all available versions using:
>
> ```bash
> helm search repo ibm-helm/ibm-odm-prod -l
> ```

Having a look at the Decision Server Runtime pod logs, you should see : 

```console
[otel.javaagent 2024-04-03 18:03:27:166 +0200] [main] INFO io.opentelemetry.javaagent.tooling.VersionLogger - opentelemetry-javaagent - version: 2.16.0
```

Using **-Dotel.traces.exporter=otlp** JVM options, no OTEL traces are exported in the log files. So, that's normal to see nothing here. If you need to display them, you can replace it by **-Dotel.traces.exporter=logging**

## Generate some traces and observe them using Grafana

### Execute some runtime call

After instantiating ODM by populating it with the sample data, we are ready to directly execute some Decision Server Runtime calls.

Refer to [this documentation](https://www.ibm.com/docs/en/odm/9.5.0?topic=tasks-configuring-external-access) to retrieve the endpoints. 

For example, on OpenShift, you can obtain the route names and hosts with the following commands:

 ```bash
 kubectl get routes --no-headers --output custom-columns=":metadata.name,:spec.host"
 ```

 You get the following hosts:
 ```console
 my-odm-release-odm-dc-route           <DC_HOST>
 my-odm-release-odm-dr-route           <DR_HOST>
 my-odm-release-odm-ds-console-route   <DS_CONSOLE_HOST>
 my-odm-release-odm-ds-runtime-route   <DS_RUNTIME_HOST>
 ```

You perform a basic authentication ODM runtime call in the following way:

 ```bash
 curl -H "Content-Type: application/json" -k --data @payload.json \
      -H "Authorization: Basic b2RtQWRtaW46b2RtQWRtaW4=" \
      https://<DS_RUNTIME_HOST>/DecisionService/rest/production_deployment/1.0/loan_validation_production/1.0
 ```

  Where `b2RtQWRtaW46b2RtQWRtaW4=` is the base64 encoding of the current username:password odmAdmin:odmAdmin

### Observe the collected traces in Grafana

If you followed the Tempo and Grafana installation, Grafana should be accessible via a route or service in the **tempo-system** namespace.

On OpenShift, you can expose Grafana with a route:

 ```bash
 oc expose svc/grafana -n tempo-system
 oc get route grafana -n tempo-system
 ```

On other Kubernetes platforms, you can use port-forwarding:

 ```bash
 kubectl port-forward svc/grafana 3000:80 -n tempo-system
 ```

To observe Decision Server Runtime executions in Grafana:
1. Navigate to Grafana (default credentials: admin/admin)
2. Go to **Explore** in the left menu
3. Select **Tempo** as the data source
4. In the query builder, select **Search** tab
5. Filter by **Service Name**: `odm`
6. Click **Run query** to see the traces

![Runtime Traces](./images/runtime_traces.png)

By clicking on a **odm:POST /DecisionService/rest/** result, you can access detailed information about the execution:

![Traces Details](./images/traces_details.png)

