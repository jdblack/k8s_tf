

# Harbor is slightly retarded in regards to the CA.  We need to give it a secret with the ca.crt
# So here, we read from the config map and map it over

data kubernetes_config_map_v1 ca_cert {
  metadata {
    name      = var.cert_issuer
  }
}

resource kubernetes_secret_v1 ca_cert {
  metadata {
    name = local.ca_secret_name
    namespace = var.namespace
  }
  data = {
    "ca.crt"= data.kubernetes_config_map_v1.ca_cert.data["tls.crt"]
  }
}

