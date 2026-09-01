locals {
  wg_spec = {
    mtu                      = "1380"
    enableIpForwardOnPodInit = true
    serviceType              = "LoadBalancer"
    dns                      = var.dns != "" ? var.dns : null
    dnsSearchDomain          = length(var.dns_search_domains) > 0 ? join(", ", var.dns_search_domains) : null
    externalAddress          = var.external_address != "" ? var.external_address : null
  }

  helm_values = {
    nameOverride = "wireguard-operator"
    image = {
      tag        = var.image_tag
      pullPolicy = "IfNotPresent"
    }
  }
}
