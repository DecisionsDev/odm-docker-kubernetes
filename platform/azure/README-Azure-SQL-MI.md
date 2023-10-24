# Deploying IBM Operational Decision Manager with Azure SQL Managed Instance

We successfully deployed ODM with an external Azure SQL Managed Instance (SQL MI), following these instructions.

Look for Azure SQL in all available services and create a SQL Managed Instances / Single instance:

![Single instance](images/sqlmi-select_offer.png)

Choose the Resource Group you want to deploy the SQL MI into, and also the Managed Instance name:

![Basics configuration](images/sqlmi-basics.png)

You should have a look at `Configure Managed Instance` and lower the number of CPUs used by the instance:

![Resources configuration](images/sqlmi-resources.png)
