module "egress_baseline" {
  source = "../network/firewalls/egress"

  namespace = var.namespace
  name      = "kube-storage-baseline-egress"
}
