resource random_password password {
  length  = 16
  special = true
}

resource kubernetes_secret_v1 samba {
  metadata {
    name      = "${local.samba_name}-secret"
    namespace = kubernetes_namespace_v1.storage.metadata[0].name
  }

  data = {
    username = var.samba_user
    password = random_password.password.result
  }
}
