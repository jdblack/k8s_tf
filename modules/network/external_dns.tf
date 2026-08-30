
# This updates a standard Bind9 zone when a new service is created.
# You'll need to know the domain, server, and the rdns key.

locals {
  dns_server = endswith(var.internal_dns.server, ".") ? var.internal_dns.server : "${var.internal_dns.server}."
  dyndns_config = {
    publishInternalServices = true
    provider                = "rfc2136"
    image = {
      registry   = "registry.k8s.io"
      repository = "external-dns/external-dns"
      tag        = "v0.21.0"
    }
    rfc2136 = {
      zone        = var.internal_dns.domain
      host        = local.dns_server
      tsigKeyname = var.internal_dns.client
      tsigSecret  = var.internal_dns.secret
    }
    sources       = ["service", "ingress", "gateway-httproute"]
    domainFilters = [var.internal_dns.domain]
    extraArgs = {
      "gateway-listener-sets" = true
    }
  }
}


resource "helm_release" "ext_dnsrelease" {
  namespace  = var.namespace
  name       = local.charts.ext_dns.name
  repository = local.charts.ext_dns.url
  chart      = local.charts.ext_dns.chart
  values     = [yamlencode(local.dyndns_config)]
  depends_on = [kubernetes_namespace_v1.namespace]
}

# Grant external-dns permissions to read ListenerSets in gateway.networking.k8s.io
resource "kubernetes_cluster_role_v1" "ext_dns_listenersets" {
  metadata {
    name = "extdns-listenersets"
  }
  rule {
    api_groups = ["gateway.networking.k8s.io"]
    resources  = ["listenersets"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "ext_dns_listenersets" {
  metadata {
    name = "extdns-listenersets"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.ext_dns_listenersets.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = "${local.charts.ext_dns.name}-external-dns"
    namespace = var.namespace
  }
}


