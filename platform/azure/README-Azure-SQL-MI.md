# Deploying IBM Operational Decision Manager with Azure SQL Managed Instance

We successfully deployed ODM with an external Azure SQL Managed Instance (SQL MI), following these instructions.

Look for Azure SQL in all available services and create a SQL Managed Instances / Single instance:

![Single instance](images/sqlmi-select_offer.png)

Choose the Resource Group you want to deploy the SQL MI into, and also the Managed Instance name:

![Basics configuration](images/sqlmi-basics.png)

You should have a look at `Configure Managed Instance` and lower the number of CPUs used by the instance:

![Resources configuration](images/sqlmi-resources.png)

Back to basics, select `Use SQL authentication` as Authentication method and then fill in admin login and password values:

![Authentication](images/sqlmi-authentication.png)

In the Networking tab, enable `Public endpoint` and allow access from `Azure services`:

![Network access](images/sqlmi-network.png)

You can then review your configuration and create the Managed Instance. It can take up to six hours (but most of the time we manage to get it created in about one hour):

![Review](images/sqlmi-review.png)

When the SQL MI is up, you can create a database in it:

![New database](images/sqlmi-newdb.png)
