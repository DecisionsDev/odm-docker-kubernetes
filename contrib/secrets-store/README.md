# Managing ODM secrets with Secret Store CSI Driver

## Introduction

In the rapidly evolving world of Kubernetes (K8s), securing sensitive information remains a paramount concern. Traditional methods, like using K8s secrets, often fall short in providing the necessary security measures.

This article delves into a more robust solution: integrating IBM's Operation Decision Manager (ODM) with external secrets stores supported by the [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/).

Why this integration? K8s secrets, while convenient, are sometimes deemed insufficient for high-security environments.

The integration of the ODM running on Kubernetes with an external secret store via the Secrets Store CSI Driver offers a more secure and efficient way to handle sensitive data.

This article guides you through the setup and configuration process, ensuring a secure and streamlined integration of these powerful technologies.

We will use [Hashicorp Vault as secrets store](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-secret-store-driver) and OpenShift Container Platform (OCP) as a Kubernetes cluster for this article.

> Alternatively, you may consider our [Vault initcontainer setup](../vault-initcontainer/README.md) as another secure method for managing secrets in the ODM on Kubernetes offering. This option requires more hands-on work but it offers greater flexibility to tailor the secret management to your specific requirements. If your project demands a more customizable approach, this could be the right choice. We recommend reviewing both configurations to determine which aligns best with your needs for control and customization.

## Architecture

The Container Storage Interface (CSI) pattern is essentially a standardized approach for connecting block or file storage to containers. This standard is adopted by various storage providers.

On Kubernetes, the Secrets Store CSI Driver operates as a DaemonSet. It interacts with each Kubelet instance on the Kubernetes nodes. When a pod initiates, this driver liaises with the external secrets provider to fetch secret data. The accompanying diagram demonstrates the functionality of the Secrets Store CSI Driver within Kubernetes.

The architecture diagram illustrates the integration process between the Secret Manager Server and IBM Operation Decision Manager (ODM) pods within a Kubernetes environment using the Secrets Store CSI Driver.

![Vault Overview schema](images/VaultInitContainer.png)

- **Secret Manager Server**: It functions as the central repository for all secrets data, securely managing sensitive information.

- **Secrets Data**: Labeled clearly, this represents the actual sensitive information that needs to be securely managed and injected into the ODM Pods.

- **Secrets Provider Class**: Definition of the data that should be injected in the ODM Pods.

- **Secret Store CSI Driver**:
  - It acts as a secure bridge between the Secret Manager Server and the Kubernetes cluster.
  - It's in charge of safely transmitting the secrets data to the ODM Pods within Kubernetes.

- **Kubernetes**:  It's the container orchestration system where the ODM application is deployed.

- **ODM Pods**:
  - Detailed within the Kubernetes rectangle, showcasing the components that make up the ODM Pods:

    - **Volume**:
      - Represented by the cylinder within the ODM Pods.
      - This is where the secrets data is stored after retrieval.

    - **ODM Containers**:
      - The main containers running the ODM application.
      - They utilize the secrets data stored in the volume for secure operations and configuration.

The diagram visually represents the secure flow of secrets data from the central manager to the ODM application in Kubernetes, facilitated by the Secret Store CSI Driver, ensuring best practices in secret management.

This documentation is based on an external HashiCorp Vault instance which hosts a few secrets needed by ODM's deployment. The differences with other Secrets stores will be highlighted.

## Prerequisites

HashiCorp Vault must be up and running. An [on-prem installation description](README-External_Vault.md) is provided (with hints about the Secrets Store CSI driver and the HashiCorp Vault provider installation) but of course you can use your own instance.

- [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/) already installed.
- [HashiCorp Vault provider driver](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-secret-store-driver) already installed
- [Helm](https://helm.sh/docs/intro/install/)
- Access to Operational Decision Manager on Container 9.5.0.0 images

> Note: The first and second steps are described in the [companion document](README-External_Vault.md) when you use OCP.

In this documentation ODM will be installed in the "odm" namespace.

## HashiCorp Vault setup

## Log into HashiCorp Vault server

Please refer to the [separate document](README-External_Vault.md) if you don't have such a secrets store already available.

Most following commands require you are connected already to your secrets store:

```bash
export VAULT_ADDR=http://<serverfqdn>:8200
vault login
```

## Define RBAC on HashiCorp Vault

Create the `odm-policy` policy that enables the read capability for secrets at path `<secretspath>/data/`:

```bash
vault policy write odm-policy - <<EOF
path "<secretspath>/data/*" {
  capabilities = ["read"]
}
EOF
```

Create an authentication role which assigns the policy created to above to some `odm-sa` service account in the namespace `odm` on your OCP cluster:

```bash
vault write auth/<clustername>/role/database \
    bound_service_account_names=odm-sa \
    bound_service_account_namespaces=odm \
    policies=odm-policy \
    ttl=24h
```

## ODM setup

### Prepare your environment for the ODM installation

A few mandatory items have to be created so that ODM can be deployed.

#### Namespace

Create an ODM project and the Service Account already described in the [companion document](README-External_Vault.md):

```bash
oc new-project odm
oc create serviceaccount odm-sa
```

#### Image pull secret

To get access to the ODM material, you need an IBM entitlement key to pull the images from the IBM Entitled Registry.

- Log in to [MyIBM Container Software Library](https://myibm.ibm.com/products-services/containerlibrary) with the IBMid and password that are associated with the entitled software.

- In the Container software library tile, verify your entitlement on the **View library** page, and then go to **Get entitlement key** to retrieve the key.

Create a pull secret by running a kubectl create secret command:

```bash
oc create secret docker-registry <REGISTRY_SECRET> \
    --docker-server=cp.icr.io \
    --docker-username=cp \
    --docker-password="<API_KEY_GENERATED>" \
    --docker-email=<USER_EMAIL>
```

Where:

- `<REGISTRY_SECRET>` is the secret name.
- `<API_KEY_GENERATED>` is the entitlement key from the previous step. Make sure you enclose the key in double-quotes.
- `<USER_EMAIL>` is the email address associated with your IBMid.

> NOTE:  The `cp.icr.io` value for the docker-server parameter is the only registry domain name that contains the images. You must set the docker-username to `cp` to use an entitlement key as docker-password.

Take note of the secret name so that you can set it for the *image.pullSecrets* parameter when you run a helm install command of your containers.  The *image.repository* parameter will later be set to `cp.icr.io/cp/cp4a/odm`.

***However, as the goal of this article is to eliminate the need for secrets, refer to the Kubernetes implementation to understand the alternative methods. For example, the OpenShift documentation on this topic can be found [here](https://docs.openshift.com/container-platform/4.14/openshift_images/managing_images/using-image-pull-secrets.html#images-update-global-pull-secret_using-image-pull-secrets)***

#### IBM Helm charts repository

Add the public IBM Helm charts repository to your environment:

```bash
helm repo add ibm-helm https://raw.githubusercontent.com/IBM/charts/master/repo/ibm-helm
helm repo update
```

Check that you can access ODM charts:

```bash
helm search repo ibm-odm-prod
NAME                    CHART VERSION   APP VERSION     DESCRIPTION
ibm-helm/ibm-odm-prod   25.0.0          9.5.0.0         IBM Operational Decision Manager
```

#### Data to be injected in the pods

To manage this process, the SecretProviderClass Custom Resource Definition (CRD) is utilized. Within this provider class, it's necessary to specify the address of the secure secret store and the locations of the secret keys.

As an example, we have populated some data. You will need to adjust it according to your needs.

First create the username and associated password used to connect to the internal database:

```bash
vault kv put <secretspath>/db-pass db-password="postgrespwd" db-user="postgresuser"
```

Please refer to the secrets store provider for the syntax.

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: odmdbsecret
spec:
  provider: vault
  parameters:
    vaultAddress: http://<vaultfqdn>:8200
    roleName: database
    objects: |
      - objectName: "db-password"
        secretPath: "<secretspath>/data/db-pass"
        secretKey: "db-password"
      - objectName: "db-user"
        secretPath: "<secretspath>/data/db-pass"
        secretKey: "db-user"
```

Save the content in a spc-odmdbsecret.yaml file and create the SecretProviderClass:

```bash
oc apply -f spc-odmdbsecret.yaml
```

> The exact syntax of the SPC depends on the Secrets store provider. The example given above corresponds to HashiCorp Vault, but the "parameters" syntax can differ greatly according to the provider. For instance Google Secret Manager relies on [other keys](https://github.com/GoogleCloudPlatform/secrets-store-csi-driver-provider-gcp/blob/main/examples/app-secrets.yaml.tmpl).

It replaces the Kubernetes Secret that would have been created with (don't do that here!):

```shell
kubectl create secret generic odmdbsecret --from-literal=db-user=myadmin@mypostgresqlserver \
                                          --from-literal=db-password='passw0rd!'
```

or:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: odmdbsecret
data:
  db-password: cGFzc3cwcmQh
  db-user: bXlhZG1pbkBteXBvc3RncmVzcWxzZXJ2ZXI=
```

Note the equivalence between the key data.db-user (for instance) in the Secret and the key spec.parameters.objects[].secretKey = "db-user" in the SecretProviderClass. It corresponds to the db-user key in the secret/db-pass you created previously with the `vault kv put` command.

(Optional) Generate a self-signed certificate.

If you do not have a trusted certificate, you can use OpenSSL and other cryptography and certificate management libraries to generate a certificate file and a private key, to define the domain name, and to set the expiration date. The following command creates a self-signed certificate (.crt file) and a private key (.key file) that accept the domain name *mynicecompany.com*. The expiration is set to 1000 days:

```shell
openssl req -x509 -nodes -days 1000 -newkey rsa:2048 -keyout mynicecompany.key \
        -out mynicecompany.crt -subj "/CN=mynicecompany.com/OU=it/O=mynicecompany/L=Paris/C=FR" \
        -addext "subjectAltName = DNS:mynicecompany.com"
```

> [!NOTE]
> You can use -addext only with actual OpenSSL and from LibreSSL 3.1.0.

Upload your self-signed certificate to your Vault:

```shell
vault kv put <secretspath>/mynicecompany.com tls.crt=@mynicecompany.crt tls.key=@mynicecompany.key
```

and create the corresponding SPC:

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: mynicecompanytlssecret
spec:
  provider: vault
  parameters:
    vaultAddress: http://<vaultfqdn>:8200
    roleName: database
    objects: |
      - objectName: "tls.crt"
        secretPath: "<secretspath>/data/mynicecompany.com"
        secretKey: "tls.crt"
      - objectName: "tls.key"
        secretPath: "<secretspath>/data/mynicecompany.com"
        secretKey: "tls.key"
```

It replaces the K8s secret that would have been created with (again, don't do that here!):

```shell
kubectl create secret generic mynicecompanytlssecret --from-file=tls.crt=mynicecompany.crt --from-file=tls.key=mynicecompany.key
```

The certificate must be the same as the one you used to enable TLS connections in your ODM release. For more information, see [Server certificates](https://www.ibm.com/docs/en/odm/9.5.0?topic=servers-server-certificates).

We also would like to create a Basic Registry configuration to be used as authSecretRef (refer to both accompanying files group-security-configurations.xml and webSecurity.xml). It will allow some "mat" guy to connect to ODM components. First upload their contents to HashiCorp Vault:

```shell
vault kv put <secretspath>/authsecret group-security-configurations.xml=@group-security-configurations.xml webSecurity.xml=@webSecurity.xml
```

and then create and apply the corresponding SPC:

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: authsecret
spec:
  provider: vault
  parameters:
    vaultAddress: http://<vaultfqdn>:8200
    roleName: database
    objects: |
      - objectName: "group-security-configurations.xml"
        secretPath: "<secretspath>/data/authsecret"
        secretKey: "group-security-configurations.xml"
      - objectName: "webSecurity.xml"
        secretPath: "<secretspath>/data/authsecret"
        secretKey: "webSecurity.xml"
```

### ODM installation with Basic authentication (10 min)

1. Edit the values-default-vault.yaml and adjust the values.

2. Run Helm deployment with the CSI driver:

```bash
helm install odm-vault-spc ibm-helm/ibm-odm-prod -f values-default-vault.yaml
```
> **Note:**  
> This command installs the **latest available version** of the chart.  
> If you want to install a **specific version**, add the `--version` option:
>
> ```bash
> helm install odm-vault-spc ibm-helm/ibm-odm-prod --version <version> -f values-default-vault.yaml
> ```
>
> You can list all available versions using:
>
> ```bash
> helm search repo ibm-helm/ibm-odm-prod -l
> ```

After a few minutes, ODM should be up and running without using any secrets for installation.

> An example with more secrets hosted by an external Vault is described in our [Vault with initContainer contrib](../vault-initcontainer/README.md).

## Reference: Secrets that you can get from your secrets store with SPC

| Secret name |
| ----------- |
| customization.authSecretRef |
| customization.baiEmitterSecretRef |
| customization.monitorRef |
| customization.privateCertificateList |
| customization.securitySecretRef |
| customization.trustedCertificateList |
| customization.usageMeteringSecretRef |
| decisionCenter.monitorRef |
| decisionRunner.monitorRef |
| decisionServerConsole.monitorRef |
| decisionServerRuntime.monitorRef |
| externalCustomDatabase.datasourceRef |
| externalDatabase.decisionCenter.sslSecretRef |
| externalDatabase.decisionServer.secretCredentials |
| externalDatabase.decisionServer.sslSecretRef |
| externalDatabase.secretCredentials |
| externalDatabase.sslSecretRef |
| internalDatabase.secretCredentials |
| oidc.clientRef |
| service.ingress.tlsSecretRef |
