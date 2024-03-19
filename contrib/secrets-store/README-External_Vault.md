# Créer un Vault externe

Sur le cluster OpenShift, installer tout d'abord l'opérateur Secrets Store CSI Driver Operator via l'OperatorHub ou en ligne de commande ; ensuite, le driver CSI de HashiCorp Vault seul peut être installé :

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

Sur une Ubuntu Fyre :

1. Installer Vault

D'après https://developer.hashicorp.com/vault/tutorials/getting-started/getting-started-install

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
gpg --no-default-keyring --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg --fingerprint
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vault
```

2. Créer un fichier de config

```bash
public_ip=$(dig a $(hostname -f) @9.0.0.1 +short)
cat >vault.hcl <<EOF
storage "file" {
 path = "/tmp/vault-data"
}

listener "tcp" {
 address = "http://${public_ip}:8200"
 tls_disable = 1
}

api_addr = "http://${public_ip}:8200"
cluster_addr = "http://${public_ip}:8201"
# log_level = "trace"
# log_file = "/tmp/vault.log"
EOF
```

3. Démarrer le serveur

```bash
vault server -dev -dev-root-token-id="root" -config vault.hcl
```

4. Utilisation

```bash
export VAULT_ADDR=http://<publicIP>:8200
vault login
```

5. Authentification OpenShift

D'après https://support.hashicorp.com/hc/en-us/articles/4404389946387-Kubernetes-auth-method-Permission-Denied-error

Récupérer l'adresse de l'API du serveur :

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
