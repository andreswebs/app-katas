resource "mongodbatlas_project" "this" {
  name   = var.project_name
  org_id = var.atlas_org_id
}

# mongodbatlas_advanced_cluster rather than mongodbatlas_flex_cluster: the same
# resource type covers Flex, tenant and dedicated, which is what makes the
# Flex-to-dedicated rehearsal in exercise 17 a `plan` rather than a rewrite.
#
# mongo_db_major_version is deliberately not set. Atlas pins Flex clusters to
# 8.0 and controls the upgrade; setting the attribute here invites a perpetual
# diff.
resource "mongodbatlas_advanced_cluster" "this" {
  project_id   = mongodbatlas_project.this.id
  name         = var.cluster_name
  cluster_type = "REPLICASET"

  replication_specs = [
    {
      region_configs = [
        {
          provider_name         = var.provider_name
          backing_provider_name = var.backing_provider_name
          region_name           = var.region_name
          priority              = 7
        }
      ]
    }
  ]

  termination_protection_enabled = false

  tags = {
    purpose    = "poc"
    disposable = "true"
  }
}

resource "random_password" "app" {
  length  = 32
  special = false
}

resource "random_password" "ops" {
  length  = 32
  special = false
}

# The least-privilege shape: readWrite on the application database only.
# Exercises 12, 13 and 15 ask what this user is refused.
resource "mongodbatlas_database_user" "app" {
  project_id         = mongodbatlas_project.this.id
  username           = var.app_username
  password           = random_password.app.result
  auth_database_name = "admin"

  roles {
    role_name     = "readWrite"
    database_name = var.database_name
  }
}

# The operations user. MongoDB documents that restoring into Atlas requires
# Atlas admin, because Atlas exposes no individual restore role or privilege
# action. Exercise 13 restores as each user and records which succeeded.
resource "mongodbatlas_database_user" "ops" {
  project_id         = mongodbatlas_project.this.id
  username           = var.ops_username
  password           = random_password.ops.result
  auth_database_name = "admin"

  roles {
    role_name     = "atlasAdmin"
    database_name = "admin"
  }
}

# Declared here rather than left to a click path, on purpose. The access list is
# exactly the thing that has to change in lockstep with a host move, and
# forgetting it presents as a total outage with a clean-looking application.
resource "mongodbatlas_project_ip_access_list" "operator" {
  project_id = mongodbatlas_project.this.id
  ip_address = var.operator_ip
  comment    = "operator"
}
