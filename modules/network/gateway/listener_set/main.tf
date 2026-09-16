locals {
  fqdn      = var.hostname != null ? var.hostname : "${var.name}.${var.domain}"
  cert_name = "cert-${local.fqdn}"
}

# cert-manager's gateway-shim provisions the cert secret (in this namespace) from the annotation;
# protocol = "HTTP" gives a plain listener with no cert.
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
          # Accept routes from ANY namespace: charts that render their own route (harbor's
          # expose.type = "route") attach cross-namespace by hostname match.
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

# Cross-namespace ListenerSet -> Gateway attachment needs a ReferenceGrant in the ListenerSet's
# namespace; same-namespace needs none.
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

# Charts that render their own HTTPRoute reference the Gateway directly, so that direction needs its
# own grant.
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

