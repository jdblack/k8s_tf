locals {
  # The app's purge CronJob runs on its own egress policy, so the baseline must not also admit it.
  trash_purge = "owncloud-trash-purge"
}

module "egress_baseline" {
  source    = "../network/firewalls/policy"
  direction = "egress"

  namespace      = kubernetes_namespace_v1.namespace.metadata[0].name
  name           = "documents-baseline-egress"
  allow_internet = false

  # NotIn, so every pod without the label (all of oCIS) still takes the baseline.
  pod_selector_expressions = [{
    key      = "app.kubernetes.io/name"
    operator = "NotIn"
    values   = [local.trash_purge]
  }]
}
