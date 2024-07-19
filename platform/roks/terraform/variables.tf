##############################################################################
# Account Variables
##############################################################################

variable "ibmcloud_api_key" {
  description = "APIkey that's associated with the account to provision resources to"
  type        = string
  default     = ""
  sensitive   = true
}

variable "prefix" {
  type        = string
  default     = ""
  description = "A prefix for all resources to be created. If none provided a random prefix will be created"
}

resource "random_string" "random" {
  count = var.prefix == "" ? 1 : 0

  length  = 6
  special = false
}

locals {
  basename = lower(var.prefix == "" ? "odm-${random_string.random.0.result}" : var.prefix)
}

variable "region" {
  description = "IBM Cloud region where all resources will be provisioned (e.g. eu-de)"
  default     = "eu-de"
}

variable "tags" {
  description = "List of Tags"
  type        = list(string)
  default     = ["tf", "odm"]
}