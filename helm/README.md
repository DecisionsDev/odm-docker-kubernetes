Helm is a tool that streamlines installation and management of Kubernetes applications. Think of it like apt/yum/homebrew for Kubernetes.

    Helm has two parts: a client (helm) and a server (tiller)
    Tiller runs inside of your Kubernetes cluster, and manages releases (installations) of your charts.
    Helm runs on your laptop, CI/CD, or wherever you want it to run.
    Charts are Helm packages that contain at least two things:
        A description of the package (Chart.yaml)
        One or more templates, which contain Kubernetes manifest files
    Charts can be stored on disk, or fetched from remote chart repositories (like Debian or RedHat packages)

For more information about ODM Helm charts, see [stable/odmcharts/README.md](stable/odmcharts/README.md).

# 6.0 Implement your own Helm charts repository
```bash

    cd helm/stable
    helm package odmcharts
    docker run --name some-nginx -v <ABSOLUTE PATH>:/usr/share/nginx/html:ro -p 8090:80 -d nginx
    ifconfig # to retrieve your IP 
    helm repo index ./ --url http://<YOUR_IP>:8090/
    Open a browser to verify the chart is available at this location
    http://<YOUR_IP>:8090/index.yaml -> Should return a file with the reference of the charts.
  ````
