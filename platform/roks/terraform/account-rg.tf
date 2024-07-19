##############################################################################
# Create a resource group or reuse an existing one
##############################################################################

variable "existing_resource_group_name" {
  default     = ""
  description = "(Optional) Name of an existing resource group where to create resources"
}

resource "ibm_resource_group" "group" {
  count = var.existing_resource_group_name != "" ? 0 : 1
  name  = "${local.basename}-group"
  tags  = var.tags
}

data "ibm_resource_group" "group" {
  count = var.existing_resource_group_name != "" ? 1 : 0
  name  = var.existing_resource_group_name
}

locals {
  resource_group_id = var.existing_resource_group_name != "" ? data.ibm_resource_group.group.0.id : ibm_resource_group.group.0.id
}

# output "resource_group_name" {
#   value = ibm_resource_group.group.name
# }