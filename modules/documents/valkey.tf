module "valkey" {
  source = "./valkey"

  namespace = kubernetes_namespace_v1.this.metadata[0].name
  name      = local.valkey_name

  image     = var.valkey_image
  image_tag = var.valkey_image_tag
  port      = local.valkey_port
}
