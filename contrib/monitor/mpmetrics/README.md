# Monitor ODM liberty metrics with mpMetrics and Prometheus

The aim of this tutorial is to explain how to expose ODM Liberty metrics provided by mpMetrics using Prometheus on an Openshift cluster. 

## What is Prometheus ?

Prometheus stores its data in time-series databases, which allow for easy querying and aggregation of data over time. It uses a pull modeling approach, where it periodically queries the target systems to collect their metrics. These metrics are then stored in Prometheus time-series database and can be used for monitoring, alerting, and visualization.

Prometheus is supported natively in OpenShift.

## What is mpMetrics Liberty feature ?

The MicroProfile mpMetrics Liberty feature provides a /metrics endpoint from which you can access all metrics that are emitted by the Liberty server and deployed applications. When the application runs, you can view your metrics from any browser by accessing the endpoint.

## Prerequisites

- [Helm 3.1](https://helm.sh/docs/intro/install/)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl)
- Access to an Operational Decision Manager product
- Access to an Openshift cluster

## How to expose ODM metrics in OCP

### Create a secret to use the Entitled Registry

1. To get your entitlement key, log in to [MyIBM Container Software Library](https://myibm.ibm.com/products-services/containerlibrary) with the IBMid and password that are associated with the entitled software.

    In the **Container software library** tile, verify your entitlement on the **View library** page, and then go to **Get entitlement key**  to retrieve the key.

2. Create a pull secret by running a `kubectl create secret` command.

    ```
    kubectl create secret docker-registry ibm-entitlement-key \
        --docker-server=cp.icr.io \
        --docker-username=cp \
        --docker-password="<API_KEY_GENERATED>" \
        --docker-email=<USER_EMAIL>
    ```

    Where:

    - *API_KEY_GENERATED* is the entitlement key from the previous step. Make sure you enclose the key in double-quotes.
    - *USER_EMAIL* is the email address associated with your IBMid.

    > Note: 
    > 1. The **cp.icr.io** value for the docker-server parameter is the only registry domain name that contains the images. You must set the *docker-username* to **cp** to use an entitlement key as *docker-password*.
    > 2. The `ibm-entitlement-key` secret name will be used for the `image.pullSecrets` parameter when you run a Helm install of your containers. The `image.repository` parameter is also set by default to `cp.icr.io/cp/cp4a/odm`.


### Create a secret to configure mpMetrics

Get the [monitor.xml](./monitor.xml) file that is containing a minimal mpMetrics liberty configuration. You can add your own configuration using [liberty documentation](https://openliberty.io/docs/23.0.0.12/reference/config/mpMetrics.html)

Create the monitor-secret

  ```shell
  kubectl create secret generic monitor-secret --from-file=monitor.xml
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
  ibm-helm/ibm-odm-prod	  25.0.0       	9.5.0.0   	IBM Operational Decision Manager
  ```

### 3. Run the `helm install` command

You can now install the product. We will use the PostgreSQL internal database and disable data persistence (`internalDatabase.persistence.enabled=false`) to avoid any platform complexity with persistent volume allocation.

See the [Preparing to install](https://www.ibm.com/docs/en/odm/9.5.0?topic=production-preparing-install-operational-decision-manager) documentation for more information.

```shell
helm install my-odm-release ibm-helm/ibm-odm-prod -f monitor-values.yaml
```

> [!NOTE]
> **customization.monitorRef** is installing /metrics endpoint on all components. 
> If you would like to install /metrics on a specific component, you can replace usage of **customization.monitorRef** by **decisionCenter.monitorRef** , **decisionServerConsole.monitorRef** , **decisionRunner.monitorRef** or **decisionServerRuntime.monitorRef**
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

### 4. Check the /metrics endpoints

As the installation has been done using **customization.monitorRef**, all ODM components are exposing metrics. So, you can check all /metrics endpoints exposed by the routes.
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
curl -k https://<DC_HOST>/metrics
curl -k https://<DR_HOST>/metrics
curl -k https://<DS_CONSOLE_HOST>/metrics
curl -k https://<DS_RUNTIME_HOST>/metrics
```

You should get a view of all Liberty metrics that will be accessible in Prometheus:
    
```
# HELP gc_total Displays the total number of collections that have occurred. This attribute lists -1 if the collection count is undefined for this collector.
# TYPE gc_total counter
gc_total{mp_scope="base",name="global",} 377.0
gc_total{mp_scope="base",name="scavenge",} 312.0
...
# HELP connectionpool_waitTime_total_seconds The total wait time on all connection requests since the start of the server.
# TYPE connectionpool_waitTime_total_seconds gauge
connectionpool_waitTime_total_seconds{datasource="jdbc_ilogDataSource",mp_scope="vendor",} 0.0
```

## Expose metrics in OCP

### Enable Monitoring

Follow the OCP documentation explaining how to [enable monitoring for user-defined projects](https://docs.openshift.com/container-platform/4.14/monitoring/enabling-monitoring-for-user-defined-projects.html) 

If you are logged as the kubeadmin user, creating the [enableMetricsConfigMap.yaml](./enableMetricsConfigMap.yaml) configmap is enough:

```
kubectl create -f enableMetricsConfigMap.yaml
```

### Check that ODM targets are available

The ODM Helm chart instance has created a PodMonitor k8s resource that you can retrieve now in the OCP dashboard.
* Drill at Observe > Target
* Click on Filter and check **User**
 
You should see the 4 ODM metrics endpoints

![Targets](./images/targets.png) 

### Consume Metrics with Prometheus

Drill at Observe > metrics.

You can now use any kind of available metrics using a query.
For example put **gc_total** in the **Expression** field and click on the **Run queries** button.

![Queries](./images/queries.png)

If you are interested in servlet requests managed by the runtime, you can use the query **servlet_request_total{mp_scope="vendor",servlet="DecisionService_RESTDecisionService"}**
For example, by monitoring this metrics, you can check the behaviour of the load balancer is correct if all Decision Server Runtime replicas are receiving almost the same number of requests like in the following screenshot.
 
![Runtime Servlet Request](./images/RuntimeRequest.png)

### Consume Metrics with Grafana Dashboard

If you prefer to visualize the metrics using Grafana Dashboard, you can follow this [documentation](https://cloud.redhat.com/experts/o11y/ocp-grafana/) explaining how to install Grafana on OCP and connect it to Promotheus.

You can use this dashboard to help spot performance issues. For instance, metrics such as servlet response times, CPU or heap usage when seen as a time-series on Grafana, could be indicative of an underlying performance issue or memory leak.

![Grafana Dashboard](./images/GrafanaDashboard.png)
