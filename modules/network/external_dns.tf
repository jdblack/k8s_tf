
# This updates a standard Bind9 zone when a new service is creaed.
# You'll need to know the domain, server,  and the  rdns key.



locals {
  dyndns_config = {
    publishInternalServices = true
    provider = "rfc2136"
    rfc2136 = {
      zone = var.deployment.internal_dns.domain
      host = var.deployment.internal_dns.server
      tsigKeyname = var.deployment.internal_dns.client
      tsigSecret = var.deployment.internal_dns.secret
    }
    sources = [ "service", "ingress" ]
    domainFilters = [ var.deployment.internal_dns.domain ]

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
