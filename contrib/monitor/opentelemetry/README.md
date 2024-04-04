# Enable ODM distributed tracing with Microprofile telemetry

When applications are observable, operations teams can identify and understand the root causes of bugs, bottlenecks, and other inefficiencies. Liberty provides a robust framework for developing observable applications and integrates with numerous third-party monitoring tools. On the [Monitor ODM liberty metrics with mpMetrics and Prometheus](https://github.com/DecisionsDev/odm-docker-kubernetes/blob/opentelemetry/contrib/monitor/mpmetrics/README.md) tutorial, we explained how to activate liberty metrics that describe the internal state of many Liberty components. Here, we will describe how to use MicroProfile Telemetry that helps to collect data data on the paths that application requests take through services. You can get more details on liberty documentation about the [Microprofile Telemetry usage](https://openliberty.io/docs/latest/microprofile-telemetry.html)

The aim of this tutorial is to explain how to configure ODM on k8s to make it communicate with an opentelemetry collector that can consume generated traces. It's not an in-deep opentelemetry tutorial. It's preferable to read the [Open Telemetry liberty configuration](https://openliberty.io/docs/latest/microprofile-telemetry.html#ol-config) before to realize the tutorial.

## Install Jaeger to display traces

Jaeger will be used to display traces that will be emitted by the Open Telemetry java agent, collected by the OpenTelemetry (OTEL) collector.
You can get [here](https://access.redhat.com/documentation/en-us/openshift_container_platform/4.5/html/jaeger/index) more details about Jaeger on OCP.
 
![Architecture](./images/otel_architecture.png)

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

We will use the **decisionServerRuntime.downloadUrl** parameter to download the [OTEL java agent](https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v1.32.1/opentelemetry-javaagent.jar) that will be injected inside the container at the /config/download/opentelemetry-javaagent.jar path.

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

To do this, create the **otel-runtime-jvm-options-configmap** configmap that will be associated to the **decisionServerRuntime.jvmOptionsRef** parameter :

```
kubectl create -f otel-runtime-jvm-options-configmap.yaml
```

We will also add a parameter to add some liberty configurations that could be increase some traces using the **decisionServerRuntime.libertyHookRef** parameter. 
Create the following secret using the libertyHookEnd.xml file :

```
kubectl create secret generic runtime-liberty-configuration --from-file=libertyHookEnd.xml
```


Then, install the ODM release :

```
helm install otel-odm-release ibm-helm/ibm-odm-prod \
        --set image.repository=cp.icr.io/cp/cp4a/odm --set image.pullSecrets=icregistry-secret \
        --set license=true --set usersPassword=odmAdmin \
        --set internalDatabase.persistence.enabled=false --set internalDatabase.populateSampleData=true \
        --set internalDatabase.runAsUser='' --set customization.runAsUser='' --set service.enableRoute=true \
        --set decisionServerRuntime.downloadUrl='{https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v1.32.1/opentelemetry-javaagent.jar}' \
        --set decisionServerRuntime.jvmOptionsRef=otel-runtime-jvm-options-configmap \
        --set decisionServerRuntime.libertyHookRef=runtime-liberty-configuration
```

Having a look at the Decision Server Runtime pod logs, you should see : 

```
[otel.javaagent 2024-04-03 18:03:27:166 +0200] [main] INFO io.opentelemetry.javaagent.tooling.VersionLogger - opentelemetry-javaagent - version: 1.32.1
```

Using **-Dotel.traces.exporter=otlp** JVM options, no OTEL traces are exported in the log files. So, that's normal to see nothing here. If you need to display them, you can replace it by **-Dotel.traces.exporter=logging**

## Generate some traces and observe them using the Jaegger UI

### Execute some runtime call

As we instanciated ODM by populating the sample data, we can directly execute some Decision Server Runtime calls.

Refer to [this documentation](https://www.ibm.com/docs/en/odm/8.12.0?topic=tasks-configuring-external-access) to retrieve the endpoints.
For example, on OpenShift you can get the route names and hosts with:

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

You perform a basic authentication ODM runtime call in the following way:

 ```
  $ curl -H "Content-Type: application/json" -k --data @payload.json \
         -H "Authorization: Basic b2RtQWRtaW46b2RtQWRtaW4=" \
        https://<DS_RUNTIME_HOST>/DecisionService/rest/production_deployment/1.0/loan_validation_production/1.0
  ```

  Where `b2RtQWRtaW46b2RtQWRtaW4=` is the base64 encoding of the current username:password odmAdmin:odmAdmin

### Observe the collected traces on the Jaegger UI

If you followed the standard Jaegger installation using OpenShift Operator, the Jaegger all-in-one instance must be exposed with a route named <jaeger-all-in-one.XXX>

When you access the Jaegger UI following this route, you can click on the "Search" menu and retreive observation about the previous Decision Server Runtime Execution.
You have to select or put **odm** as the Service name and select **POST /DecisionService/rest/\* ** as Operation. Then click on the **Find Traces** button
 
![Runtime Traces](./images/runtime_traces.png)

Clicking on a **odm:POST /DecisionService/rest/\* ** result, you can get more details about the execution :

![Traces Details](./images/traces_details.png)

Now, if you want to get more span details, you can add more liberty features.
Edit the runtime-liberty-configuration secret and uncomment the lines that add liberty opentelemetry features :

 ```
<server>
    <featureManager>
        <feature>servlet-4.0</feature>
        <feature>appSecurity-3.0</feature>
        <feature>jsp-2.3</feature>
        <feature>jdbc-4.1</feature>
        <feature>ldapRegistry-3.0</feature>
        <feature>openidConnectClient-1.0</feature>
        <feature>transportSecurity-1.0</feature>
        <feature>monitor-1.0</feature>
        <feature>mpOpenAPI-2.0</feature>
        <feature>mpOpenTracing-2.0</feature>
        <feature>microProfile-4.0</feature>
    </featureManager>
</server>
 ```

The Decision Server Runtime logs must show :

 ```
[4/3/24, 18:36:23:612 CEST] 0000003b FeatureManage A CWWKF1037I: The server added the [jaxrs-2.1, jaxrsClient-2.1, jsonb-1.0, jsonp-1.1, jwt-1.0, microProfile-4.0, mpConfig-2.0, mpFaultTolerance-3.0, mpHealth-3.0, mpJwt-1.2, mpMetrics-3.0, mpOpenAPI-2.0, mpOpenTracing-2.0, mpRestClient-2.0, opentracing-2.0] features to the existing feature set.
[4/3/24, 18:36:23:613 CEST] 0000003b FeatureManage A CWWKF0012I: The server installed the following features: [appSecurity-2.0, appSecurity-3.0, cdi-2.0, distributedMap-1.0, el-3.0, federatedRegistry-1.0, jaxrs-2.1, jaxrsClient-2.1, jdbc-4.1, jndi-1.0, json-1.0, jsonb-1.0, jsonp-1.1, jsp-2.3, jwt-1.0, ldapRegistry-3.0, microProfile-4.0, monitor-1.0, mpConfig-2.0, mpFaultTolerance-3.0, mpHealth-3.0, mpJwt-1.2, mpMetrics-3.0, mpOpenAPI-2.0, mpOpenTracing-2.0, mpRestClient-2.0, oauth-2.0, openidConnectClient-1.0, opentracing-2.0, servlet-4.0, ssl-1.0, transportSecurity-1.0].
[4/3/24, 18:36:23:614 CEST] 0000003b FeatureManage A CWWKF0008I: Feature update completed in 2.964 seconds.
 ```

Now, when running new Runtime Execution, you should see more managed span in Jaegger UI :

![Traces Details](./images/more_spans.png)

If you want to add more span in the java code to observe code behaviour, have a look at the [liberty tutorial](https://openliberty.io/guides/microprofile-telemetry-jaeger.html)

 
