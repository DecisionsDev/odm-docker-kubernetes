# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## What this repo is

Pure documentation/configuration repository — no application source code, no build system, no package manager. All artifacts are Helm values files (`.yaml`), shell scripts, Kubernetes manifests, XML configuration templates, and Markdown READMEs. There is nothing to compile or unit-test locally.

## Helm chart source (external — not in this repo)

ODM is deployed via the **ibm-odm-prod** Helm chart published externally:
```bash
helm repo add ibmcharts https://raw.githubusercontent.com/IBM/charts/master/repo/ibm-helm
helm repo update
helm search repo ibm-odm-prod          # latest
helm search repo ibm-helm/ibm-odm-prod -l   # all versions
```
Current latest: chart `26.0.0`, appVersion `9.6.0.0`. Min Kubernetes: `>=1.28.0-0`.

A **dev/trial chart** (`ibm-odm-dev`) also exists at `repo/stable/` (pre-packaged `.tgz` files).

## Image registry

All ODM images live at `cp.icr.io/cp/cp4a/odm` (IBM Entitled Registry). Pull secret name is always `ibm-entitlement-key` (hardcoded across every platform values file).

```bash
kubectl create secret docker-registry ibm-entitlement-key \
  --docker-server=cp.icr.io --docker-username=cp --docker-password="<ENTITLEMENT_KEY>"
```

## Standard install pattern

```bash
helm install <release-name> ibmcharts/ibm-odm-prod -f <platform>/<values>.yaml
# Add --version <chart-version> to pin a version
```

## ODM pod topology (5 pods)

| Pod suffix | Role |
|---|---|
| `dbserver` | Internal PostgreSQL (dev/test only) |
| `odm-decisioncenter` | Decision Center (rule authoring UI) |
| `odm-decisionrunner` | Decision Runner (test UI) |
| `odm-decisionserverconsole` | RES Console (deployment UI) |
| `odm-decisionserverruntime` | Decision Server Runtime (execution) |

## Platform-specific values files

Each platform has its own values file; **do not mix them**:

| Platform | Values file(s) |
|---|---|
| Minikube | `platform/minikube/minikube-values.yaml` |
| EKS (ALB) | `platform/eks/eks-values.yaml` or `eks-rds-values.yaml` |
| AKS | `platform/azure/` |
| GKE | `platform/gcloud/` |
| ROKS/OCP | `platform/roks/roks-values.yaml` or `ocp-values.yaml` (root) |

## OpenShift vs vanilla Kubernetes difference

OCP/ROKS requires `customization.runAsUser: ''` and `internalDatabase.runAsUser: ''` (empty string, not omitted). Vanilla K8s does not need these.

OCP also needs `service.enableRoute: true` instead of an Ingress.

## Authentication template generation

Each OIDC provider has a `generateTemplate.sh` that does `sed` substitution on XML/properties files in `templates/` → `output/`. **Always run it from inside the provider's directory** (uses relative `./output` and `./templates` paths).

```bash
cd authentication/Keycloak
./generateTemplate.sh -i CLIENT_ID -x CLIENT_SECRET -n KEYCLOAK_SERVER_URL
```

## External database (non-internal)

To use an external PostgreSQL, set `externalDatabase.*` and omit `internalDatabase`. Credentials are passed via a named secret (e.g., `externalDatabase.secretCredentials: odm-db-secret`), not inline values.

## Secrets management (two patterns)

1. **Secrets Store CSI Driver** (`contrib/secrets-store/`): Uses `SecretProviderClass` with `type: spc` references in the values file.
2. **Vault InitContainer** (`contrib/vault-initcontainer/`): Uses `kustomization.yaml` overlay on top of the Helm release.

## CI (GitHub Actions — no local equivalent)

- **check-links.yml**: Runs `linkspector` on all Markdown. Config in `.linkspector.yml`. IBM docs URLs are rewritten to `ibmdocs-test.dcs.ibm.com` for testing.
- **detect-secrets.yml**: Runs IBM `detect-secrets` via Docker image `icr.io/git-defenders/detect-secrets:0.13.1.ibm.61.dss-redhat-ubi`.
- **Pre-commit hook**: Uses `ibm/detect-secrets@0.13.1+ibm.64.dss`. Run `pre-commit run detect-secrets` locally to preview scan.

## Markdown conventions

- Use `> [!NOTE]`, `> [!IMPORTANT]`, `> [!WARNING]` callout syntax (GitHub-flavored).
- Link targets inside README files use anchor format `#step-name` (lowercase, hyphenated).
- NGINX-based approaches are **deprecated** across all platforms; always recommend ALB/Gateway API.
