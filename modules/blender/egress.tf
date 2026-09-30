module "egress" {
  source    = "../network/firewalls/policy"
  direction = "egress"

  namespace    = kubernetes_namespace_v1.storage.metadata[0].name
  name         = "blender-egress"
  pod_selector = { app = local.samba_name }
}
