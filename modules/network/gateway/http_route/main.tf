locals {
  fqdn = var.hostname != null ? var.hostname : "${var.name}.${var.domain}"
}

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
      rules = [merge({
        backendRefs = [{
          name = var.backend_name
          port = var.backend_port
        }]
      }, length(var.filters) > 0 ? { filters = var.filters } : {})]
    }
  }
}
