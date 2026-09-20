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

# Retention is this thinning pass, not Velero's TTL: TTL only bounds a dead thinner.
module "thin" {
  count  = var.backup_enabled ? 1 : 0
  source = "./backup/thin"

  # Flip once the dry-run plans have been read.
  dry_run = true

  depends_on = [module.backup]
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
