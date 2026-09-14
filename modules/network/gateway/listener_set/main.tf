locals {
  fqdn      = var.hostname != null ? var.hostname : "${var.name}.${var.domain}"
  cert_name = "cert-${local.fqdn}"
}

# App HTTPS listener on this Gateway instance (e.g. media-private). cert-manager's
# gateway-shim auto-provisions the cert secret (in this namespace, alongside the
# ListenerSet) from the annotation. protocol = "HTTP" gives a plain-HTTP listener
# with no cert (cert_issuer ignored).
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
          # Accept routes from ANY namespace: charts that render their own route
          # against the Gateway (e.g. harbor's expose.type = "route") attach
          # cross-namespace via hostname matching, which the default
          # allowedRoutes (Same) would block. Hostname scoping keeps it isolated.
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

# Cross-namespace ListenerSet -> Gateway attachment needs a ReferenceGrant in the
# ListenerSet's namespace. Same-namespace attachment (the media pattern) needs
# none, so this is skipped there.
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

# Charts that render their own HTTPRoute against the Gateway (harbor's
# expose.type = "route") reference it directly, so a cross-namespace attachment
# needs a SECOND grant for HTTPRoute -> Gateway.
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

