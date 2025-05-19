# Using sticky session for Decision Center connection

The aim of this complementary documentation is to explain how to enable sticky session for Decision Center connection, using NGINX ingress.

Sticky sessions or session affinity, is a feature that allows you to keep a session alive for a certain period of time. In a Kubernetes cluster, if sticky session is enabled, all the traffic from a client to an application will be redirected to the same pod, even with multiple replicas.

## Prerequisites

This supposes that you already provision an NGINX Ingress Controller in your cluster. Refer to the documentation corresponding to your platform for more information.

## Deploy ODM without Ingress

To install ODM without Ingress:

- Get the appropriate value file for your platform and set the `ingress.enabled` parameter to `false`:
    ```yaml
    ingress:
      enabled: false
    ```
> **Note**
> `false` is the default value if not provided.

- Run the helm install command:

```
helm install mycompany ibm-helm/ibm-odm-prod --version 25.0.0 -f my-nginx-values.yaml
```

## Configuring Ingress to use sticky sessions

To be able to use sticky session in Decision Center but not enabling it in Decision Server, you must create to different Ingress instances.

Replace the `RELEASE_NAME` environment variable in both file and apply them:

```bash
export RELEASE_NAME=mycompany

envsubst < ingress-dc.yaml | kubectl apply -f -
envsubst < ingress-ds.yaml | kubectl apply -f -
```

The [ingress-dc.yaml](ingress-dc.yaml) configuration file uses the `nginx.ingress.kubernetes.io/affinity: cookie` annotation that enable sticky sessions.

> **Note**
> If you are on AWS/EKS and that your are using the ALB instead of NGINX Ingress Controller, [ALB annotations to manage sticky session](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.2/guide/ingress/annotations/) will be :
> 
> alb.ingress.kubernetes.io/target-group-attributes: stickiness.enabled=true,stickiness.lb_cookie.duration_seconds=60
> alb.ingress.kubernetes.io/target-type: ip 

### 6. Access the ODM services  

After a couple of minutes, the Ingress configuration is updated. You can then access the ODM services by retrieving the URLs with this command:

```bash
export DC_ROOTURL=$(kubectl get ingress mycompany-odm-dc-ingress --no-headers |awk '{print $4}')
export DS_ROOTURL=$(kubectl get ingress mycompany-odm-ds-ingress --no-headers |awk '{print $4}')
```

The ODM services are accessible from the following URLs:

| *Component* | *URL* | *Username/Password* |
|---|---|---|
| Decision Center | https://${DC_ROOTURL}/decisioncenter | odmAdmin/odmAdmin |
| Decision Center Swagger | https://${DC_ROOTURL}/decisioncenter-api | odmAdmin/odmAdmin |
| Decision Server Console |https://${DS_ROOTURL}/res| odmAdmin/odmAdmin |
| Decision Server Runtime | https://${DS_ROOTURL}/DecisionService | odmAdmin/odmAdmin |
| Decision Runner | https://${DS_ROOTURL}/DecisionRunner | odmAdmin/odmAdmin |
