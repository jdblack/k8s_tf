module "listener_set" {
  source            = "../../network/gateway/listener_set"
  name              = var.name
  namespace         = var.namespace
  domain            = var.domain
  cert_issuer       = var.cert_issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
}


# App HTTPRoute: routes HTTPS host traffic from the ListenerSet to the backend Service.
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
          name = local.svc_name
          port = tonumber(var.service_port)
        }]
      }]
    }
  }
}


