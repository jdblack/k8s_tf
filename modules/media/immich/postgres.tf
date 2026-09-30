module "postgres" {
  source = "./postgres"

  namespace = var.namespace
  name      = local.postgres_name

  image         = var.postgres_image
  image_tag     = var.postgres_image_tag
  storage_class = var.storage_class
  size          = var.postgres_size
}
