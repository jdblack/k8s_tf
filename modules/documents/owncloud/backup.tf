module "backup" {
  for_each = local.backup_targets

  source    = "../../storage/backup/schedule"
  target    = each.key
  namespace = var.namespace
  selector  = each.value
}
