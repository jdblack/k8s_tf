module "seaweedfs_admin" {
  source = "../../modules/storage/seaweedfs_admin"

  namespace   = "kube-storage"
  domain      = var.deployment.cluster.domains.private
  cert_issuer = var.deployment.cert_manager.external_issuer

  gateway_name      = "private"
  gateway_namespace = "kube-network"
}
