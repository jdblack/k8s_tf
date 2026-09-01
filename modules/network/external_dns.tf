
# This updates a standard Bind9 zone when a new service is created.
# You'll need to know the domain, server, and the rdns key.

locals {
  dns_server = endswith(var.internal_dns.server, ".") ? var.internal_dns.server : "${var.internal_dns.server}."
}


resource "helm_release" "ext_dnsrelease" {
  namespace  = var.namespace
  name       = local.charts.ext_dns.name
  repository = local.charts.ext_dns.url
  chart      = local.charts.ext_dns.chart
  values     = [yamlencode(local.helm_values.external_dns)]
  depends_on = [kubernetes_namespace_v1.namespace]
}



