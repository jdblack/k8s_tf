locals {
  app_data_name = "${var.name}-data"

  gated = var.auth_outpost != null
}
