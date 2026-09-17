# Egress for the share itself and nothing else: it answers LAN clients and initiates nothing, so DNS
# plus its own namespace is the whole list. Selected by `app` -- and here that is load-bearing, not
# cosmetic: the mDNS advertiser is hostNetwork (mdns.tf) but still carries pod labels, so a
# namespace-wide `{}` would select it too, and whether Calico enforces pod policy inside a host netns
# has not been tested here. A blanket selector would risk the Bonjour advertisement to buy nothing:
# `blender-samba` is the only namespaced pod in this namespace.
module "egress" {
  source = "../network/firewalls/egress"

  namespace    = kubernetes_namespace_v1.storage.metadata[0].name
  name         = "blender-egress"
  pod_selector = { app = local.samba_name }
}
