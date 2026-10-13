module "backup" {
  source    = "../../storage/backup/schedule"
  target    = local.data_pvc_name
  namespace = var.namespace
  selector  = local.labels
}
