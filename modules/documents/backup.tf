# One schedule, one claim: the pod annotation on the deployment limits velero to the `data`
# volume, so the SeaweedFS library and the transient inbox stay out of it.
module "backup" {
  source = "../storage/backup/schedule"

  target    = local.data_pvc
  namespace = kubernetes_namespace_v1.this.metadata[0].name
  selector  = local.labels
}
