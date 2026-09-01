# Exposure via the shared private gateway (kube-network): HTTPS listeners for
# admin/master/s3 + HTTPRoutes to the chart's ClusterIP services. TLS is
# terminated at the gateway with linuxguru-ca certs (previously these were
# plain HTTP through the private ingress-nginx, so the scheme changes to
# https:// for these three hostnames).
module "listener_set_admin" {
  source            = "../../network/gateway/listener_set"
  name              = "seaweedfs-admin"
  namespace         = var.namespace
  domain            = var.domains[var.visibility]
  hostname          = local.admin_host
  cert_issuer       = local.issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
}

module "listener_set_master" {
  source            = "../../network/gateway/listener_set"
  name              = "seaweedfs-master"
  namespace         = var.namespace
  domain            = var.domains[var.visibility]
  hostname          = local.master_host
  cert_issuer       = local.issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
}

module "listener_set_s3" {
  source            = "../../network/gateway/listener_set"
  name              = "seaweedfs-s3"
  namespace         = var.namespace
  domain            = var.domains[var.visibility]
  hostname          = local.s3_host
  cert_issuer       = local.issuer
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
}

resource "kubernetes_manifest" "http_route_admin" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "seaweedfs-admin"
      namespace = var.namespace
      annotations = {
        "external-dns.alpha.kubernetes.io/hostname" = local.admin_host
      }
    }
    spec = {
      parentRefs = [{
        kind        = "ListenerSet"
        name        = "seaweedfs-admin"
        namespace   = var.namespace
        sectionName = "seaweedfs-admin"
      }]
      hostnames = [local.admin_host]
      rules = [{
        backendRefs = [{
          name = "seaweedfs-admin"
          port = 23646
        }]
      }]
    }
  }
}

resource "kubernetes_manifest" "http_route_master" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "seaweedfs-master"
      namespace = var.namespace
      annotations = {
        "external-dns.alpha.kubernetes.io/hostname" = local.master_host
      }
    }
    spec = {
      parentRefs = [{
        kind        = "ListenerSet"
        name        = "seaweedfs-master"
        namespace   = var.namespace
        sectionName = "seaweedfs-master"
      }]
      hostnames = [local.master_host]
      rules = [{
        backendRefs = [{
          name = "seaweedfs-master"
          port = 9333
        }]
      }]
    }
  }
}

resource "kubernetes_manifest" "http_route_s3" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "seaweedfs-s3"
      namespace = var.namespace
      annotations = {
        "external-dns.alpha.kubernetes.io/hostname" = local.s3_host
      }
    }
    spec = {
      parentRefs = [{
        kind        = "ListenerSet"
        name        = "seaweedfs-s3"
        namespace   = var.namespace
        sectionName = "seaweedfs-s3"
      }]
      hostnames = [local.s3_host]
      rules = [{
        backendRefs = [{
          name = "seaweedfs-s3"
          port = 8333
        }]
      }]
    }
  }
}
