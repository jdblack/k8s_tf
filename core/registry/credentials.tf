resource "random_password" "password" {
  length = 15 
  special = true
  override_special = "_%@"
}


resource "kubernetes_secret" "reg_secret" {
  metadata {
    name = var.secret_name
    namespace = var.namespace
  }
  data = {
    name = var.docker_user
    pass = random_password.password.result
    server = local.url
  }
}

