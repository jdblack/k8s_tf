# WireGuard VPN (nccloud/wireguard-operator).
#
# Peers reach the server via `home.linuxguru.net` (public DNS -> router NAT,
# UDP 51820 -> MetalLB LoadBalancer IP). DNS + search domains are pushed to
# clients so they can resolve internal .vn.linuxguru.net / linuxguru.net names
# while away from home.
module "wireguard" {
  source = "../../modules/network/wireguard"

  namespace          = "kube-network-vpn"
  external_address   = var.deployment.vpn.external_address
  dns                = var.deployment.vpn.dns
  dns_search_domains = var.deployment.vpn.dns_search_domains
  peers              = var.deployment.vpn.peers

  depends_on = [module.network]
}
