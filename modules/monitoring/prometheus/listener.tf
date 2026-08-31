# Exposure via the shared private gateway (kube-network): HTTPS listener
# (grafana.vn.linuxguru.net, linuxguru-ca cert) + HTTPRoute to the
# prometheus-grafana ClusterIP service. TLS terminated at the gateway.
module "listener_set" {
  source            = "../../network/gateway/listener_set"
  name              = var.grafana_name
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
}

resource "kubernetes_manifest" "http_route" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = var.grafana_name
      namespace = var.namespace
      annotations = {
        "external-dns.alpha.kubernetes.io/hostname" = "${var.grafana_name}.${var.domain}"
      }
    }
    spec = {
      parentRefs = [{
        kind        = "ListenerSet"
        name        = var.grafana_name
        namespace   = var.namespace
        sectionName = var.grafana_name
      }]
      hostnames = ["${var.grafana_name}.${var.domain}"]
      rules = [{
        backendRefs = [{
          name = "prometheus-grafana"
          port = 80
        }]
      }]
    }
  }
}
