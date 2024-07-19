##############################################################################
# IBM Cloud Provider
##############################################################################

terraform {
  # required_version = ">=1.5"
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "1.67.1"
    }
  }
}

provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.region
}