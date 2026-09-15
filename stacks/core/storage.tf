
module "seaweedfs" {
  source    = "../../modules/storage/seaweedfs"
  namespace = "kube-storage"
  # Both listeners (master.vn, s3.vn) are the "private" visibility. Signed with the
  # default issuer because nothing in-cluster validates them and external clients then
  # trust public roots instead of ~/.ssl/ca.crt.
  cert_issuer = var.deployment.cert_authorities.default
  domains     = var.deployment["domains"]
  data_center = var.deployment.storage.data_center
}
