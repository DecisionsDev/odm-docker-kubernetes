
# Variables
##############################################################################
variable "icd_postgres_plan" {
  type        = string
  description = "The plan type of the Database instance"
  default     = "standard"
}

variable "icd_postgres_adminpassword" {
  type        = string
  description = "The admin user password for the instance"
  default     = "AdminPassw0rd01"
}

variable "icd_postgres_ram_allocation" {
  type        = number
  description = "RAM (GB/data member)"
  default     = 4096
}

variable "icd_postgres_disk_allocation" {
  type        = number
  description = "Disk Usage (GB/data member)"
  default     = 5120
}

variable "icd_postgres_core_allocation" {
  type        = number
  description = "Dedicated Cores (cores/data member)"
  default     = 2
}

variable "icd_postgres_db_version" {
  type        = string
  description = "The database version to provision if specified"
  default     = "16"
}

variable "icd_postgres_users" {
  default     = null
  type        = set(map(string))
  description = "Database Users. It is set of username and passwords"
}

variable "icd_postgres_service_endpoints" {
  default     = "public"
  type        = string
  description = "Types of the service endpoints. Possible values are 'public', 'private', 'public-and-private'."
}

##############################################################################
## ICD Postgres
##############################################################################
resource "ibm_database" "icd_postgres" {
  name              = format("%s-%s", local.basename, "postgres")
  service           = "databases-for-postgresql"
  plan              = var.icd_postgres_plan
  version           = var.icd_postgres_db_version
  service_endpoints = var.icd_postgres_service_endpoints
  location          = var.region
  resource_group_id = local.resource_group_id
  tags              = var.tags

  # DB Settings
  adminpassword = var.icd_postgres_adminpassword
  group {
    group_id = "member"
    host_flavor { id = "multitenant" }
    memory { allocation_mb = var.icd_postgres_ram_allocation }
    disk { allocation_mb = var.icd_postgres_disk_allocation }
    cpu { allocation_count = var.icd_postgres_core_allocation }
  }
}

## Service Credentials
##############################################################################
resource "ibm_resource_key" "db-svc-credentials" {
  name                 = format("%s-%s", local.basename, "postgres-key")
  resource_instance_id = ibm_database.icd_postgres.id
  role                 = "Viewer"
}

locals {
  endpoints = [
    {
      name        = "postgres",
      # crn         = ibm_database.icd_postgres.id
      db-name     = nonsensitive(ibm_resource_key.db-svc-credentials.credentials["connection.postgres.database"])
      db-host     = nonsensitive(ibm_resource_key.db-svc-credentials.credentials["connection.postgres.hosts.0.hostname"])
      db-port     = nonsensitive(ibm_resource_key.db-svc-credentials.credentials["connection.postgres.hosts.0.port"])
      db-user     = nonsensitive(ibm_resource_key.db-svc-credentials.credentials["connection.postgres.authentication.username"])
      db-password = nonsensitive(ibm_resource_key.db-svc-credentials.credentials["connection.postgres.authentication.password"])
    }
  ]
}

output "icd-postgres-credentials" {
  value = local.endpoints
}