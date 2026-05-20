# Enable ODM distributed tracing with Microprofile telemetry

When applications are made observable, operations teams can more easily identify and understand the root causes of bugs, bottlenecks, and other inefficiencies. Liberty offers a robust framework for developing such observable applications and integrates seamlessly with numerous third-party monitoring tools. 

In the [Monitor ODM liberty metrics with mpMetrics and Prometheus](../mpmetrics/README.md) tutorial, we detailed how to enable Liberty metrics that depict the internal state of various Liberty components. In this document, we will discuss how to utilize MicroProfile Telemetry, which assists in collecting data on the paths that application requests take through services. More details on the usage of Microprofile Telemetry can be found in the [Liberty documentation](https://openliberty.io/docs/latest/microprofile-telemetry.html).

The goal of this tutorial is to demonstrate how to configure ODM on Kubernetes to enable communication with an OpenTelemetry collector that can process generated traces. This is not an in-depth OpenTelemetry tutorial. Therefore, it is advisable to familiarize yourself with the [Open Telemetry liberty configuration](https://openliberty.io/docs/latest/microprofile-telemetry.html#ol-config) before proceeding with this tutorial.

![Architecture](./images/otel_architecture.png) 

## Install Grafana Tempo to display traces

Grafana Tempo will be used to display traces emitted by the Open Telemetry Java agent and collected by the OpenTelemetry (OTEL) collector.

### Install Tempo

Tempo can be installed on various platforms. Below are instructions for different installation methods:

#### Option 1: Quick Installation using Helm (Recommended for testing)

Create the namespace and install Tempo:

```bash
kubectl create namespace tempo-system
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install tempo grafana/tempo -n tempo-system
```

This installs Tempo with default settings suitable for testing and development.

#### Option 2: Production Installation with Distributed Mode

For production environments, use the tempo-distributed chart which provides better scalability:

```bash
helm install tempo grafana/tempo-distributed -n tempo-system \
  --set traces.otlp.grpc.enabled=true \
  --set traces.otlp.http.enabled=true
```

#### Option 3: OpenShift with Tempo Operator (Easiest for OpenShift)

On OpenShift, the easiest way is to use the Red Hat OpenShift distributed tracing platform (Tempo) with MinIO as S3-compatible storage:

**Step 1: Install the Tempo Operator**

```bash
# Create the namespace
oc new-project tempo-system

# Install the operator via CLI
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: tempo-operator
  namespace: openshift-operators
spec:
  channel: stable
  name: tempo-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
```

Or install via the OpenShift Console:
1. Navigate to **Operators** → **OperatorHub**
2. Search for "Tempo" or "Red Hat OpenShift distributed tracing platform"
3. Click **Install** and follow the prompts

**Step 2: Deploy MinIO for S3-compatible storage (simplest for testing)**

```bash
# Deploy MinIO
cat <<EOF | oc apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: minio-pvc
  namespace: tempo-system
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  namespace: tempo-system
spec:
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      labels:
        app: minio
    spec:
      containers:
      - name: minio
        image: quay.io/minio/minio:latest
        args:
        - server
        - /data
        - --console-address
        - :9001
        env:
        - name: MINIO_ROOT_USER
          value: "tempo"
        - name: MINIO_ROOT_PASSWORD
          value: "supersecret"
        ports:
        - containerPort: 9000
        - containerPort: 9001
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: minio-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: minio
  namespace: tempo-system
spec:
  ports:
  - port: 9000
    targetPort: 9000
    name: api
  - port: 9001
    targetPort: 9001
    name: console
  selector:
    app: minio
EOF
```

**Step 3: Create the MinIO bucket**

```bash
# Wait for MinIO to be ready
oc wait --for=condition=available --timeout=300s deployment/minio -n tempo-system

# Create the bucket using MinIO client
oc run mc --image=quay.io/minio/mc:latest --restart=Never -n tempo-system --command -- \
  /bin/sh -c "mc alias set myminio http://minio.tempo-system.svc:9000 tempo supersecret && mc mb myminio/tempo && echo 'Bucket created successfully'"

# Wait for the job to complete and check logs
sleep 5
oc logs mc -n tempo-system

# Clean up the pod
oc delete pod mc -n tempo-system --ignore-not-found=true
```

Alternatively, you can create the bucket by port-forwarding to MinIO and using a local mc client:

```bash
# Port-forward to MinIO
oc port-forward svc/minio 9000:9000 -n tempo-system &
PF_PID=$!

# Wait a moment for port-forward to establish
sleep 3

# Create bucket using local mc (install from https://min.io/docs/minio/linux/reference/minio-mc.html)
mc alias set myminio http://localhost:9000 tempo supersecret
mc mb myminio/tempo

# Stop port-forward
kill $PF_PID
```

**Step 4: Create storage secret and TempoStack with Gateway (required for OpenShift)**

```bash
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: tempo-storage
  namespace: tempo-system
stringData:
  endpoint: http://minio.tempo-system.svc:9000
  bucket: tempo
  access_key_id: tempo
  access_key_secret: supersecret
type: Opaque
---
apiVersion: tempo.grafana.com/v1alpha1
kind: TempoStack
metadata:
  name: tempo
  namespace: tempo-system
spec:
  storage:
    secret:
      name: tempo-storage
      type: s3
  storageSize: 1Gi
  tenants:
    mode: openshift
    authentication:
      - tenantName: dev
        tenantId: "1610b0c3-c509-4592-a256-a1871353dbfa"
  template:
    gateway:
      enabled: true
    queryFrontend:
      jaegerQuery:
        enabled: true
        ingress:
          type: route
EOF
```

**Important:** The gateway is required on OpenShift for authentication and authorization. The configuration above:
- Enables the gateway component
- Uses OpenShift authentication mode
- Creates a default "dev" tenant
- Provides secure access to ingest and query paths

**Step 5: Wait for TempoStack to be ready**

```bash
oc get tempostack tempo -n tempo-system -w
```

Wait until STATUS shows "Ready". This may take a few minutes.

**Step 6: Get the Jaeger Query UI route**

```bash
oc get route -n tempo-system | grep jaeger
```

You can now access the Jaeger Query UI to view traces.

**Note:** For production environments, replace MinIO with a managed S3 service (AWS S3, Azure Blob Storage, or Google Cloud Storage) by updating the storage secret accordingly.

### Verify Tempo Installation

Check that Tempo is running:

```bash
kubectl get pods -n tempo-system
kubectl logs -n tempo-system -l app.kubernetes.io/name=tempo
```

You should see Tempo pods in Running state.

### Install Grafana for Trace Visualization

Install Grafana to query and visualize traces:

```bash
helm install grafana grafana/grafana -n tempo-system \
  --set persistence.enabled=true \
  --set persistence.size=10Gi \
  --set adminPassword=admin \
  --set service.type=ClusterIP
```

Get the Grafana admin password (if you didn't set it):

```bash
kubectl get secret --namespace tempo-system grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

### Configure Grafana Data Source

After Grafana is running, configure Tempo as a data source:

1. Access Grafana (see instructions in the "Observe the collected traces" section below)
2. Go to **Configuration** → **Data Sources** → **Add data source**
3. Select **Tempo**
4. Configure the following:
   - **Name**: Tempo
   - **URL**: `http://tempo.tempo-system.svc.cluster.local:3100`
   - Click **Save & Test**

Alternatively, you can configure the data source automatically during Grafana installation:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: tempo-system
data:
  datasources.yaml: |
    apiVersion: 1
    datasources:
    - name: Tempo
      type: tempo
      access: proxy
      url: http://tempo.tempo-system.svc.cluster.local:3100
      isDefault: true
EOF

helm upgrade grafana grafana/grafana -n tempo-system \
  --reuse-values \
  --set datasources.datasources\\.yaml.apiVersion=1 \
  --set datasources.datasources\\.yaml.datasources[0].name=Tempo \
  --set datasources.datasources\\.yaml.datasources[0].type=tempo \
  --set datasources.datasources\\.yaml.datasources[0].access=proxy \
  --set datasources.datasources\\.yaml.datasources[0].url=http://tempo.tempo-system.svc.cluster.local:3100
```

For more advanced configurations and production deployments, refer to the [Tempo documentation](https://grafana.com/docs/tempo/latest/setup/).

## Deploy the OpenTelemetry Collector

We will install the OpenTelemetry Collector near the ODM Instance in a project named **otel**.
On OCP, create the **otel** project:

```bash
oc new-project otel
```

Install the [OpenTelemetry Collector Helm Chart](https://opentelemetry.io/docs/platforms/kubernetes/helm/collector/):

```bash
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
```

Install the Collector instance using [otel-collector-values.yaml](./otel-collector-values.yaml)

```bash
helm install my-opentelemetry-collector open-telemetry/opentelemetry-collector \    
	--set image.repository="otel/opentelemetry-collector-k8s" \
	-f otel-collector-values.yaml
```

Verify that the OpenTelemetry Collector is up and running by executing:

 ```bash
kubectl logs deployment/my-opentelemetry-collector
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
    --docker-username=cp --docker-password="<ENTITLEMENT_KEY>" --docker-email=<USER_EMAIL>
```

Where:
* `<ENTITLEMENT_KEY>` is the entitlement key from the previous step. Make sure you enclose the key in double-quotes.
* `<USER_EMAIL>` is the email address associated with your IBMid.

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
ibm-helm/ibm-odm-prod           	25.1.0       	9.5.0.1   	IBM Operational Decision Manager
```

### Install an IBM Operational Decision Manager release (10 min)

Install a Kubernetes release with the default configuration named `otel-odm-release`, injecting the OTEL Java agent with the relevant JVM configuration.

We'll use the **decisionServerRuntime.downloadUrl** parameter to download the [OTEL Java agent](https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases), which will be injected into the container at the `/config/download/opentelemetry-javaagent.jar` path.

To configure the OTEL Java agent, we need to set up some JVM options, such as:

```bash
    -javaagent:/config/download/opentelemetry-javaagent.jar
    -Dotel.sdk.disabled=false
    -Dotel.exporter.otlp.protocol=grpc
    -Dotel.exporter.otlp.endpoint=http://my-opentelemetry-collector.otel.svc.cluster.local:4317
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

