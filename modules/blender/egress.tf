# Egress for the share itself, and nothing else: it answers LAN clients and initiates nothing,
# so DNS plus its own namespace is the whole list. Selected by `app` rather than namespace-wide
# so the policy says exactly what it covers -- the mDNS advertiser is hostNetwork (mdns.tf),
# where pod policy does not apply at all.
module "egress" {
  source = "../network/firewalls/egress"

  namespace    = kubernetes_namespace_v1.storage.metadata[0].name
  name         = "blender-egress"
  pod_selector = { app = local.samba_name }
}
