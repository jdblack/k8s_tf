module "egress_baseline" {
  source    = "../network/firewalls/policy"
  direction = "egress"

  namespace = var.namespace
  name      = "kube-storage-baseline-egress"
}

# Cluster-wide VolumeSnapshot reconciliation, plus its leader-election lease.
module "egress_snapshot_controller" {
  source    = "../network/firewalls/policy"
  direction = "egress"

  namespace     = var.namespace
  name          = "snapshot-controller-egress"
  pod_selector  = { "app.kubernetes.io/name" = "snapshot-controller" }
  allow_k8s_api = true
}
