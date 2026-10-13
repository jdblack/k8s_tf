# Forgejo's [storage] subsystems -- LFS, attachments, avatars, repo-avatars, repo-archive,
# packages, actions logs/artifacts -- are blobs, so they land in SeaweedFS over S3 rather than
# on the block claim. Only the DB and the git repositories stay on longhorn.
module "bucket" {
  source = "../../../storage/seaweedfs/bucket"

  bucket = var.s3_bucket
  owner  = var.name
}

# The credential Secret's keys ARE the FORGEJO__ env var names the chart's env-to-ini folds into
# app.ini, so the release references the Secret keys and nothing is threaded through values.
module "s3_user" {
  source = "../../../storage/seaweedfs/s3_user"

  user      = var.name
  bucket    = module.bucket.bucket
  role      = "admin"
  namespace = var.namespace

  access_key_key = "FORGEJO__storage__MINIO_ACCESS_KEY_ID"
  secret_key_key = "FORGEJO__storage__MINIO_SECRET_ACCESS_KEY"
}
