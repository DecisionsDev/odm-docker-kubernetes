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
* Switch to the YAML view and create a default otel collector using [otel-collector.yaml](otel-collector.yaml)

This configuration ensures your collector is ready to ingest data via the OpenTelemetry protocol (OTLP). Use oc logs to see your traces appearing in real time during the testing phase.

### Verify the collector

Verify that the OpenTelemetry Collector is up and running by executing:

```bash
kubectl logs deployment/otel-collector -n otel-demo
 ```

You should get the message :

```console
"Everything is ready. Begin running and processing data."
 ```



## Install ODM with the Open Telemetry agent

In this tutorial, we will inject the OpenTelemetry java agent inside the Decision Server Runtime and configure it to communicate with the OTEL Collector using JVM options. Then, we will manage some execution to generate traces and inspect them in the otel collector pod logs.


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
    -Dotel.exporter.otlp.endpoint=http://otel-collector.otel-demo.svc.cluster.local:4318
    -Dotel.service.name=odm
    -Dotel.javaagent.debug=true
    -Dotel.traces.exporter=otlp
    -Dotel.logs.exporter=none
    -Dotel.metrics.exporter=none
```

> [!NOTE]
> We set the agent in debug mode using **-Dotel.javaagent.debug=true** in order to get the full stack trace in the logs. As it is very verbose, don't forget to remove this setting in production to avoid performance issues.

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
[otel.javaagent 2026-05-22 10:37:54:277 +0200] [main] INFO io.opentelemetry.javaagent.tooling.VersionLogger - opentelemetry-javaagent - version: 2.28.0
```

Using **-Dotel.traces.exporter=otlp** JVM options, no OTEL traces are exported in the log files. So, that's normal to see nothing here. If you need to display them, you can replace it by **-Dotel.traces.exporter=logging**

## Generate some traces and observe them using Grafana

### Execute some runtime call

After instantiating ODM by populating it with the sample data, we are ready to directly execute some Decision Server Runtime calls.

Refer to [this documentation](https://www.ibm.com/docs/en/odm/9.6.0?topic=tasks-configuring-external-access) to retrieve the endpoints. 

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

### Observe the collected traces in the otel collector pod

After you executed the Decision Server Runtime call, you should see in the otel collector pod log:

```bash
kubectl logs deployment/otel-collector -n otel-demo
 ```

a trace like :

	```bash
	ScopeSpans #1
	ScopeSpans SchemaURL: https://opentelemetry.io/schemas/1.37.0
	InstrumentationScope io.opentelemetry.servlet-5.0 2.28.0-alpha
	Span #0
	    Trace ID       : 914029e493a16d5d71352479e27f64ec
	    Parent ID      : 
	    ID             : a9c5fcd129ff3524
	    Name           : POST /DecisionService/rest/*
	    Kind           : Server
	    Start time     : 2026-05-27 07:32:37.282860188 +0000 UTC
	    End time       : 2026-05-27 07:32:38.207108573 +0000 UTC
	    Status code    : Unset
	    Status message : 
	    DroppedAttributesCount: 0
	    DroppedEventsCount: 0
	    DroppedLinksCount: 0
	Attributes:
	     -> url.path: Str(/DecisionService/rest/production_deployment/1.0/loan_validation_production/1.0)
	     -> network.peer.port: Int(46614)
	     -> client.address: Str(10.254.12.2)
	     -> user_agent.original: Str(curl/8.19.0)
	     -> network.peer.address: Str(10.254.12.2)
	     -> http.response.status_code: Int(200)
	     -> network.protocol.version: Str(2.0)
	     -> http.route: Str(/DecisionService/rest/*)
	     -> http.request.method: Str(POST)
	     -> thread.id: Int(89)
	     -> url.scheme: Str(https)
	     -> thread.name: Str(Default Executor-thread-7)
		{"resource": {"service.instance.id": "8c476977-537e-421f-aac6-c05ce65be9c6", "service.name": "otelcol", "service.version": "0.144.0"}, "otelcol.component.id": "debug", "otelcol.component.kind": "exporter", "otelcol.signal": "traces"}
	2026-05-27T07:32:51.111Z	info	Traces	{"resource": {"service.instance.id": "8c476977-537e-421f-aac6-c05ce65be9c6", "service.name": "otelcol", "service.version": "0.144.0"}, "otelcol.component.id": "debug", "otelcol.component.kind": "exporter", "otelcol.signal": "traces", "resource spans": 1, "spans": 1}
	2026-05-27T07:32:51.111Z	info	ResourceSpans #0
	Resource SchemaURL: https://opentelemetry.io/schemas/1.24.0
	Resource attributes:
	     -> container.id: Str(e78bf0e37af83672f000a919153bc597deac74676188bb860f016a6f467c888e)
	     -> host.arch: Str(amd64)
	     -> host.name: Str(test-odm-decisionserverruntime-cc8d4dfc5-ddvlm)
	     -> os.description: Str(Linux 5.14.0-570.107.1.el9_6.x86_64)
	     -> os.type: Str(linux)
	     -> os.version: Str(5.14.0-570.107.1.el9_6.x86_64)
	     -> process.command_args: Slice(["/opt/java/openjdk/bin/java","-javaagent:/opt/ibm/wlp/bin/tools/ws-javaagent.jar","-Djava.awt.headless=true","-Djdk.attach.allowAttachSelf=true","-Duser.timezone=Europe/Paris","-Dcom.ibm.jsse2.overrideDefaultTLS=true","-javaagent:/config/download/opentelemetry-javaagent.jar","-Dotel.sdk.disabled=false","-Dotel.exporter.otlp.endpoint=http://otel-collector.otel-demo.svc.cluster.local:4318","-Dotel.service.name=odm","-Dotel.javaagent.debug=true","-Dotel.traces.exporter=otlp","-Dotel.logs.exporter=otlp","-Dotel.metrics.exporter=otlp","--add-exports","java.base/sun.security.action=ALL-UNNAMED","--add-exports","java.naming/com.sun.jndi.ldap=ALL-UNNAMED","--add-exports","java.naming/com.sun.jndi.url.ldap=ALL-UNNAMED","--add-exports","jdk.naming.dns/com.sun.jndi.dns=ALL-UNNAMED","--add-exports","jdk.naming.dns/com.sun.jndi.url.dns=ALL-UNNAMED","--add-exports","java.security.jgss/sun.security.krb5.internal=ALL-UNNAMED","--add-exports","jdk.attach/sun.tools.attach=ALL-UNNAMED","--add-opens","java.base/java.util=ALL-UNNAMED","--add-opens","java.base/java.lang=ALL-UNNAMED","--add-opens","java.base/java.util.concurrent=ALL-UNNAMED","--add-opens","java.base/java.io=ALL-UNNAMED","--add-opens","java.base/java.nio=ALL-UNNAMED","--add-opens","java.base/sun.nio.ch=ALL-UNNAMED","--add-opens","java.naming/javax.naming.spi=ALL-UNNAMED","--add-opens","java.naming/com.sun.naming.internal=ALL-UNNAMED","--add-opens","jdk.naming.rmi/com.sun.jndi.url.rmi=ALL-UNNAMED","--add-opens","java.naming/javax.naming=ALL-UNNAMED","--add-opens","java.rmi/java.rmi=ALL-UNNAMED","--add-opens","java.sql/java.sql=ALL-UNNAMED","--add-opens","java.management/javax.management=ALL-UNNAMED","--add-opens","java.base/java.lang.reflect=ALL-UNNAMED","--add-opens","java.desktop/java.awt.image=ALL-UNNAMED","--add-opens","java.base/java.security=ALL-UNNAMED","--add-opens","java.base/java.net=ALL-UNNAMED","--add-opens","java.base/java.text=ALL-UNNAMED","--add-opens","java.base/sun.net.www.protocol.https=ALL-UNNAMED","--add-exports","jdk.management.agent/jdk.internal.agent=ALL-UNNAMED","--add-exports","java.base/jdk.internal.vm=ALL-UNNAMED","-jar","/opt/ibm/wlp/bin/tools/ws-server.jar","defaultServer"])
	     -> process.executable.path: Str(/opt/java/openjdk/bin/java)
	     -> process.pid: Int(1)
	     -> process.runtime.description: Str(Eclipse OpenJ9 Eclipse OpenJ9 VM 21.0.11+10-openj9-0.59.0)
	     -> process.runtime.name: Str(IBM Semeru Runtime Open Edition)
	     -> process.runtime.version: Str(21.0.11+10-LTS)
	     -> service.instance.id: Str(35ca7d5f-4c2c-43fd-b51d-66706039e99e)
	     -> service.name: Str(odm)
	     -> telemetry.distro.name: Str(opentelemetry-java-instrumentation)
	     -> telemetry.distro.version: Str(2.28.0)
	     -> telemetry.sdk.language: Str(java)
	     -> telemetry.sdk.name: Str(opentelemetry)
	     -> telemetry.sdk.version: Str(1.62.0)
	 ```bash


Then you can make a search to retrieve all spans that have a **parent Id** equals to **a9c5fcd129ff3524**.
You will retrieve all the JDBC queries to retrieve the ruleapp and the ruleset like :


	```bash
	ScopeSpans #0
	ScopeSpans SchemaURL: 
	InstrumentationScope io.opentelemetry.jdbc 2.28.0-alpha
	Span #0
	    Trace ID       : 914029e493a16d5d71352479e27f64ec
	    Parent ID      : a9c5fcd129ff3524
	    ID             : bf4de5f54fad8783
	    Name           : odmdb
	    Kind           : Client
	    Start time     : 2026-05-27 07:32:37.358157078 +0000 UTC
	    End time       : 2026-05-27 07:32:37.360421315 +0000 UTC
	    Status code    : Unset
	    Status message : 
	    DroppedAttributesCount: 0
	    DroppedEventsCount: 0
	    DroppedLinksCount: 0
	Attributes:
	     -> db.user: Str(odmusr)
	     -> server.port: Int(5432)
	     -> server.address: Str(test-dbserver)
	     -> db.connection_string: Str(postgresql://test-dbserver:5432)
	     -> db.system: Str(postgresql)
	     -> db.statement: Str()
	     -> thread.id: Int(89)
	     -> db.name: Str(odmdb)
	     -> thread.name: Str(Default Executor-thread-7)
	Span #1
	    Trace ID       : 914029e493a16d5d71352479e27f64ec
	    Parent ID      : a9c5fcd129ff3524
	    ID             : 8e81944663271123
	    Name           : odmdb
	    Kind           : Client
	    Start time     : 2026-05-27 07:32:37.380594966 +0000 UTC
	    End time       : 2026-05-27 07:32:37.381414333 +0000 UTC
	    Status code    : Unset
	    Status message : 
	    DroppedAttributesCount: 0
	    DroppedEventsCount: 0
	    DroppedLinksCount: 0
	Attributes:
	     -> db.user: Str(odmusr)
	     -> server.port: Int(5432)
	     -> server.address: Str(test-dbserver)
	     -> db.connection_string: Str(postgresql://test-dbserver:5432)
	     -> db.system: Str(postgresql)
	     -> db.statement: Str()
	     -> thread.id: Int(89)
	     -> db.name: Str(odmdb)
	     -> thread.name: Str(Default Executor-thread-7)
	Span #2
	    Trace ID       : 914029e493a16d5d71352479e27f64ec
	    Parent ID      : a9c5fcd129ff3524
	    ID             : 2c1c86f8930b9ce2
	    Name           : odmdb
	    Kind           : Client
	    Start time     : 2026-05-27 07:32:37.399585421 +0000 UTC
	    End time       : 2026-05-27 07:32:37.400754406 +0000 UTC
	    Status code    : Unset
	    Status message : 
	    DroppedAttributesCount: 0
	    DroppedEventsCount: 0
	    DroppedLinksCount: 0
	Attributes:
	     -> db.user: Str(odmusr)
	     -> server.port: Int(5432)
	     -> server.address: Str(test-dbserver)
	     -> db.connection_string: Str(postgresql://test-dbserver:5432)
	     -> db.system: Str(postgresql)
	     -> db.statement: Str()
	     -> thread.id: Int(89)
	     -> db.name: Str(odmdb)
	     -> thread.name: Str(Default Executor-thread-7)
	Span #3
	    Trace ID       : 914029e493a16d5d71352479e27f64ec
	    Parent ID      : a9c5fcd129ff3524
	    ID             : 82af3643e74c3796
	    Name           : SELECT odmdb.RS_ENABLED_VIEW
	    Kind           : Client
	    Start time     : 2026-05-27 07:32:37.489026886 +0000 UTC
	    End time       : 2026-05-27 07:32:37.496791547 +0000 UTC
	    Status code    : Unset
	    Status message : 
	    DroppedAttributesCount: 0
	    DroppedEventsCount: 0
	    DroppedLinksCount: 0
	Attributes:
	     -> server.port: Int(5432)
	     -> server.address: Str(test-dbserver)
	     -> db.connection_string: Str(postgresql://test-dbserver:5432)
	     -> db.system: Str(postgresql)
	     -> db.statement: Str(SELECT RA_NAME, RA_MAJVERS, RA_MINVERS, RS_NAME, RS_MAJVERS, RS_MINVERS FROM RS_ENABLED_VIEW WHERE RA_NAME = ? AND RA_MAJVERS = ? AND RA_MINVERS = ? AND RS_NAME = ? AND RS_MAJVERS = ? AND RS_MINVERS = ? ORDER BY RA_MAJVERS DESC, RA_MINVERS DESC, RS_MAJVERS DESC, RS_MINVERS DESC)
	     -> thread.id: Int(89)
	     -> db.sql.table: Str(RS_ENABLED_VIEW)
	     -> db.operation: Str(SELECT)
	     -> db.name: Str(odmdb)
	     -> thread.name: Str(Default Executor-thread-7)
	Span #4
	    Trace ID       : 914029e493a16d5d71352479e27f64ec
	    Parent ID      : a9c5fcd129ff3524
	    ID             : 60d77632ddfe3764
	    Name           : odmdb
	    Kind           : Client
	    Start time     : 2026-05-27 07:32:37.501311632 +0000 UTC
	    End time       : 2026-05-27 07:32:37.502248091 +0000 UTC
	    Status code    : Unset
	    Status message : 
	    DroppedAttributesCount: 0
	    DroppedEventsCount: 0
	    DroppedLinksCount: 0
	Attributes:
	     -> db.user: Str(odmusr)
	     -> server.port: Int(5432)
	     -> server.address: Str(test-dbserver)
	     -> db.connection_string: Str(postgresql://test-dbserver:5432)
	     -> db.system: Str(postgresql)
	     -> db.statement: Str()
	     -> thread.id: Int(89)
	     -> db.name: Str(odmdb)
	     -> thread.name: Str(Default Executor-thread-7)
	Span #5
	    Trace ID       : 914029e493a16d5d71352479e27f64ec
	    Parent ID      : a9c5fcd129ff3524
	    ID             : 7a6b54518a62604f
	    Name           : SELECT odmdb
	    Kind           : Client
	    Start time     : 2026-05-27 07:32:37.505957389 +0000 UTC
	    End time       : 2026-05-27 07:32:37.507040901 +0000 UTC
	    Status code    : Unset
	    Status message : 
	    DroppedAttributesCount: 0
	    DroppedEventsCount: 0
	    DroppedLinksCount: 0
	Attributes:
	     -> server.port: Int(5432)
	     -> server.address: Str(test-dbserver)
	     -> db.connection_string: Str(postgresql://test-dbserver:5432)
	     -> db.system: Str(postgresql)
	     -> db.statement: Str(SELECT RS.ID FROM RULESETS RS, RULEAPPS RA WHERE RA.NAME = ? AND RA.MAJOR_VERSION = ? AND RA.MINOR_VERSION = ? AND RS.NAME = ? AND RS.MAJOR_VERSION = ? AND RS.MINOR_VERSION = ? AND RA.ID = RS.RULEAPP_ID)
	     -> thread.id: Int(89)
	     -> db.operation: Str(SELECT)
	     -> db.name: Str(odmdb)
	     -> thread.name: Str(Default Executor-thread-7)
	...
	```

Find the full traces in [otel-collector.logs](otel-collector.logs)



