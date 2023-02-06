locals {
  dyndns_config = {
    publishInternalServices = true
    provider = "rfc2136"
    rfc2136 = {
      zone = var.deployment.dyndns.domain
      host = var.deployment.dyndns.server
      tsigKeyname = var.deployment.dyndns.client
      tsigSecret = var.deployment.dyndns.secret
    }
    sources = [ "service", "ingress" ]
    domainFilters = [ var.deployment.dyndns.domain ]

  }
}
resource "helm_release" "ext_dnsrelease" {
  namespace  = var.namespace
  name       = local.charts.ext_dns.name
  repository = local.charts.ext_dns.url
  chart      = local.charts.ext_dns.chart
  values = [yamlencode(local.dyndns_config)]
  depends_on  = [ kubernetes_namespace.namespace]
}
