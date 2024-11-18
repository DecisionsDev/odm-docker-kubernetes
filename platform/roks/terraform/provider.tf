##############################################################################
# IBM Cloud Provider
##############################################################################

terraform {
  required_version = ">=1.6"
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "1.71.2"
    }
}

provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.region
}