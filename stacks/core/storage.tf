module "storage" {
  source    = "./storage"
  namespace = "kube-storage"

  gateway_name      = module.network.gateway_name
  gateway_namespace = module.network.gateway_namespace

  # For the SeaweedFS tier this module now owns.
  cert_issuer = var.deployment.cert_manager.external_issuer
  domains     = var.deployment.cluster.domains
  data_center = var.deployment.storage.data_center

  backup_enabled  = var.backup_enabled
  backup_bucket   = var.deployment.storage.backup.bucket
  backup_region   = var.deployment.storage.backup.region
  backup_endpoint = var.deployment.storage.backup.endpoint
}

