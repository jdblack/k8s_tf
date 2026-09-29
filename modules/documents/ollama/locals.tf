locals {
  labels = { "app.kubernetes.io/name" = var.name }

  # Runs in both containers, so the blobs and ollama's own state share the claim.
  models_dir = "/models"

  pulls = join(" && ", [for model in var.models : "ollama pull ${model}"])
}
