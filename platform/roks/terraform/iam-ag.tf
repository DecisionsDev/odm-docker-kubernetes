## IAM
##############################################################################

# Create Access Group
resource "ibm_iam_access_group" "accgrp" {
  name = format("%s-%s", local.basename, "ag")
  tags = var.tags
}

# Visibility on the Resource Group
resource "ibm_iam_access_group_policy" "iam-rg-viewer" {
  access_group_id = ibm_iam_access_group.accgrp.id
  roles           = ["Viewer"]
  resources {
    resource_type = "resource-group"
    resource      = local.resource_group_id
  }
}

# Create a policy to all Kubernetes/OpenShift clusters within the Resource Group
resource "ibm_iam_access_group_policy" "policy-k8s" {
  access_group_id = ibm_iam_access_group.accgrp.id
  roles           = ["Manager", "Writer", "Editor", "Operator", "Viewer", "Administrator"]

  resources {
    service           = "containers-kubernetes"
    resource_group_id = local.resource_group_id
  }
}

# Assign Administrator platform access role to enable the creation of API Key
# Pre-Req to provision IKS/ROKS clusters within a Resource Group
resource "ibm_iam_access_group_policy" "policy-k8s-identity-administrator" {
  access_group_id = ibm_iam_access_group.accgrp.id
  roles           = ["Administrator", "User API key creator", "Service ID creator"]

  resources {
    service = "iam-identity"
  }
}

# Doc at https://cloud.ibm.com/docs/cloud-databases?topic=cloud-databases-iam
resource "ibm_iam_access_group_policy" "iam-postgres" {
  access_group_id = ibm_iam_access_group.accgrp.id
  roles           = ["Editor"]

  resources {
    service           = "databases-for-postgresql"
    resource_group_id = local.resource_group_id
  }
}