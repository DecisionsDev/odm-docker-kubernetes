# Overview

Helm is a tool that streamlines installing and managing Kubernetes applications. 

Helm consists of two parts: a client (`helm`) and a server (`tiller`):
- Tiller runs inside of your Kubernetes cluster, and manages releases (installations) of your charts.
- Helm runs on your laptop, CI/CD, or wherever you want it to run.

Charts are Helm packages that contain at least two things:
- A description of the package (`Chart.yaml`)
- One or more templates, which contain Kubernetes manifest files

Charts can be stored on disk or fetched from remote chart repositories, which is similar to Debian or RedHat packages.

For more information about Helm, see [Kubernetes Helm](https://github.com/kubernetes/helm)

For information about ODM Helm charts, see [stable/odmcharts/README.md](stable/odmcharts/README.md).

# Create your own Helm charts repository

To create your Helm charts repository, run the following commands:
```

    cd helm/stable
    helm package odmcharts
    docker run --name some-nginx -v <ABSOLUTE PATH>:/usr/share/nginx/html:ro -p 8090:80 -d nginx
```
Run `ifconfig` to retrieve your IP address.
Run the following command:
```
    helm repo index ./ --url http://<YOUR_IP>:8090/
```
Open a browser to verify the chart is available at this location: http://_<YOUR_IP>_:8090/index.yaml. It should return a file with the reference of the charts.


