

# Harbor needs the CA as a secret containing ca.crt, so read it from the
# config map and map it over.

data "kubernetes_config_map_v1" "ca_cert" {
  metadata {
    name = var.cert_issuer
  }
}

resource "kubernetes_secret_v1" "ca_cert" {
  metadata {
    name      = local.ca_secret_name
    namespace = var.namespace
  }
  data = {
    "ca.crt" = data.kubernetes_config_map_v1.ca_cert.data["tls.crt"]
  }
}

