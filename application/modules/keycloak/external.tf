provider "keycloak" {
    client_id     = "admin-cli"
    username      = data.kubernetes_secret.keycloak_secrets.data.admin-user
    password      = data.kubernetes_secret.keycloak_secrets.data.admin-password
    url           = data.kubernetes_secret.keycloak_secrets.data.site
}


data kubernetes_secret keycloak_secrets {
  metadata {
    name = var.credentials
    namespace = var.namespace
  }
}

