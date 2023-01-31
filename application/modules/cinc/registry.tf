

module "registry-puller" {
  source  = "../../../common/registry_access"
   registry_ns = var.registry_info.namespace
   registry_secret = var.registry_info.secret_name
   dest_ns = var.namespace
   dest_secret = local.registry_secret
}
