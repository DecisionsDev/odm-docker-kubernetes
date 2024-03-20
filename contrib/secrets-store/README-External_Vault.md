# Install, configure and use HashiCorp Vault on Ubuntu

We provide here some installation hints about the installation and the configuration of a test instance for HashiCorp Vault so that it can be used as a secrets store on OpenShift Container Platform.

## Secrets Store CSI driver and provider

The installation of the Secrets Store CSI driver is straightforward on OpenShift: Go the OperatorHub, look for "Secrets Store CSI Driver Operator" and deploy the operator with its defaults.

Then create the CSI Driver itself:

```bash
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

```bash
oc adm policy add-scc-to-user privileged system:serviceaccount:vault:vault-csi-provider
helm install vault hashicorp/vault \
    --set "global.openshift=true" \
    --set "server.enabled=false" \
    --set "injector.enabled=false" \
    --set "csi.enabled=true" \
    --set "csi.daemonSet.securityContext.container.privileged=true" \
    --namespace vault \
    --create-namespace
```

Verify that one pod for each worker node is created in the "vault" namespace before continuing:

```bash
oc get pods --namespace vault --output wide
```

## Installation

On Ubuntu 22.04, from https://developer.hashicorp.com/vault/tutorials/getting-started/getting-started-install, add HashiCorp Vault's repository and download it:

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
gpg --no-default-keyring --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg --fingerprint
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vault
```

Edit its configuration file in order to enable HTTP connectivity instead of HTTPS (it will be enough for this demonstration). The configuration file should look like this:

```
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

```bash
sudo systemctl enable vault
sudo systemctl start vault
```

Initialize the server:

```bash
export VAULT_ADDR=http://<serverfqdn>:8200
vault operator init
```

Make sure you keep the unseal keys and token that will be displayed in a safe place! They can't be retrieved afterwards.

Unseal the vault:

```bash
vault operator unseal
```

It will ask for any unseal key (displayed above). You have to run the same command three times (with different keys!) before the vault is actually unsealed.

You can then log into the vault:

```bash
vault login
```

Just enter the root token displayed at the end of the init step.

## Configuration for OCP usage

(With help from https://support.hashicorp.com/hc/en-us/articles/4404389946387-Kubernetes-auth-method-Permission-Denied-error.)

Log into your OCP cluster.

Get its API IP address:

    KUBE_HOST=$(kubectl config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.server}')

Pour les deux éléments suivants, il faut récupérer le secret contenant le token pour le Service Account "vault" du namespace "vault". Sur OpenShift il a un nom sous la forme vault-token-XXXXXXXX.

Récupérer le token du Service Account qui autorisera la connexion à l'API K8s depuis Vault :

    TOKEN_REVIEW_JWT=$(kubectl get secret vault-token-XXXXXXXX -n vault -o go-template='{{ .data.token }}' | base64 --decode)

Récupérer enfin la chaîne de certificats du serveur (elle se trouve curieusement dans le même secret qu'au dessus):

    kubectl get secret -n vault vault-token-qmfcv -o yaml -o jsonpath='{.data.ca\.crt}'|base64 -d > ca.crt

Et configurer Vault enfin avec ces éléments :

```bash
vault auth enable kubernetes
vault write auth/kubernetes/config \
    token_reviewer_jwt="${TOKEN_REVIEW_JWT}" \
    kubernetes_host="${KUBE_HOST}" \
    kubernetes_ca_cert=@ca.crt \
    disable_local_ca_jwt="true"
```

6. Création d'un secret

Création secrets (serveur Vault en mode dev): https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-secret-store-driver

Sinon en mode prod, il faut d'abord activer l'engine kv :

```bash
vault secrets enable -version=2 -path secret kv
```

```bash
vault kv put secret/db-pass db-password="myodmpwd" db-user="myodmusr"
vault kv put secret/myodmcompany myodmcompany.key=@myodmcompany.key myodmcompany.crt=@myodmcompany.crt
```

7. Autorisation

Créer une politique pour le déploiement d'ODM :

```bash
vault policy write odm-policy - <<EOF
path "secret/data/*" {
  capabilities = ["read"]
}
EOF
```

Attribuer la politique au ServiceAccount de la release :

```bash
vault write auth/kubernetes/role/database \
    bound_service_account_names=toto-ibm-odm-prod-service-account \
    bound_service_account_namespaces=odm01 \
    policies=odm-policy \
    ttl=20m
```

Il peut être intéressant de tester à ce moment-là que tout marche bien du côté Vault :

```bash
TOKEN_REVIEW_SJWT=$(oc get secret toto-ibm-odm-prod-service-account-token-XXXXXXXX -n odm01 -o jsonpath='{.data.token}'|base64 -d)
curl -X POST --data "{\"jwt\": \"${TOKEN_REVIEW_SJWT}\", \"role\": \"database\"}" http://<publicIP>:8200/v1/auth/kubernetes/login
```

ce qui devrait renvoyer du JSON avec plein de données, commençant par une request_id. Si on obtient un "Permission denied"... ben on a dû se tromper quelque part (ou alors Red Hat a frappé et a modifié des trucs dans OpenShift).

Ensuite seulement, quand le curl au-dessus fonctionne, on peut créer la SecretProviderClass et lancer le helm install.
