
# This updates a standard Bind9 zone when a new service is created.
# You'll need to know the domain, server, and the rdns key.

locals {
  dns_server = endswith(var.internal_dns.server, ".") ? var.internal_dns.server : "${var.internal_dns.server}."
  dyndns_config = {
    provider = {
      name = "rfc2136"
    }
    env = [
      {
        name  = "EXTERNAL_DNS_RFC2136_HOST"
        value = local.dns_server
      },
      {
        name  = "EXTERNAL_DNS_RFC2136_PORT"
        value = "53"
      },
      {
        name  = "EXTERNAL_DNS_RFC2136_ZONE"
        value = var.internal_dns.domain
      },
      {
        name  = "EXTERNAL_DNS_RFC2136_TSIG_KEYNAME"
        value = var.internal_dns.client
      },
      {
        name  = "EXTERNAL_DNS_RFC2136_TSIG_SECRET"
        value = var.internal_dns.secret
      },
      {
        name  = "EXTERNAL_DNS_RFC2136_TSIG_SECRET_ALG"
        value = "hmac-sha256"
      }
    ]
    sources                   = ["service", "ingress", "gateway-httproute"]
    enableGatewayListenerSets = true
    domainFilters             = [var.internal_dns.domain]
    extraArgs = [
      "--publish-internal-services"
    ]
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



