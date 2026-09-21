module "backup" {
  count  = var.backup_enabled ? 1 : 0
  source = "./backup"

  bucket   = var.backup_bucket
  region   = var.backup_region
  endpoint = var.backup_endpoint

  public_endpoint = var.backup_public_endpoint
}

locals {
  # One schedule per seaweedfs volume, same as every other target.
  seaweedfs_targets = var.backup_enabled ? toset(["admin", "filer", "master"]) : toset([])
}

# The namespace's own metadata (seaweedfs master/filer/admin): an accidental-wipe guard.
module "seaweedfs_backup" {
  for_each = local.seaweedfs_targets
  source   = "./backup/schedule"

  target    = "seaweedfs-${each.key}"
  namespace = var.namespace
  selector = {
    "app.kubernetes.io/name"      = "seaweedfs"
    "app.kubernetes.io/component" = each.key
  }

  # The Schedule CRs live in kube-backup, which module.backup creates.
  depends_on = [module.backup]
}
