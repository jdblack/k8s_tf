# Offsite copies are made by the rclone job on ns1 that mirrors these SeaweedFS buckets onto the
# local /backup disk. The old S3 -> Backblaze mirror (the per-bucket CronJobs) is gone; Terraform
# still owns the read-only per-bucket identities so the keys ns1 uses never drift.

locals {
  offsite_buckets = toset([
    "owncloud-storage",
    "photos",
    "movies-archive",
  ])
}

# A read-only identity per bucket, so one leaked key cannot read the others.
module "offsite_source" {
  for_each = local.offsite_buckets
  source   = "../seaweedfs/s3_user"

  user      = "offsite-${each.key}"
  bucket    = each.key
  role      = "readonly"
  namespace = kubernetes_namespace_v1.namespace.metadata[0].name
}
