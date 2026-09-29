module "ollama" {
  count  = var.enable_ai ? 1 : 0
  source = "./ollama"

  namespace = kubernetes_namespace_v1.this.metadata[0].name
  name      = local.ollama_name

  image     = var.ollama_image
  image_tag = var.ollama_image_tag
  port      = local.ollama_port

  models        = [var.llm_model, var.embedding_model]
  models_size   = var.ollama_models_size
  storage_class = var.storage_class
  cpu_limit     = var.ollama_cpu_limit
  memory_limit  = var.ollama_memory_limit
}
