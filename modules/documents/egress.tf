module "egress_baseline" {
  source    = "../network/firewalls/policy"
  direction = "egress"

  namespace      = kubernetes_namespace_v1.namespace.metadata[0].name
  name           = "documents-baseline-egress"
  allow_internet = false
}
