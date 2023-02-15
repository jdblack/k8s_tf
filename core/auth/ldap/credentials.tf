resource "random_password" "password" {
  length = 15
  special = true
  override_special = "_%@"
}


resource "kubernetes_secret" "ldap_admin" {
  metadata {
    name = "ldap-admin"
    namespace = var.namespace
  }
  data = {
    name = "admin"
    pass = random_password.password.result
    server = var.ldap_domain
  }
}

