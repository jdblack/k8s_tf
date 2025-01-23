
resource "kubernetes_secret" "admin_auth" {
  type = "Opaque"
  metadata {
    namespace = var.namespace
    name = var.auth_secret
  }

  data = {
    username = "admin"
    password = random_password.admin_password.result 
    url = local.url
    fqdn = local.url
  }

}

resource random_password admin_password {
  length = 15
  special = true
  override_special = "_%@"
}

