
# The apiserver's real endpoint IPs (control-plane nodes), read HERE, at the
# stack's root module, and passed down to the firewall modules that need them
# (authentik's pod-scoped allow_api, cert_man's namespace-wide allow_to_k8sapi).
#
# Why the root and not the firewall module? A module-level `depends_on` applies
# to everything inside the module, data sources included. authentik depends on
# module.cert_man + module.storage, cert_man on module.network -- so ANY pending
# change in one of those defers the endpoints read to apply time; the
# NetworkPolicy that consumes it then plans a *guessed* peer-block count
# (ClusterIP only, 1) and the apply dies with the provider's "inconsistent final
# plan" error (`spec.egress[1].to: block count changed from 1 to 2`). Nothing
# depends on the root module, so here the read happens during plan and the peer
# list is known. Mechanism + evidence: .clinedocs/calico-netpols.md.
data "kubernetes_endpoints_v1" "kubernetes" {
  metadata {
    name      = "kubernetes"
    namespace = "default"
  }
}

locals {
  # Post-DNAT endpoints of the API server: Calico evaluates egress policy after
  # kube-proxy DNATs the ClusterIP, so these IPs -- not 10.96.0.1 -- are what
  # authorize API traffic from the pods these firewalls cover.
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
  gateway_ips = {
    public  = var.deployment.network_ingress.public_ip
    private = var.deployment.network_ingress.private_ip
  }
}

module "storage" {
  source     = "../../modules/storage"
  namespace  = "kube-storage"
  depends_on = [module.network]
}

module "cert_man" {
  source     = "../../modules/cert_manager"
  data       = var.deployment.cert
  acme_email = var.deployment.cert.acme_email

  # cert-manager gateway-shim (config.enableGatewayAPI) needs the Gateway API
  # CRDs to exist before it starts. modules/network/api_gateway_config.tf
  # installs them (cluster-scoped, exactly once), so wait for the network
  # module. This guarantees a fresh rebuild provisions the shim before any
  # Gateway manifests are applied.
  #
  # api_peer_ips: see the data source at the top of this file -- without it the
  # firewall's own endpoints read is deferred by the depends_on above and the
  # apply aborts with "inconsistent final plan".
  api_peer_ips = local.api_peer_ips

  depends_on = [module.network]
}
