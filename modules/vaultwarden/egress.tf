module "egress" {
  source = "../network/firewalls/egress"

  namespace = kubernetes_namespace_v1.this.metadata[0].name
  name      = "vaultwarden-egress"
}
