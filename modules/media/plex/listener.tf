# Web UI exposure via the shared public gateway (kube-network): HTTPS listener
# (plex.linuxguru.net, letsencrypt cert) + HTTPRoute to the same PMS service
# the chart's LoadBalancer exposes (32400). DNS keeps publishing both IPs:
# 192.168.0.104 (direct PMS via the LoadBalancer service) and 192.168.0.101
# (web UI via the gateway).
module "listener_set" {
  source            = "../../network/gateway/listener_set"
  name              = var.plex_name
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
      name      = var.plex_name
      namespace = var.namespace
      annotations = {
        "external-dns.alpha.kubernetes.io/hostname" = local.plex_host_internal
      }
    }
    spec = {
      parentRefs = [{
        kind        = "ListenerSet"
        name        = var.plex_name
        namespace   = var.namespace
        sectionName = var.plex_name
      }]
      hostnames = [local.plex_host_internal]
      rules = [{
        backendRefs = [{
          name = "${var.plex_name}-plex-media-server"
          port = 32400
        }]
      }]
    }
  }
}
