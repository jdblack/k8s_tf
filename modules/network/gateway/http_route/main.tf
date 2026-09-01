locals {
  fqdn = var.hostname != null ? var.hostname : "${var.name}.${var.domain}"
}

# App HTTPRoute: routes HTTPS host traffic from the app's ListenerSet (or
# directly from a Gateway) to the backend Service. Single hostname, single
# rule, single backend -- the shape every app in this repo uses. The
# external-dns annotation keeps DNS for the hostname pointed at the gateway.
resource "kubernetes_manifest" "http_route" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = var.name
      namespace = var.namespace
      annotations = merge({
        "external-dns.alpha.kubernetes.io/hostname" = local.fqdn
      }, var.annotations)
    }
    spec = {
      parentRefs = [{
        group       = "gateway.networking.k8s.io"
        kind        = var.parent_kind
        name        = coalesce(var.parent_name, var.name)
        namespace   = coalesce(var.parent_namespace, var.namespace)
        sectionName = coalesce(var.parent_name, var.name)
      }]
      hostnames = [local.fqdn]
      rules = [{
        backendRefs = [{
          name = var.backend_name
          port = var.backend_port
        }]
      }]
    }
  }
}
