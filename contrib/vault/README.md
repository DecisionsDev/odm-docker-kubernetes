# Introduction
This documentation explain how to use ODM with Harshicorp vault
This implementation use the [CSIDriver feature](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-secret-store-driver).
Note that this documentation has been tested with a Harshicorp evaluation instance. We assume that for the commercial product the procedure will remains the same.

## Architecture
The Container Storage Interface (CSI) pattern is essentially a standardized approach for connecting block or file storage to containers. This standard is adopted by various storage providers.

On Kubernetes, the Secrets Store CSI Driver operates as a DaemonSet. It interacts with each Kubelet instance on the Kubernetes nodes. When a pod initiates, this driver liaises with the external secrets provider to fetch secret data. The accompanying diagram demonstrates the functionality of the Secrets Store CSI Driver within Kubernetes.

![Vault Overview schema](/images/Contrib/vault/Overview.png)

To manage this process, the SecretProviderClass Custom Resource Definition (CRD) is utilized. Within this provider class, it's necessary to specify the address of the secure vault and the locations of the secret keys. The following is the SecretProviderClass for our specific case, which involves using HashiCorp Vault deployed on Kubernetes.
```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: vault-database
spec:
  provider: vault
  parameters:
    vaultAddress: http://vault:8200
    roleName: database
    objects: |
      - objectName: "db-password"
        secretPath: "secret/data/db-pass"
        secretKey: "db-password"
      - objectName: "db-user"
        secretPath: "secret/data/db-pass"
        secretKey: "db-user"
      - objectName: "automation.crt"
        secretPath: "secret/data/trustedcertificates"
        secretKey: "automationcloud.crt"
      - objectName: "tls.crt"
        secretPath: "secret/data/privatecertificates"
        secretKey: "tls.crt"
      - objectName: "tls.key"
        secretPath: "secret/data/privatecertificates"
        secretKey: "tls.key"
```

To be able to use 

## Pre-requisite 
   * Harshicorp Instance 
   * Helm V3
   * Kustomize
   * ODM 

### Configure connection between the Vault server and the Kubernetes resources

##### Configure Kubernetes authentication in the Vault server
Vault provides a Kubernetes authentication method that enables clients to authenticate with a Kubernetes Service Account Token. This token is provided to each pod when it is created.

```bash
oc exec -ti vault-0 --namespace vault -- sh
/ $ vault auth enable kubernetes
/ $ vault write auth/kubernetes/config \
    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
```

###### You can use `vault` command line for the next steps
```bash
export VAULT_ADDR=http://$(oc get route vault -n vault -o jsonpath='{.spec.host}')
vault login
```

- Define the `odm-policy` policy that enables the read capability for secrets at path `secret/data/`
  
```bash
vault policy write odm-policy - <<EOF
path "secret/data/*" {
  capabilities = ["read"]
}
EOF
```

- Create a Kubernetes authentication role

```bash
vault write auth/kubernetes/role/database \
    bound_service_account_names=odm-sa \
    bound_service_account_namespaces=odm \
    policies=odm-policy \
    ttl=24h
```

##### Populate the secrets in the vault

```bash
export VAULT_ADDR=http://$(oc get route vault --no-headers -o custom-columns=HOST:.spec.host)
vault kv put secret/privatecertificates tls.crt=@vaultdata/mycompany.crt  tls.key=@vaultdata/mycompany.key
vault kv put secret/trustedcertificates automationcloud.crt=@vaultdata/automationcloud.crt
vault kv put secret/db-pass db-password="postgrespwd" db-user="postgresuser"
```



### 3. Prepare your environment for the ODM installation (10 min)

To get access to the ODM material, you need an IBM entitlement key to pull the images from the IBM Entitled Registry.

#### a. Retrieve your entitled registry key

- Log in to [MyIBM Container Software Library](https://myibm.ibm.com/products-services/containerlibrary) with the IBMid and password that are associated with the entitled software.

- In the Container software library tile, verify your entitlement on the **View library** page, and then go to **Get entitlement key** to retrieve the key.

#### b. Create a pull secret by running a kubectl create secret command.

```
kubectl create secret docker-registry <REGISTRY_SECRET> \
        --docker-server=cp.icr.io \
        --docker-username=cp \
        --docker-password="<API_KEY_GENERATED>" \
        --docker-email=<USER_EMAIL>
```

Where:

* `<REGISTRY_SECRET>` is the secret name.
* `<API_KEY_GENERATED>` is the entitlement key from the previous step. Make sure you enclose the key in double-quotes.
* `<USER_EMAIL>` is the email address associated with your IBMid.

> NOTE:  The `cp.icr.io` value for the docker-server parameter is the only registry domain name that contains the images. You must set the docker-username to `cp` to use an entitlement key as docker-password.

Take note of the secret name so that you can set it for the *image.pullSecrets* parameter when you run a helm install command of your containers.  The *image.repository* parameter will later be set to `cp.icr.io/cp/cp4a/odm`.

#### c. Add the public IBM Helm charts repository

```
helm repo add ibm-helm https://raw.githubusercontent.com/IBM/charts/master/repo/ibm-helm
helm repo update
```

#### d. Check you can access ODM charts

```
helm search repo ibm-odm-prod
NAME                  	CHART VERSION   APP VERSION     DESCRIPTION
ibm-helm/ibm-odm-prod	23.2.0          8.12.0.1        IBM Operational Decision Manager
```

#### Installation 

1. Edit the values-default-vault.yaml and abjust the values.

2. Kustomize helm deployment with the csi driver

```bash
helm template odm-vault-kust ../ibm-odm-prod -f values-default-vault.yaml > odm-template-nocsi.yaml && kustomize build -o odm-csi.yaml && oc apply -f odm-csi.yaml
```

After some minutes ODM should be up and running

