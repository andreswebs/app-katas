output "cluster" {
  value = {
    name         = mongodbatlas_advanced_cluster.this.name
    project_id   = mongodbatlas_project.this.id
    cluster_id   = mongodbatlas_advanced_cluster.this.cluster_id
    state        = mongodbatlas_advanced_cluster.this.state_name
    version      = mongodbatlas_advanced_cluster.this.mongo_db_version
    standard_srv = mongodbatlas_advanced_cluster.this.connection_strings.standard_srv
  }
}

output "app_uri" {
  description = <<-EOT
    The application user's connection string, built correctly: mongodb+srv,
    TLS on by default, database name explicit. Do not carry a tls=false left
    over from a local-development template into this string; exercise 11 does
    that once, deliberately, to record the failure.
  EOT
  sensitive   = true
  value = format(
    "%s/%s?retryWrites=true&w=majority",
    replace(
      mongodbatlas_advanced_cluster.this.connection_strings.standard_srv,
      "mongodb+srv://",
      format(
        "mongodb+srv://%s:%s@",
        mongodbatlas_database_user.app.username,
        random_password.app.result,
      ),
    ),
    var.database_name,
  )
}

output "ops_uri" {
  description = "The atlasAdmin user's connection string, for the exercise 13 comparison."
  sensitive   = true
  value = format(
    "%s/%s?retryWrites=true&w=majority",
    replace(
      mongodbatlas_advanced_cluster.this.connection_strings.standard_srv,
      "mongodb+srv://",
      format(
        "mongodb+srv://%s:%s@",
        mongodbatlas_database_user.ops.username,
        random_password.ops.result,
      ),
    ),
    var.database_name,
  )
}
