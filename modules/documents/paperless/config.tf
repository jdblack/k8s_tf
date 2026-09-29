resource "random_password" "secret_key" {
  length           = 50
  special          = true
  override_special = "_-%@"
}

resource "random_password" "admin" {
  length           = 24
  special          = true
  override_special = "_-%@"
}

resource "kubernetes_config_map_v1" "config" {
  metadata {
    name      = "${var.name}-config"
    namespace = var.namespace
    labels    = local.labels
  }

  data = merge(
    local.base_config,
    local.flower_config,
    local.filename_config,
    var.extra_config,
  )
}

resource "kubernetes_secret_v1" "config" {
  metadata {
    name      = "${var.name}-secret"
    namespace = var.namespace
    labels    = local.labels
  }

  data = merge(
    {
      PAPERLESS_SECRET_KEY     = random_password.secret_key.result
      PAPERLESS_ADMIN_PASSWORD = random_password.admin.result
    },
    var.extra_secret,
  )
}
