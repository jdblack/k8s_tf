
data kubernetes_secret ca_cert {
  metadata {
    name      = var.ssl_ca
    namespace = var.ssl_ca_namespace
  }
}

resource kubernetes_config_map argocd_ca_cert {
  metadata {
    name = "${var.ssl_ca}.crt"
    namespace = var.namespace
  }
  data = {
    "ca.crt"= data.kubernetes_secret.ca_cert.data["tls.crt"]
  }
}

resource kubernetes_config_map_v1_data argocd_tls_cert {
  metadata {
    name      = "argocd-tls-certs-cm"
    namespace = var.namespace
  }

  data = {
    "harbor.vn.linuxguru.net"= data.kubernetes_secret.ca_cert.data["tls.crt"]
  }
}

