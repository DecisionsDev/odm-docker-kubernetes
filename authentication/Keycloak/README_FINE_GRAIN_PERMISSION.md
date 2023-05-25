# How to import Keycloak Groups and Users using SCIM

# Introduction

ODM Decision Center allows to [manage users and groups from the Business console](https://www.ibm.com/docs/en/odm/8.11.1?topic=center-managing-users-groups-from-business-console) in order to set access security on specific projects. 
The Groups and Users import can be done using an LDAP connection.
But, if the openId server also provides a SCIM server, then it can also be managed using a SCIM connection.

Keycloak server doesn't provide a SCIM server by default. But, it's possible to manage it using the following opensource contribution [https://github.com/Captain-P-Goldfish/scim-for-keycloak](https://github.com/Captain-P-Goldfish/scim-for-keycloak).
As the project [https://scim-for-keycloak.de/](https://scim-for-keycloak.de) will become Enterprise ready soon, we realized this tutorial using the last available open source version : kc-20-b1 for Keycloak 20.0.5.

## Build the Keycloak docker image embbeding the open source SCIM plug-in

- Get the [SCIM for Keycloak scim-for-keycloak-kc-20-b1.jar file](https://github.com/Captain-P-Goldfish/scim-for-keycloak/releases/download/kc-20-b1/scim-for-keycloak-kc-20-b1.jar)
- Get the [Dockerfile]()
- Build the image locally:

```shell
   docker buildx build . --build-arg KEYCLOAK_IMAGE=quay.io/keycloak/keycloak:20.0.5 --platform linux/amd64 -t keycloak-scim:latest
```

## Push the image on the OpenShift Cluster

- Expose the Docker image registry:

```shell
   oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge
```

- Log into it:

```shell
   REGISTRY_HOST=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')
   docker login -u kubeadmin -p $(oc whoami -t) $REGISTRY_HOST
```

- Upload the keycloak-scim:latest on the wanted <my-keycloak-project>:

```shell
   docker tag keycloak-scim:latest $REGISTRY_HOST/<my-keycloak-project>/keycloak-scim:latest
   docker push $REGISTRY_HOST/<my-keycloak-project>/keycloak-scim:latest
```

Note: To avoid an error on the image push, perhaps you will have to add $REGITRY_HOST to your Docker insecure-registries list configuration.

## Deploy Keycloak Service using the keycloak-scim image

- Get the [keycloak.yaml](https://raw.githubusercontent.com/keycloak/keycloak-quickstarts/latest/openshift-examples/keycloak.yaml) file
- Replace the provided image: input using default-route-openshift-image-registry.apps.mat-test-tuto.cp.fyre.ibm.com/keycloak2/keycloak-scim:latest

```shell
   ...
      spec:
          containers:
            - env:
                - name: KEYCLOAK_ADMIN
                  value: '${KEYCLOAK_ADMIN}'
                - name: KEYCLOAK_ADMIN_PASSWORD
                  value: '${KEYCLOAK_ADMIN_PASSWORD}'
                - name: KC_PROXY
                  value: 'edge'
              image: image-registry.openshift-image-registry.svc:5000/<my-keycloak-project>/keycloak-scim:latest
   ...
```

- Deploy keycloak:

```shell
   oc process -f ./keycloak.yaml \
    -p KEYCLOAK_ADMIN=admin \
    -p KEYCLOAK_ADMIN_PASSWORD=admin \
    -p NAMESPACE=<my-keycloak-project> \
| oc create -f -
```

