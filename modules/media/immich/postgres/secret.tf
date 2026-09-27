resource "random_password" "postgres" {
  length           = 32
  special          = true
  override_special = "_%@"
}

resource "kubernetes_secret_v1" "postgres" {
  metadata {
    name      = var.name
    namespace = var.namespace
  }

  data = {
    password = random_password.postgres.result
  }
}
