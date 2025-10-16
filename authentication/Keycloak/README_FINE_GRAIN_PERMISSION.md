# How to import Keycloak Groups and Users using SCIM

## Table of Contents
<!-- TOC depthfrom:1 depthto:6 withlinks:false updateonsave:false orderedlist:false -->
- [Introduction](#introduction)
- [Deploy on OpenShift a custom Keycloak service with a SCIM Server](#deploy-on-openshift-a-custom-keycloak-service-with-a-scim-server)
  - [Build the Keycloak docker image embedding the open source SCIM plug-in](#build-the-keycloak-docker-image-embedding-the-open-source-scim-plug-in)
  - [Push the image into the OpenShift Cluster](#push-the-image-into-the-openshift-cluster)
  - [Deploy Keycloak Service using the keycloak-scim image](#deploy-keycloak-service-using-the-keycloak-scim-image)
- [Configure an ODM Application with Keycloak dashboard](#configure-an-odm-application-with-keycloak-dashboard)
- [Deploy an Open LDAP Service](#deploy-an-open-ldap-service)
- [Add an LDAP User Federation to Keycloak](#add-an-ldap-user-federation-to-keycloak)
- [SCIM Configuration](#scim-configuration)
  - [Enable the SCIM Console Theme](#enable-the-scim-console-theme)
  - [Configure the odm client application authorization](#configure-the-odm-client-application-authorization)
  - [Check the SCIM Group and User endpoints](#check-the-scim-group-and-user-endpoints)
- [Deploy ODM on a container configured with Keycloak](#deploy-odm-on-a-container-configured-with-keycloak)
- [Manage Security on ODM Decision Service Project](#manage-security-on-odm-decision-service-project)
  - [Provide the relevant roles on groups](#provide-the-relevant-roles-on-groups)
  - [Load projects](#load-projects)
  - [Import Groups and Users](#import-groups-and-users)
  - [Set the project security](#set-the-project-security)
  - [Check the project security](#check-the-project-security)
- [Synchronize Decision Center when updating Keycloak](#synchronize-decision-center-when-updating-keycloak)

<!-- /TOC -->

# Introduction

ODM Decision Center allows to [manage users and groups from the Business console](https://www.ibm.com/docs/en/odm/9.5.0?topic=center-managing-users-groups-from-business-console) in order to set access security on specific projects.
Groups and Users can be imported using an LDAP connection or a SCIM connection (as Keycloak can feature a SCIM server).

Keycloak does not provide a SCIM server off the shelf, but this feature can be added using a plugin called *SCIM for Keycloak* which comes 
- either as an open-source contribution: see [https://github.com/Captain-P-Goldfish/scim-for-keycloak](https://github.com/Captain-P-Goldfish/scim-for-keycloak),
- or as a commercial product: see [https://scim-for-keycloak.de/](https://scim-for-keycloak.de) 

The open source version of the plugin is no longer updated, and the last version is for Keycloak **20.0.5**. In this tutorial, we use this version of Keycloak and the open source version of the plugin.

But alternatively you can register to https://scim-for-keycloak.de/ in order to get a free license valid for 14 days and download a more recent version of the plugin, and do the tutorial with a newer version of Keycloak. To do so, you only need to replace the value of the two `--build-arg` `KEYCLOAK_IMAGE` and `SCIM_JAR_FILE` in the `docker buildx build` command in [Build the Keycloak docker image embedding the open source SCIM plug-in](#build-the-keycloak-docker-image-embedding-the-open-source-scim-plug-in).

# Deploy on OpenShift a custom Keycloak service with a SCIM Server

## Build the Keycloak docker image embedding the open source SCIM plug-in

- Get the [SCIM for Keycloak scim-for-keycloak-kc-20-b1.jar file](https://github.com/Captain-P-Goldfish/scim-for-keycloak/releases/download/kc-20-b1/scim-for-keycloak-kc-20-b1.jar)
- Get the [Dockerfile](Dockerfile)
- Replace `${ARCH}` by the cpu architecture used in the cluster  (`amd64`,...) where Keycloak will be deployed in the command below and run the command in the directory that contains the JAR and Dockerfile. It will build an Docker image of Keycloak featuring the plugin JAR.

  ```shell
  docker buildx build . --platform=linux/${ARCH} --build-arg KEYCLOAK_IMAGE=quay.io/keycloak/keycloak:20.0.5 --build-arg SCIM_JAR_FILE=scim-for-keycloak-kc-20-b1.jar -t keycloak-scim:20.0.5
  ```

  > Note:
  > Tbe image built must be suitable to the architecture (amd64, ...) of the cluster where Keycloak is deployed, not the architecture of the machine where the build is performed.


## Push the image into the OpenShift Cluster

- Log on your OCP Cluster
- Expose the default Docker image registry externally:

  ```shell
  oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge
  ```

- Log into it:

  ```shell
  REGISTRY_HOST=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')
  docker login -u kubeadmin -p $(oc whoami -t) $REGISTRY_HOST
  ```

- Upload the image built into the cluster private registry:

  ```shell
  docker tag keycloak-scim:20.0.5 ${REGISTRY_HOST}/openshift/keycloak-scim:20.0.5
  docker push ${REGISTRY_HOST}/openshift/keycloak-scim:20.0.5
  ```

>Note: Should the error `failed to verify certificate: x509: certificate signed by unknown authority` occur, you need to add `${REGISTRY_HOST}` to your Docker insecure-registries list configuration.
>
> For instance, if you use podman, you have to create a myregistry.conf file in the /etc/containers/registries.conf.d folder (inside the virtual machine on Windows or Mac) with the content below:
> ```
> [[registry]]
> location = "${REGISTRY_HOST}"
> insecure = true
> ```

## Deploy Keycloak Service using the keycloak-scim image

- Run the command below:

  ```shell
   KEYCLOAK_PROJECT=$(oc project --short=true)

   oc process -f ./keycloak-scim.yaml \
    -p KEYCLOAK_IMAGE=image-registry.openshift-image-registry.svc:5000/openshift/keycloak-scim:20.0.5 \
    -p KEYCLOAK_ADMIN=admin \
    -p KEYCLOAK_ADMIN_PASSWORD=admin \
    -p NAMESPACE=${KEYCLOAK_PROJECT} \
  | oc create -f -
  ```
# Configure an ODM Application with Keycloak dashboard

Please follow the instructions in [Configure a Keycloak instance for ODM (Part 1)](README.md#configure-a-keycloak-instance-for-odm-part-1) to configure ODM roles in Keycloak.


# Deploy an Open LDAP Service

- Create a Service Account with the `anyuid` policy

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

- In the namespace where OpenLDAP has been deployed, run the command below (that returns the OpenLDAP Schema) :

  ```shell
  OPENLDAP_PROJECT=$(oc project --short=true)
  OPENLDAP_POD=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" --selector app=openldap-deploy)
  oc exec -ti ${OPENLDAP_POD} bash -- ldapsearch -x -Z -H ldap://ldap-service.${OPENLDAP_PROJECT}.svc:389  -D 'cn=admin,dc=example,dc=org' -b 'dc=example,dc=org' -w xNxICc74qG24x3GoW03n
  ```

Where:
  - OPENLDAP_POD is the name of the OpenLDAP pod
  - OPENLDAP_PROJECT is the name of the project in which the OpenLDAP pod has been deployed


# Add an LDAP User Federation to Keycloak

- Connect at the Keycloak Admin Dashboard using the `odm` realm with username/password `admin/admin`
- Select **Configure > User federation** and click **Add Provider > Add Ldap providers**

- Fill the **Add LDAP provider** dialog

   * General options
     * Console display name: `openldap`
     * Vendor: "Red Hat Directory Server"

   * Connection and authentication settings
     * Connection URL should be:  `ldap://ldap-service.<OPENLDAP_PROJECT>.svc:389` (where OPENLDAP_PROJECT is the project in which OpenLdap has been deployed)
     * Bind type: `simple`
     * Bind DN: `cn=admin,dc=example,dc=org`
     * Bind credentials: `xNxICc74qG24x3GoW03n`
- Click the **Test authentication** button => "Successfully connected to LDAP" message is displayed

   * LDAP searching and updating
     * Edit mode: `READ_ONLY`
     * Users DN: `dc=example,dc=org`
     * Username LDAP attribute: `uid`
     * RDN LDAP attribute: `uid`
     * UUID LDAP attribute: `uid`
     * User object classes: `inetOrgPerson, organizationalPerson`
     * User LDAP Filter:
     * Search scope: `Subtree`
     * Read timeout:
     * Pagination: `Off`

   * Synchronization settings
     * Import users: `On`
     * Sync Registrations: `On`
     * Batch size:
     * Periodic full sync: `Off`
     * Periodic changed users sync: `Off`

   * Kerberos integration
     * Allow Kerberos authentication: `Off`
     * Use Kerberos for password authentication: `Off`

   * Cache settings
     * Cache policy: `DEFAULT`

   * Advanced settings
     * Enable the LDAPv3 password modify extended operation: `Off`
     * Validate password policy: `Off`
     * Trust email: `On`

  - Click the **Save** button

  At this stage, all openldap users have been imported. To check that :
   - Click the **Users** tab
   - Type `*` in the Search user box and click the search icon button.

  You should see:

  ![OpenLdap Users Import](images/import_openldap_users.png)

  Now let us import groups.

  - In **User federation**, click **openldap**
  - Click the **Mappers** tab
  - Click **Add mapper**
     * Name: `groups`
     * Mapper type: `group-ldap-mapper`
     * LDAP Groups DN: `dc=example,dc=org`
     * Group Name LDAP Attribute: `cn`
     * Group Object Classes: `groupOfNames`
     * Preserve Group Inheritance: `Off`
     * Ignore Missing Groups: `Off`
     * Membership LDAP Attribute: `member`
     * Membership Attribute Type: `DN`
     * Membership User LDAP Attribute: `uid`
     * LDAP Filter:
     * Mode: `READ_ONLY`
     * User Groups Retrieve Strategy: `LOAD_GROUPS_BY_MEMBER_ATTRIBUTE`
     * Member-Of LDAP Attribute: `memberOf`
     * Mapped Group Attributes:
     * Drop non-existing groups during sync: `Off`
     * Groups Path: `/`

  - Click the **Save** button
  - Click **Action > Sync All users**

  Now you can check the openldap groups have been imported in the **Groups** tab. You should see :

  ![OpenLdap Groups Import](images/import_openldap_groups.png)

# SCIM Configuration


## Enable the SCIM Console Theme

  To access the SCIM Configuration User Interface, you have to change the Admin Console Theme.
  - Select the **master** realm
  - Select the **Realm settings** Menu
  - Select the **Themes** Tab
  - Select `scim` for the **Admin console theme**
  - Click the **Save** button => the "Realm successfully updated" message is displayed
  - Refresh the browser page => a "Page not found..." message is displayed
  - Click the **Go to the home page >>** hyperlink

  Now, the Admin console theme has changed and you should be able to access the SCIM Configuration tab :

  ![SCIM Configuration Tab](images/scim_configuration.png)

## Configure the odm client application authorization

  - Select the **Service Provider** tab

   - Select the **Settings** sub-tab
   - Set **SCIM enabled** to `ON`
   - Click the **Save** Button

   - Select the **Authorization** sub-tab
   - Select `odm` (clientId of the application) in the **Available Clients** list and click **Add selected >** to move it to the **Assigned Clients** list


  By default, the SCIM Groups and Users Endpoints require authentication.

  Now, let us configure these endpoints to authorize authenticated users that have the `rtsAdministrators` role. In the ODM client application, we will use the client_credentials flow using the `service-account-odm` service account having assigned the `rtsAdministrators` role. We just have to configure authorization for the "Get" endpoint as the ODM SCIM Import is a read only mode and doesn't need the other endpoints (Create, Update, Delete).

  ![SCIM Resources Tab](images/scim_resources.png)

  - Select the **Resource Type** tab
    - Click **Group** inside the table
    - Select the **Authorization** sub-tab
    - Expand **Common Roles**, select `rtsAdministrators` in the **Available Roles** list and click **Add selected >** to move it to the **Assigned Roles** list
    - Expand **Roles for Get**, select `rtsAdministrators` in the **Available Roles** list and click **Add selected >** to move it to the **Assigned Roles** list

  ![SCIM Group Authorization Tab](images/scim_groups_authorization.png)

 - Select the **Resource Type** tab again
   - Click **User** inside the table
   - Click the **Authorization** sub-tab
   - Expand **Common Roles**, select `rtsAdministrators` in the **Available Roles** list and click **Add selected >** to move it to the **Assigned Roles** list
   - Expand **Roles for Get**, select `rtsAdministrators` in the **Available Roles** list and click **Add selected >** to move it to the **Assigned Roles** list

  ![SCIM User Authorization Tab](images/scim_user_authorization.png)

## Check the SCIM Group and User endpoints

  Download the [keycloak-odm-script.zip](keycloak-odm-script.zip) file to your machine and unzip it in your working directory.
  This .zip file contains scripts and templates to verify and set up ODM.

  Request an access token using the Client-Credentials flow

  ```shell
  ./get-client-credential-token.sh -i $CLIENT_ID -x $CLIENT_SECRET -n $KEYCLOAK_SERVER_URL
  ```

  Call the SCIM Groups endpoint using this <ACCESS_TOKEN>

  ```shell
  curl -k -H "Authorization: Bearer $ACCESS_TOKEN" $KEYCLOAK_SERVER_URL/scim/v2/Groups
  ```

  The result should look like (after formatting (with jq for instance)):

  ```json
{
  "schemas": [
    "urn:ietf:params:scim:api:messages:2.0:ListResponse"
  ],
  "totalResults": 9,
  "itemsPerPage": 9,
  "startIndex": 1,
  "Resources": [
    {
      "schemas": [
        "urn:ietf:params:scim:schemas:core:2.0:Group"
      ],
      "id": "f716f3d4-81bf-4027-b7e2-4dff34a02201",
      "displayName": "ADPEnvironmentOwners",
      "members": [
        {
          "value": "84ca2822-4642-48af-ac3a-d52c9a76a381",
          "$ref": "https://keycloak-<KEYCLOAK_PROJECT>.<DOMAIN>/realms/odm/scim/v2/Users/84ca2822-4642-48af-ac3a-d52c9a76a381",
          "type": "User"
        },
        {
          "value": "4ee6972f-47c6-43bc-8648-1bd0abc087bc",
          "$ref": "https://keycloak-<KEYCLOAK_PROJECT>.<DOMAIN>/realms/odm/scim/v2/Users/4ee6972f-47c6-43bc-8648-1bd0abc087bc",
          "type": "User"
        },
        {
          "value": "2114f7df-af0e-4d5b-8084-d07247d00c35",
          "$ref": "https://keycloak-<KEYCLOAK_PROJECT>.<DOMAIN>/realms/odm/scim/v2/Users/2114f7df-af0e-4d5b-8084-d07247d00c35",
          "type": "User"
        }
      ],
      "meta": {
        "resourceType": "Group",
        "created": "2025-10-16T07:59:24.776Z",
        "lastModified": "2025-10-16T07:59:24.776Z",
        "location": "https://keycloak-<KEYCLOAK_PROJECT>.<DOMAIN>/realms/odm/scim/v2/Groups/f716f3d4-81bf-4027-b7e2-4dff34a02201"
      }
    },
    ...
  ```

  Call the SCIM Users endpoint using this <ACCESS_TOKEN>

  ```shell
  curl -k -H "Authorization: Bearer $ACCESS_TOKEN" $KEYCLOAK_SERVER_URL/scim/v2/Users
  ```

  The result should look like (after formatting (with jq for instance)):

  ```json
  {
  "schemas": [
    "urn:ietf:params:scim:api:messages:2.0:ListResponse"
  ],
  "totalResults": 17,
  "itemsPerPage": 17,
  "startIndex": 1,
  "Resources": [
    {
      "schemas": [
        "urn:ietf:params:scim:schemas:core:2.0:User"
      ],
      "id": "4b13b3e3-a715-44c7-a798-4c356e45613d",
      "userName": "caserviceuser",
      "name": {
        "familyName": "caServiceUser",
        "givenName": "caServiceUser"
      },
      "active": true,
      "meta": {
        "resourceType": "User",
        "created": "2025-10-16T07:29:20.572Z",
        "lastModified": "2025-10-16T07:29:20.572Z",
        "location": "https://keycloak-<KEYCLOAK_PROJECT>.<DOMAIN>/realms/odm/scim/v2/Users/4b13b3e3-a715-44c7-a798-4c356e45613d"
      }
    },
    ...
  ```

# Deploy ODM on a container configured with Keycloak

Follow - [Deploy ODM on a container configured with Keycloak (Part 2)](README.md#deploy-odm-on-a-container-configured-with-keycloak-part-2).

But replace the previous step "3. Create the Keycloak authentication secret" of the section [Create secrets to configure ODM with Keycloak](README.md#create-secrets-to-configure-odm-with-keycloak) by:

  ```
  kubectl create secret generic keycloak-auth-secret \
      --from-file=ldap-configurations.xml=./output/ldap-configurations.xml \
      --from-file=openIdParameters.properties=./output/openIdParameters.properties \
      --from-file=openIdWebSecurity.xml=./output/openIdWebSecurity.xml \
      --from-file=webSecurity.xml=./output/webSecurity.xml
  ```
Make sure that you finish [Complete post-deployment tasks](README.md#complete-post-deployment-tasks).

# Manage Security on ODM Decision Service Project 

ODM Decision Center allows to [manage users and groups from the Business console](https://www.ibm.com/docs/en/odm/9.5.0?topic=center-managing-users-groups-from-business-console) in order to set access security on specific projects.
Now, we will manage the following scenario. We will load the "Loan Validation Service" and "Miniloan Service" projects that are available at the getting started repository.
We will only provide access to the "Loan Validation Service" project for users belonging to the `TaskAuditors` group.
We will only provide access to the "Miniloan Service" project for users belonging to the `TaskUsers` group.

## Provide the relevant roles on groups

The first step is to declare the groups of users that will be Decision Center Administrators, and therefore have access to the Business Console Administration Tab.

  - In Keycloak admin console, select the **odm** realm
  - Select the **Manage > Groups** Tab
  - Double-click `TaskAdmins`
  - Select the **Role Mappings** Tab
  - Select all `rts***` roles in the **Available Roles** list and click **Add selected >** to move them to the **Assigned Roles** list

  ![Assign Admin Roles](images/assign_rtsadministrators_role.png)

Let us also assign the `rtsUsers` role to the `TaskAuditors` and `TaskUsers` groups. If you do not do this, users are not authorized to login into the Business Console.

  - Select the **Manage > Groups** Tab
  - Double-click on `TaskAuditors`
  - Select the **Role Mappings** Tab
  - Select the `rtsUsers` role in the **Available Roles** list and click **Add selected >** to move it to the **Assigned Roles** list
  - Repeat the same for the `TaskUsers` group

  ![Assign User Roles](images/assign_rtsusers_role.png)

## Load projects

  For the next steps, the users password can be found in the `ldap_user.ldif` file of the `openldap-customldif` secret, by running the commmand:
  ```
  oc get secret openldap-customldif -o jsonpath={.data."ldap_user\.ldif"} | base64 -d
  ```

  - Log in to the ODM Decision Center Business Console as the `cp4admin` user
  - Select the **LIBRARY** tab
  - Import the [Loan Validation Service](https://github.com/DecisionsDev/odm-for-container-getting-started/blob/master/Loan%20Validation%20Service.zip) and [Miniloan Service](https://github.com/DecisionsDev/odm-for-container-getting-started/blob/master/Miniloan%20Service.zip) projects if they are not already there.

  ![Load Projects](images/load_projects.png)

## Import Groups and Users

  - Select the **ADMINISTRATION** tab
  - Select the **Connection Settings** sub-tab
  - Check the KEYCLOAK_SCIM connection status is green
  - Select the **Groups** sub-tab
  - Click the **Import Groups from directories** icon button (arrow)
  - Select the `TaskAuditors` and `TaskUsers` groups
  - Click on the **Import groups and users** button

  ![DC Import Groups and Users](images/dc_import_groups_users.png)

## Set the project security

  - Select the **Project Security** sub-tab
  - Click on the pen icon next to the "Loan Validation Service" project (the text **Edit decision service security** gets displayed when hovering the mouse pointer over the icon)
  - Below the Security section, select **Enforce Security**
  - Below the Groups section, select the `TaskAuditors` group
  - Click the **Done** button

  ![Set Loan Validation Service Security](images/set_loan_validation_service_security.png)

  - Click the the pen icon next to the "Miniloan Service" project (the text **Edit decision service security** gets displayed when hovering the mouse pointer over the icon)
  - Below the Security section, select **Enforce Security**
  - Below the Groups section, select the `TaskUsers` group
  - Click the **Done** button

  ![Security Results](images/security_results.png)

## Check the project security

  - Click on top right **cp4admin** user
  - Click the **Log out** link
  - Click the Keycloak Logout button

  - Log in as `user1`. Check that the **ADMINISTRATION** tab is not available
  - Click on **LIBRARY** tab, only the "Miniloan Service" project must be available
  - Click on top-right `user1` link
  - Select "Profile" link
  - The `user1` User Profile is showing the `TaskUsers` group

  ![User1 Check](images/user1_check.png)

  - Log in as `user6`. Check that the **ADMINISTRATION** tab is not available
  - Click on **LIBRARY** tab, only the "Loan Validation Service" project must be available
  - Click on top-right `user6` link
  - Select "Profile" link
  - The `user6` User Profile is showing the `TaskAuditors` group

  ![User6 Check](images/user6_check.png)

# Synchronize Decision Center when updating Keycloak

  During the life of a project, the following can happen :
  - a user moves from a group to an other,
  - a user leaves a group,
  - a new user joins a group, ...

  All these changes are performed using the Keycloak dashboard and then reflected inside Decision Center, either manually using the Decision Center Synchronize button or using the automatic synchronization (scheduled every 2 hours by default).

  You can read more about configuring the automatic synchronization in the documentation page [Importing users and groups from LDAP directories](https://www.ibm.com/docs/en/odm/9.5.0?topic=ldap-importing-users-groups-from-directories).
