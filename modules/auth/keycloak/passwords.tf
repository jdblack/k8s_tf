
resource random_password keycloak_admin {
  length = 15
  special = true
  override_special = "_%@"
}

resource random_password database {
  length = 15
  special = true
  override_special = "_%@"
}

resource kubernetes_secret keycloak_secrets {
  metadata {
    name = var.credentials
    namespace = var.namespace
  }
  data = {
    "admin_password" = random_password.keycloak_admin.result
    "admin_user" = var.adminuser
    "postgres_password" = random_password.database.result
    "admin_url" = local.url
  }
}

