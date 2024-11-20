##############################################################################
## Global Variables
##############################################################################

region = "eu-de" # eu-de for Frankfurt MZR
# existing_resource_group_name = ""

##############################################################################
## VPC
##############################################################################
vpc_address_prefix_management = "manual"
vpc_enable_public_gateway     = true


##############################################################################
## Cluster ROKS
##############################################################################
# Optional: Specify OpenShift version. If not included, 4.15 is used
openshift_version        = "4.16_openshift"
openshift_os             = "RHCOS"
openshift_machine_flavor = "bx2.4x16"

openshift_disable_public_service_endpoint = false
# By default, public outbound access is blocked in OpenShift 4.15
openshift_disable_outbound_traffic_protection = true

# Available values: MasterNodeReady, OneWorkerNodeReady, or IngressReady
openshift_wait_till          = "OneWorkerNodeReady"
openshift_update_all_workers = false


##############################################################################
## ICD Postgres
##############################################################################
# Available Plans: standard, enterprise
icd_postgres_plan = "standard"
# expected length in the range (10 - 32) - must not contain special characters
icd_postgres_adminpassword     = "Passw0rd01forODM"
icd_postgres_db_version        = "16"
icd_postgres_service_endpoints = "public"

# Minimum parameter for Standard Edition
icd_postgres_ram_allocation  = 4096
icd_postgres_disk_allocation = 5120
icd_postgres_core_allocation = 0

# icd_postgres_users = [{
#   name     = "user123"
#   password = "Password12forODM"
# }]
