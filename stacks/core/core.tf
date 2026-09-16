# Apiserver endpoint IPs, read at the stack root and passed down to the firewalls. A
# module-level `depends_on` covers data sources too: under one, the consuming NetworkPolicy
# plans a guessed peer count and the apply dies with "inconsistent final plan". Nothing
# depends on the root module, so here the read stays in plan. .clinedocs/calico-netpols.md
data "kubernetes_endpoints_v1" "kubernetes" {
  metadata {
    name      = "kubernetes"
    namespace = "default"
  }
}

locals {
  # Calico evaluates egress post-DNAT, so these -- not 10.96.0.1 -- authorize API
  # traffic.
  api_peer_ips = flatten([
    for s in try(data.kubernetes_endpoints_v1.kubernetes.subset, []) : [
      for a in s.address : a.ip
    ]
  ])
}

module "network" {
  source         = "../../modules/network"
  internal_dns   = var.deployment.internal_dns
  metal_networks = var.deployment.metal.networks
  # Gateway data planes are not told a VIP: they float and are reached by name.
}

module "storage" {
  source     = "../../modules/storage"
  namespace  = "kube-storage"
  depends_on = [module.network]

  # Same reason as cert_man below: the longhorn egress firewall needs the API carve-out,
  # and this module sits under a module-level depends_on.
  api_peer_ips = local.api_peer_ips
}

module "cert_man" {
  source     = "../../modules/cert_manager"
  data       = var.deployment.cert
  acme_email = var.deployment.cert.acme_email

  # Needs network's Gateway API CRDs (cert-manager's gateway shim), and api_peer_ips
  # must come from the root: see the data source at the top of this file.
  api_peer_ips = local.api_peer_ips

  depends_on = [module.network]
}
