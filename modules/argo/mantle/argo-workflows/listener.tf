# Exposure via the shared private gateway (kube-network): HTTPS listener
# (argo-wf.vn.linuxguru.net, linuxguru-ca cert) + HTTPRoute to the ClusterIP
# service (plain HTTP backend on 2746).
module "listener_set" {
  source            = "../../../network/gateway/listener_set"
  name              = var.name
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
      name      = var.name
      namespace = var.namespace
      annotations = {
        "external-dns.alpha.kubernetes.io/hostname" = local.fqdn
      }
    }
    spec = {
      parentRefs = [{
        kind        = "ListenerSet"
        name        = var.name
        namespace   = var.namespace
        sectionName = var.name
      }]
      hostnames = [local.fqdn]
      rules = [{
        backendRefs = [{
          name = "${var.name}-argo-workflows-server"
          port = 2746
        }]
      }]
    }
  }
}
