Helm is a tool that streamlines installing and managing Kubernetes applications. Think of it like apt/yum/homebrew for Kubernetes.

    Helm has two parts: a client (helm) and a server (tiller)
    Tiller runs inside of your Kubernetes cluster, and manages releases (installations) of your charts.
    Helm runs on your laptop, CI/CD, or wherever you want it to run.
    Charts are Helm packages that contain at least two things:
        A description of the package (Chart.yaml)
        One or more templates, which contain Kubernetes manifest files
    Charts can be stored on disk, or fetched from remote chart repositories (like Debian or RedHat packages)
