module "seaweedfs_admin" {
  source = "../../modules/storage/seaweedfs_admin"

  namespace   = "kube-storage"
  domain      = var.deployment.domains.private
  cert_issuer = var.deployment.cert_authorities.default

  gateway_name      = "private"
  gateway_namespace = "kube-network"

  group_name = "storage"
}
