module "network" {
  source         = "../../modules/network"
  internal_dns   = var.deployment.network.internal_dns
  metal_networks = var.deployment.network.metal_networks
}

module "storage" {
  source    = "../../modules/storage"
  namespace = "kube-storage"

  gateway_name      = module.network.gateway_name
  gateway_namespace = module.network.gateway_namespace

  backup_enabled  = var.backup_enabled
  backup_bucket   = var.deployment.storage.backup.bucket
  backup_region   = var.deployment.storage.backup.region
  backup_endpoint = var.deployment.storage.backup.endpoint

  backup_offsite_bucket     = var.deployment.storage.backup.offsite.bucket
  backup_offsite_region     = var.deployment.storage.backup.offsite.region
  backup_offsite_endpoint   = var.deployment.storage.backup.offsite.endpoint
  backup_offsite_access_key = var.deployment.storage.backup.offsite.access_key
  backup_offsite_secret_key = var.deployment.storage.backup.offsite.secret_key

  backup_buckets_dest_bucket = var.deployment.storage.backup.buckets.dest_bucket
  backup_buckets_region      = var.deployment.storage.backup.buckets.region
  backup_buckets_endpoint    = var.deployment.storage.backup.buckets.endpoint
  backup_buckets_access_key  = var.deployment.storage.backup.buckets.access_key
  backup_buckets_secret_key  = var.deployment.storage.backup.buckets.secret_key
}

module "cert_man" {
  source     = "../../modules/cert_manager"
  acme_email = var.deployment.cert_manager.acme_email

  dns01 = {
    AWS_ACCESS_KEY_ID     = var.deployment.cert_manager.dns01.access_key
    AWS_SECRET_ACCESS_KEY = var.deployment.cert_manager.dns01.secret_key
    AWS_REGION            = var.deployment.cert_manager.dns01.region
    R53_ZONEID            = var.deployment.cert_manager.dns01.zone_id
  }
}
