# Scope the Decision Server Console to a dedicated node

Use `kustomize` to scope the Decision Server Console to a dedicated node defined by a specific label.

## Prerequisites

- [`kustomize`](https://kubectl.docs.kubernetes.io/installation/kustomize/) 3.5+ installed in your PATH
- Helm 3.1
- In a running Kubernetes cluster with an annotated node. You can add a label to a node with the following command:
  ```
  kubectl label nodes <your-node-name> <your-label>=<value>
  ```
  > Note: Only the label key existence is required for the node to be assigned to the `odm-decisionserverconsole` pod.

  Refer to the [kubernetes documentation](https://kubernetes.io/docs/tasks/configure-pod-container/assign-pods-nodes/#add-a-label-to-a-node) for more information.

## Installation

1. Define the label of the dedicated node

  ```
  export node_label=<your-label>
  ```

2. Modify the `kustomization.yaml` file

  ```
  $ cd kustomize
  $ sed -i "s/<customization.dedicatedNodeLabel>/${node_label}/g" kustomization.yaml
  ```

3. Install ODM

  ```
  helm install test-instance path-to-chart/ibm-odm-prod --post-renderer ./kustomize
  ```

4. Verify that the `odm-decisionserverconsole` pod is running on the chosen node

  ```
  oc get pods --output=wide
  ```
