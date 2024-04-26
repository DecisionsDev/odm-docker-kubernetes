# Deploying IBM Operational Decision Manager with Azure SQL Managed Instance

This page provides instructions on setting up IBM® Operational Decision Manager (ODM) with Azure SQL Managed Instance (MI).

Search for 'Azure SQL' among the available services and create a SQL Managed Instance or a Single instance:

![Single instance](images/sqlmi-select_offer.png)

Choose the desired Resource Group for deploying the SQL Managed Instance and specify the Managed Instance name:

![Basics configuration](images/sqlmi-basics.png)

Click the link 'Configure Managed Instance' and reduce the number of CPUs allocated to the instance:

![Resources configuration](images/sqlmi-resources.png)

Back to basics, select `Use SQL authentication` as Authentication method and then fill in admin login and password values:

![Authentication](images/sqlmi-authentication.png)

In the Networking tab, enable `Public endpoint` and allow access from `Azure services`:
> NOTE: It is not recommended to use a public IP. In a production environment, you should use a private IP.

![Network access](images/sqlmi-network.png)

You can now review your configuration and proceed to create the Managed Instance. While it can take up to six hours, in most cases, it is created in approximately one hour:

![Review](images/sqlmi-review.png)

Once the SQL Managed Instance is operational, you have the ability to establish a database within it:

![New database](images/sqlmi-newdb.png)

Later you'll need the FQDN for your SQL MI; it can be found as `Host` in the instance Overview:

![SQL MI Overview](images/sqlmi-overview.png)

The port to use should always be 3342 but you can verify it in the public JDBC connection string from your SQL Managed Instance:

![JDBC string](images/sqlmi-jdbcstring.png)

Proceed as standard installation and create a DB authentication secret:

```bash
kubectl create secret generic <odmdbsecret> --from-literal=db-user=<sqlmiadmin> \
                                            --from-literal=db-password='<password>'
```

> [!WARNING]
> db-user must not contain the `@<managedinstancename>` part!

Then you can deploy ODM with:

```bash
helm install <release> ibmcharts/ibm-odm-prod --version 24.0.0 \
        --set image.repository=cp.icr.io/cp/cp4a/odm --set image.pullSecrets=<registrysecret> \
        --set image.arch=amd64 --set image.tag=${ODM_VERSION:-9.0.0} --set service.type=LoadBalancer \
        --set externalDatabase.type=sqlserver \
        --set externalDatabase.serverName=<sqlminame>.public.<dns_zone_identifier>.database.windows.net \
        --set externalDatabase.databaseName=odmdb \
        --set externalDatabase.port=3342 \
        --set externalDatabase.secretCredentials=<odmdbsecret> \
        --set customization.securitySecretRef=<mynicecompanytlssecret> \
        --set license=true --set usersPassword=<password>
```

You can find the fully qualified name of the Azure SQL managed instance in the Settings under 'Connection Strings' as explained in [Azure SQL documentation](https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/public-endpoint-configure?view=azuresql&tabs=azure-portal).

Other deployment options (especially using NGINX) and IBM License Service usage are explained in the main [README](README.md).

## Troubleshooting

If your ODM instances are not running properly, refer to [our dedicated troubleshooting page](https://ibmdocs-test.dcs.ibm.com/docs/en/odm/9.0.0?topic=900-troubleshooting-support).

## Getting Started with IBM Operational Decision Manager for Containers

Get hands-on experience with IBM Operational Decision Manager in a container environment by following this [Getting started tutorial](https://github.com/DecisionsDev/odm-for-container-getting-started/blob/master/README.md).

# License

[Apache 2.0](/LICENSE)
