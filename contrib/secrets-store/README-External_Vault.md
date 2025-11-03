# Install, configure and use HashiCorp Vault on Ubuntu

We provide here some installation hints about the installation and the configuration of a test instance for HashiCorp Vault so that it can be used as a secrets store on OpenShift Container Platform.

## Installation

On Ubuntu 22.04, from <https://developer.hashicorp.com/vault/tutorials/getting-started/getting-started-install>, add HashiCorp Vault's repository and download it:

```shell
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
gpg --no-default-keyring --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg --fingerprint
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vault
```

Edit its configuration file in order to enable HTTP connectivity instead of HTTPS (it will be enough for this demonstration). The configuration file should look like this:

```text
ui = true

storage "file" {
  path = "/opt/vault/data"
}

# HTTP listener
listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = 1
}
```

Enable and start the service:

```shell
sudo systemctl enable vault
sudo systemctl start vault
```

Initialize the server:

```shell
export VAULT_ADDR=http://<serverfqdn>:8200
vault operator init
```

Make sure you keep the unseal keys and token that will be displayed in a safe place! They can't be retrieved afterwards.

Unseal the vault:

```shell
vault operator unseal
```

It will ask for any unseal key (displayed above). You have to run the same command three times (with different keys!) before the vault is actually unsealed.

You can then log into the vault:

```shell
vault login
```

Just enter the root token displayed at the end of the init step.

Activate the kv-2 secrets engine which allows to keep simple secrets such as passwords and certificates along with their history:

```shell
vault secrets enable -version=2 -path <secretspath> kv
```

## Secrets Store CSI driver and provider

The installation of the Secrets Store CSI driver is straightforward on OpenShift 4.14+: Go the OperatorHub, look for "Secrets Store CSI Driver Operator" and deploy the operator with its defaults.

Then create the CSI Driver itself:

```shell
oc apply -f - <<EOF
apiVersion: operator.openshift.io/v1
kind: ClusterCSIDriver
metadata:
  name: secrets-store.csi.k8s.io
spec:
  logLevel: Normal
  managementState: Managed
  operatorLogLevel: Trace
EOF
```

When done, install the HashiCorp Vault provider driver:

```shell
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
oc adm policy add-scc-to-user privileged system:serviceaccount:vault:vault-csi-provider
helm install vault hashicorp/vault --namespace vault --create-namespace -f - <<EOF
csi:
  agent:
    image:
      repository: docker.io/hashicorp/vault
  daemonSet:
    securityContext:
      container:
        privileged: true
  enabled: true
global:
  openshift: true
injector:
  enabled: false
server:
  enabled: false
EOF
```

Verify that one pod for each worker node is created in the "vault" namespace before continuing:

```shell
oc get pods --namespace vault --output wide
```

## Configuration of HashiCorp Vault for OCP usage

<!-- markdown-link-check-disable-next-line -->
(With help from <https://support.hashicorp.com/hc/en-us/articles/4404389946387-Kubernetes-auth-method-Permission-Denied-error> and <https://computingforgeeks.com/how-to-integrate-multiple-kubernetes-clusters-to-vault-server/>)

Log into your OCP cluster.

Get its API IP address:

```shell
KUBE_HOST=$(kubectl config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.server}')
```

For the next two elements you have to find the secret containing the token for the Service Account "vault" in namespace "vault". Its name is like vault-token-XXXXX on OpenShift:

```shell
SA_TOKEN_SECRET=$(kubectl get secrets --namespace vault --output=jsonpath='{.items[?(@.metadata.annotations.kubernetes\.io/service-account\.name=="vault")].metadata.name}' --field-selector type=kubernetes.io/service-account-token)
```

Get the Service Account's token from it:

```shell
TOKEN_REVIEW_JWT=$(kubectl get secret ${SA_TOKEN_SECRET} -n vault -o go-template='{{ .data.token }}' | base64 --decode)
```

And get also the certificate chain of the server (yes it is in the same secret indeed):

```shell
kubectl get secret ${SA_TOKEN_SECRET} -n vault -o jsonpath='{.data.ca\.crt}' | base64 -d > ca.crt
```

You can then configure the Vault with these elements:

```shell
vault auth enable -path <clustername> kubernetes
vault write auth/<clustername>/config \
    token_reviewer_jwt="${TOKEN_REVIEW_JWT}" \
    kubernetes_host="${KUBE_HOST}" \
    kubernetes_ca_cert=@ca.crt \
    disable_local_ca_jwt="true"
```
