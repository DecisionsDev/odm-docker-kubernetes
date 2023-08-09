# How to import Keycloak Groups and Users using SCIM

# Introduction

ODM Decision Center allows to [manage users and groups from the Business console](https://www.ibm.com/docs/en/odm/8.11.1?topic=center-managing-users-groups-from-business-console) in order to set access security on specific projects. 
The Groups and Users import can be done using an LDAP connection.
But, if the openId server also provides a SCIM server, then it can also be managed using a SCIM connection.

Keycloak server doesn't provide a SCIM server by default. But, it's possible to manage it using the following opensource contribution [https://github.com/Captain-P-Goldfish/scim-for-keycloak](https://github.com/Captain-P-Goldfish/scim-for-keycloak).
As the project [https://scim-for-keycloak.de/](https://scim-for-keycloak.de) will become Enterprise ready soon, we realized this tutorial using the last available open source version : kc-20-b1 for Keycloak 20.0.5.

## Build the Keycloak docker image embbeding the open source SCIM plug-in

- Get the [SCIM for Keycloak scim-for-keycloak-kc-20-b1.jar file](https://github.com/Captain-P-Goldfish/scim-for-keycloak/releases/download/kc-20-b1/scim-for-keycloak-kc-20-b1.jar)
- Get the [Dockerfile](Dockerfile)
- Build the image locally:

```shell
   docker build . --build-arg KEYCLOAK_IMAGE=quay.io/keycloak/keycloak:20.0.5 --build-arg SCIM_JAR_FILE=scim-for-keycloak-kc-20-b1.jar -t keycloak-scim:latest
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
## Configure an ODM Application with Keycloak dashboard

## Deploy an Open LDAP Service

- Create a Service Account with the anyuid policy

```shell
oc apply -f ./openldap/service-account-for-anyuid.yaml
oc adm policy add-scc-to-user anyuid -z openldap-anyuid
```

- Install the OpenLDAP Service

```shell
oc apply -f ./openldap/ldap-custom-ssl-secret.yaml
oc apply -f ./openldap/openldap-env.yaml
oc apply -f ./openldap/openldap-secret.yaml
oc apply -f ./openldap/openldap-customldif.yaml
oc apply -f ./openldap/openldap-deploy.yaml
oc apply -f ./openldap/ldap-service.yaml

```

- Check the OpenLDAP Service

The following command should return the OpenLDAP Schema :

    ```shell
    oc exec -ti <OPENLDAP_POD> bash -- ldapsearch -x -Z -H ldap://ldap-service.<PROJECT>.svc:389  -D 'cn=admin,dc=example,dc=org' -b 'dc=example,dc=org' -w xNxICc74qG24x3GoW03n
    ```

    Where:

    - OPENLDAP_POD is the name of the OpenLDAP pod
    - PROJECT is the name of the current project


## Add an LDAP User Federation to Keycloak

- Connect at the Keycloak Admin Dashboard using the odm realm with login/pass admin/admin
- Select "User federation" and click Add Provider > LDAP

- Fill "Add LDAP provider" dialog

   * General options
     * Console display name: openldap
     * Vendor: "Red Hat Directory Server"
  
   * Connection and authentication settings
     * Connection URL: ldap://ldap-service.<PROJECT>.svc:389

  Click on the "Test connection" button => "Successfully connected to LDAP" message is displayed

     * Bind type: simple
     * Bind DN: cn=admin,dc=example,dc=org
     * Bind credentials: xNxICc74qG24x3GoW03n

  Click on the "Test authentication" button => "Successfully connected to LDAP" message is displayed

   * LDAP searching and updating
     * Edit mode: READ_ONLY
     * Users DN: dc=example,dc=org
     * Username LDAP attribute: uid
     * RDN LDAP attribute: uid
     * UUID LDAP attribute: uid
     * User object classes: inetOrgPerson, organizationalPerson
     * User LDAP Filter:
     * Search scope: Subtree
     * Read timeout:
     * Pagination: Off

   * Synchronization settings
     * Import users: On
     * Sync Registrations: On
     * Batch size:
     * Periodic full sync: Off
     * Periodic changed users sync: Off

   * Kerberos integration
     * Allow Kerberos authentication: Off
     * Use Kerberos for password authentication: Off

   * Cache settings
     * Cache policy: DEFAULT

   * Advanced settings
     * Enable the LDAPv3 password modify extended operation: Off
     * Validate password policy: Off
     * Trust email: On

  - Click on the "Save" button

  At this step, all openldap users have been imported. You can check it by clicking on the "Users" tab, put "*" in the Search user box and click on the search button.
  You should see:

  ![OpenLdap Users Import](/images/Keycloak/import_openldap_users.png)

  Now, we will import groups.

  - Edit the "openldap" User federation
  - Click on the "Mappers" tab
  - Click "Add mapper"
     * Name: groups
     * Mapper type: group-ldap-mapper
     * LDAP Groups DN: dc=example,dc=org
     * Group Name LDAP Attribute: cn
     * Grouyp Object Classes: groupOfNames
     * Preserve Group Inheritance: Off
     * Ignore Missing Groups: Off
     * Membership LDAP Attribute: member
     * Membership Attribute Type: DN
     * Membership User LDAP Attribute: uid
     * LDAP Filter:
     * Mode: READ_ONLY
     * User Groups Retrieve Strategy: LOAD_GROUPS_BY_MEMBER_ATTRIBUTE
     * Member-Of LDAP Attribute: memberOf
     * Mapped Group Attributes:
     * Drop non-existing groups during sync: Off
     * Groups Path: /

  - Click the "Save" button
  - Click on Action>Sync All users

  Now you can check the openldap groups have been imported using the Groups tab. You shoud see :

  ![OpenLdap Groups Import](/images/Keycloak/import_openldap_groups.png)

## SCIM Configuration


### Enable the SCIM ConsoleTheme

  To access the SCIM Configuration User Interface, you have to change the Admin Console Theme.
  - Select the "Realm settings" Tab
  - Select "scim" for the "Admin console theme"
  - Click the "Save" button => the "Realm sucessfully updated" message is displayed
  - Refresh the browser page => a "Page not found..." message is displayed
  - Click on the "Go to the home page >>" hyperlink

  Now, the Admin console theme has changed and you should be able to access the SCIM Configuration tab :

  ![SCIM Configuration Tab](/images/Keycloak/scim_configuration.png)

### Configure the odm client application authorization

  - Select the "Service Provider" tab

   - Select "Settings"
   - Set "SCIM enabled" to "ON"
   - Click on the "Save" Button

   - Select "Authorization"
   - Select"odm" (clientId of the application) in the "Available Clients" list and click on "Add selected" to move it to the "Assigned Clients" list


  By default, the SCIM Groups and Users Endpoints recquires authentication. 

  ![SCIM Resources Tab](/images/Keycloak/scim_resources.png)

  Now, we will configure these endpoints to authorize authenticated users that have the rtsAdministrators role. In the ODM client application, we will use the client_credentials flow using the "service-account-odm" service account having assigned the rtsAdministrators role. We just have to configure authorization for the "Get" endpoint as the ODM SCIM Import is a read only mode and doesn't need the other endpoints (Create, Update, Delete) 

  - Select the "Resource Type" tab
   
   - Click on "Group" inside the table
   - Click on the "Authorization" tab
   - Expand "Common Roles", select "rtsAdministrators" in the "Available Roles" and click on "Add selected" to move it to the "Assigned Roles" list
   - Expand "Roles for Get", select "rtsAdministrators" in the "Available Roles" and click on "Add selected" to move it to the "Assigned Roles" list

  ![SCIM Group Authorization Tab](/images/Keycloak/scim_groups_authorization.png)

   - Click on "User" inside the table
   - Click on the "Authorization" tab
   - Expand "Common Roles", select "rtsAdministrators" in the "Available Roles" and click on "Add selected" to move it to the "Assigned Roles" list
   - Expand "Roles for Get", select "rtsAdministrators" in the "Available Roles" and click on "Add selected" to move it to the "Assigned Roles" list

  ![SCIM User Authorization Tab](/images/Keycloak/scim_user_authorization.png)

 
     
