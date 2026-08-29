locals {
  namespace = coalesce(var.namespace, var.name)
  project = coalesce(var.project, var.name)
  aoa_name = coalesce(var.aoa_name, "aoa-${var.name}")
}
