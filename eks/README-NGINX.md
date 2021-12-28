# Deploying IBM Operational Decision Manager with NGINX Ingress Controller on Amazon EKS

The aim of this complementary documentation is to explain how to replace the AWS Load Balancer Controller usage by an NGINX Ingress Conroller.
Assuming you realize the step 1 of [Deploying IBM Operational Decision Manager on Amazon EKS](README.md#1-prepare-your-environment-40-min) , you can replace the "Provision an AWS Load Balancer Controller" step by following the Nginx Ingress Controller installation with the chart explained in the [ingress-nginx readme](https://github.com/kubernetes/ingress-nginx/tree/main/charts/ingress-nginx#install-chart)

```console
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install my-odm-nginx ingress-nginx/ingress-nginx
```

If your AWS subnets have been well tagged using 

```bash
key: kubernetes.io/cluster/<cluster-name> | Value: shared
key: kubernetes.io/role/elb | Value: 1
```
my-odm-ginx should have an available External-IP when execution the command :

```console
kubectl --namespace default get services -o wide -w my-odm-nginx-ingress-nginx-controller
```

Now, you can follow all the steps of the Deploying IBM Operational Decision Manager on Amazon EKS documentation.
You just have to replace during the helm install **eks-values.yaml** by **eks-nginx-values.yaml** that contains the relevant ingress annotations :
"kubernetes.io/ingress.class: nginx" and "nginx.ingress.kubernetes.io/backend-protocol: https" 
