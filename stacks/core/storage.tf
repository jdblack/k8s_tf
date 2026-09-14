
module "seaweedfs" {
  source    = "../../modules/storage/seaweedfs"
  namespace = "kube-storage"
  # Both listeners (master.vn, s3.vn) are the "private" visibility. Sign them
  # with the public issuer: nothing in-cluster validates them (no S3 client, no
  # Longhorn backup target), and external clients then trust public roots
  # instead of ~/.ssl/ca.crt.
  cert_issuers = merge(
    var.deployment["cert_authorities"],
    { private = var.deployment.cert_authorities.public },
  )
  domains     = var.deployment["domains"]
  data_center = var.deployment.storage.data_center
}
