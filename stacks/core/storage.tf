module "storage" {
  source    = "../../modules/storage"
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

# SeaweedFS moved inside `module.storage` (modules/storage/seaweedfs.tf) so the kube-storage
# namespace, SeaweedFS and the Velero backup that execs into it are all one module -- the ordering
# becomes expressible and the bootstrap cycle disappears.
#
# This block relocates the live instance to its new address. Removing it would plan a destroy of the
# old address, which is a helm uninstall of SeaweedFS (chart CRDs + the admin PVC that holds the IAM
# identities). Keep it.
moved {
  from = module.seaweedfs
  to   = module.storage.module.seaweedfs
}
