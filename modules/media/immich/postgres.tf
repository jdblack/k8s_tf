module "postgres" {
  source = "./postgres"

  namespace = var.namespace
  name      = local.postgres_name

  image         = var.postgres_image
  image_tag     = var.postgres_image_tag
  storage_class = var.storage_class
  size          = var.postgres_size
}

# The database now lives in ./postgres; these rename the addresses in state rather than
# letting OpenTofu read each object as gone and build a replacement (the claim would take
# its longhorn volume with it).
moved {
  from = kubernetes_deployment_v1.postgres
  to   = module.postgres.kubernetes_deployment_v1.postgres
}

moved {
  from = kubernetes_service_v1.postgres
  to   = module.postgres.kubernetes_service_v1.postgres
}

moved {
  from = kubernetes_persistent_volume_claim_v1.postgres
  to   = module.postgres.kubernetes_persistent_volume_claim_v1.postgres
}

moved {
  from = kubernetes_secret_v1.postgres
  to   = module.postgres.kubernetes_secret_v1.postgres
}

moved {
  from = random_password.postgres
  to   = module.postgres.random_password.postgres
}
