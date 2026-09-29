locals {
  fqdn = coalesce(var.hostname, "${var.name}.${var.domain}")

  icon_cdn = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/"
  icon     = var.icon == null ? "${local.icon_cdn}${var.name}.svg" : (var.icon == "" ? null : var.icon)

  uid = 1000
  gid = 1000

  app_port    = 8000
  flower_port = 5555

  valkey_name = "${var.name}-valkey"
  valkey_port = 6379

  ollama_name = "${var.name}-ollama"
  ollama_port = 11434

  # media rides the SeaweedFS s3sync, consume is a transient inbox, and the model blobs re-pull,
  # so only the database claim is a backup target.
  media_pvc   = "documents-media"
  consume_pvc = "documents-consume"
  data_pvc    = "documents-paperless-data"
  ollama_pvc  = "documents-ollama"

  labels = { "app.kubernetes.io/name" = var.name }
}
