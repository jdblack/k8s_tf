
data kubernetes_secret ca_cert {
  metadata {
    name      = var.ssl_ca
    namespace = var.ssl_ca_namespace
  }
}

resource kubernetes_secret ca_cert {
  metadata {
    name = local.ca_secret_name
    namespace = var.namespace
  }
  data = {
    "ca.crt"= data.kubernetes_secret.ca_cert.data["tls.crt"]
  }
}


