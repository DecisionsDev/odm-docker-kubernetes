# Provision an ODM landing zone on IBM CLoud

> Estimated duration: 60 mins

These Terraform scripts will provision the following Cloud Services in IBM Cloud:

* a Resource Group to host resources
* a VPC with 3 subnets across a MZR (Multi Zone Region)
* a managed OpenShift cluster (ROKS)
* a managed Postgres Database

You can then ssh into the newly created VSI.

| Terraform | Estimation Duration |
| --------- | --------- |
| Apply     | ~60 mins |
| Destroy   | ~5-10 mins |

## Before you begin

This lab requires the following command lines:

* [IBM Cloud CLI](https://github.com/IBM-Cloud/ibm-cloud-cli-release/releases)
* [Terraform CLI](https://developer.hashicorp.com/terraform/downloads)
* [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
* [jq CLI JSON processor](https://jqlang.github.io/jq/download/)

> Unless you are Administrator of the Cloud Account, you need permissions to be able to provision VPC Resources. Ask the Administrator run the Terraform in `iam` folder.

## Provisioning Steps

1. Clone this repository

    ```sh
    git clone https://github.com/lionelmace/learn-ibm-terraform
    ```

1. Login to IBM Cloud

    ```sh
    ibmcloud login
    ```

1. Create and store the value of an API KEY as environment variable

    ```sh
    export IBMCLOUD_API_KEY=$(ibmcloud iam api-key-create my-api-key --output json | jq -r .apikey)
    ```

    > If the variable "ibmcloud_api_key" is set in your provider,
    > you can initialize it using the following command
    > export TF_VAR_ibmcloud_api_key="Your IBM Cloud API Key"

1. Terraform must initialize the provider before it can be used.

    ```sh
    terraform init
    ```

1. Review the plan

    ```sh
    terraform plan
    ```

1. Start provisioning.

   > Estimated duration: 45-60 mins

    ```sh
    terraform apply --var-file="odm.auto.tfvars"
    ```

## Destroy Resources

1. Clean up the resources to avoid cost

    ```sh
    terraform destroy
    ```
