# Introduction

In the rapidly evolving world of Kubernetes (K8s), securing sensitive information remains a paramount concern. Traditional methods, like using K8s secrets, often fall short in providing the necessary security measures. 

This article delves into a more robust solution: integrating IBM's Operation Decision Manager (ODM) with HashiCorp Vault utilizing the  [Secrets Store CSI Driver](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-secret-store-driver).

Why this integration? K8s secrets, while convenient, are sometimes deemed insufficient for high-security environments. 

The integration of ODM with HashiCorp Vault via the Secrets Store CSI Driver offers a more secure and efficient way to handle sensitive data.

On the ODM side, we introduce an init container - a specialized container that sets up the necessary environment before the main container runs. In this init container, we inject the Vault CSI volume. This approach allows us to craft a shell script, which is then executed within the init container, to seamlessly transfer the files into the ODM containers.


This article guides you through the setup and configuration process, ensuring a secure and streamlined integration of these powerful technologies.

# Architecture
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

The architecture diagram illustrates the integration process between the Secret Manager Server and IBM Operation Decision Manager (ODM) pods within a Kubernetes environment using the Secrets Store CSI Driver. 
![Vault Overview schema](/images/Contrib/vault/VaultInitContainer.jpg)

- **Secret Manager Server**: It functions as the central repository for all secrets data, securely managing sensitive information.

- **Secrets Data**: Labeled clearly, this represents the actual sensitive information that needs to be securely managed and injected into the ODM Pods.

- **Secret Store CSI Driver**: 
  - It acts as a secure bridge between the Secret Manager Server and the Kubernetes cluster.
  - It's in charge of safely transmitting the secrets data to the ODM Pods within Kubernetes.

- **Kubernetes**:  It's the container orchestration system where the ODM application is deployed.

- **ODM Pods**: 
  - Detailed within the Kubernetes rectangle, showcasing the components that make up the ODM Pods:
    - **Init Container**:
      - A temporary container that runs a shell script ('Vault.sh') before the main ODM Containers start. See the sample [vault.sh](configmap/vault.sh) script for more details. 
      - It's responsible for retrieving the secrets data from the Secret Store CSI Driver and placing it into a shared volume. 
    - **Volume**:
      - Represented by the two smaller rectangles within the ODM Pods.
      - This is where the secrets data is stored after retrieval, accessible by both the init container and the ODM Containers.
    - **ODM Containers**:
      - The main containers running the ODM application.
      - They utilize the secrets data stored in the volume for secure operations and configuration. An empty dire ephemeral storage is used to transmit the data between the containers.

The diagram visually represents the secure flow of secrets data from the central manager to the ODM application in Kubernetes, facilitated by the Secret Store CSI Driver, ensuring best practices in secret management.

## Pre-requisite 
   * Harshicorp Instance evaluation setup and running. Tutorial can found [here](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-secret-store-driver).
   * Helm V3
   * Kustomize
   * Operational Decision Manager on Container 8.12.0.1

> Note: This documentation has been tested with a HashiCorp evaluation instance. We assume that the procedure will remain the same for the commercial product.
> 
# Setup an Harshicorp vault with ODM on Kubernetes
# Configure connection between the Vault server and the Kubernetes resources

##### Configure Kubernetes authentication in the Vault server
Vault provides a Kubernetes authentication method that enables clients to authenticate with a Kubernetes Service Account Token. This token is provided to each pod when it is created.

```bash
oc exec -ti vault-0 --namespace vault -- sh
/ $ vault auth enable kubernetes
/ $ vault write auth/kubernetes/config \
    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
```

###### You can use `vault` command line for the next steps or use the vault pod as in the previous step.
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

