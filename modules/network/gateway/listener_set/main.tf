locals {
  fqdn      = var.hostname != null ? var.hostname : "${var.name}.${var.domain}"
  cert_name = "cert-${local.fqdn}"
}

resource "kubernetes_manifest" "listener_set" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "ListenerSet"
    metadata = {
      name      = var.name
      namespace = var.namespace
      annotations = var.protocol == "HTTPS" && var.cert_issuer != "" ? {
        "cert-manager.io/cluster-issuer" = var.cert_issuer
      } : {}
    }
    spec = {
      parentRef = {
        name      = var.gateway_name
        namespace = var.gateway_namespace
      }
      listeners = [merge(
        {
          name     = var.name
          port     = var.port
          protocol = var.protocol
          hostname = local.fqdn
          allowedRoutes = {
            namespaces = {
              from = "All"
            }
          }
        },
        var.protocol == "HTTPS" ? {
          tls = {
            mode = "Terminate"
            certificateRefs = [
              { name = local.cert_name }
            ]
          }
        } : {}
      )]
    }
  }
}

resource "kubernetes_manifest" "reference_grant" {
  count = var.gateway_namespace != var.namespace ? 1 : 0

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1beta1"
    kind       = "ReferenceGrant"
    metadata = {
      name      = "${var.name}-listenerset"
      namespace = var.namespace
    }
    spec = {
      from = [
        {
          group     = "gateway.networking.k8s.io"
          kind      = "ListenerSet"
          namespace = var.namespace
        }
      ]
      to = [
        {
          group = "gateway.networking.k8s.io"
          kind  = "Gateway"
          name  = var.gateway_name
        }
      ]
    }
  }
}

resource "kubernetes_manifest" "reference_grant_httproute" {
  count = var.gateway_namespace != var.namespace ? 1 : 0

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1beta1"
    kind       = "ReferenceGrant"
    metadata = {
      name      = "${var.name}-httproute"
      namespace = var.namespace
    }
    spec = {
      from = [
        {
          group     = "gateway.networking.k8s.io"
          kind      = "HTTPRoute"
          namespace = var.namespace
        }
      ]
      to = [
        {
          group = "gateway.networking.k8s.io"
          kind  = "Gateway"
          name  = var.gateway_name
        }
      ]
    }
  }
}
