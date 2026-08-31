locals {
  fqdn      = var.hostname != null ? var.hostname : "${var.name}.${var.domain}"
  cert_name = "cert-${local.fqdn}"
}

# App HTTPS listener on this Gateway instance (e.g. media-private). The
# cert-manager gateway-shim auto-provisions the certificate secret (in THIS
# namespace, same-namespace as the ListenerSet) based on the annotation.
# protocol = "HTTP" creates a plain-HTTP listener with no cert (cert_issuer
# ignored) - only needed if an app must keep serving plain HTTP.
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
          # Accept routes from any namespace. Apps that own their exposure with
          # manifest routes parentRef this ListenerSet (same namespace), but
          # charts that render routes against the Gateway directly (e.g.
          # harbor's expose.type = "route") attach cross-namespace via hostname
          # matching -- the default allowedRoutes (Same) would block those.
          # Hostname scoping keeps this app-isolated.
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

# Cross-namespace ListenerSet -> Gateway attachment (gateway lives in another
# namespace, e.g. the shared public/private gateways in kube-network) requires
# a ReferenceGrant in the ListenerSet's namespace. Same-namespace attachments
# (the media gateway pattern) need no grant, so this is skipped there.
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

# Charts that render their own Gateway API HTTPRoute against the gateway
# (e.g. harbor's expose.type = "route") reference the Gateway directly, so a
# cross-namespace attachment needs a SECOND grant for HTTPRoute -> Gateway.
# Created alongside the ListenerSet grant so any cross-namespace app that uses
# this submodule is covered either way.
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

