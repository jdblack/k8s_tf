module "backup" {
  count  = var.backup_enabled ? 1 : 0
  source = "./backup"

  bucket   = var.backup_bucket
  region   = var.backup_region
  endpoint = var.backup_endpoint
}

# The namespace's own metadata (seaweedfs master/filer/admin): an accidental-wipe guard.
module "namespace_backup" {
  count     = var.backup_enabled ? 1 : 0
  source    = "./backup/schedule"
  namespace = var.namespace

  tiers = ["daily"]

  # The Schedule CRs live in kube-backup, which module.backup creates.
  depends_on = [module.backup]
}
