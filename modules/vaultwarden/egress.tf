module "egress" {
  source    = "../network/firewalls/policy"
  direction = "egress"

  namespace = kubernetes_namespace_v1.namespace.metadata[0].name
  name      = "vaultwarden-egress"
}
