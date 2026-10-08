# kubectl_manifest: the Velero CRD is installed by core, so it may not exist at plan time.
resource "kubectl_manifest" "schedule" {
  yaml_body = yamlencode({
    apiVersion = "velero.io/v1"
    kind       = "Schedule"
    metadata = {
      name      = var.target
      namespace = var.velero_namespace
      labels    = local.target_label
    }
    spec = {
      schedule = var.cron
      template = {
        ttl                = var.ttl
        includedNamespaces = [var.namespace]
        labelSelector      = { matchLabels = var.selector }
      }
    }
  })
}

# Optional weekly copy, off-box, on a separate BSL (disabled when the BSL name is empty).
resource "kubectl_manifest" "weekly" {
  count = var.weekly_storage_location == "" ? 0 : 1

  yaml_body = yamlencode({
    apiVersion = "velero.io/v1"
    kind       = "Schedule"
    metadata = {
      name      = "${var.target}-weekly"
      namespace = var.velero_namespace
      labels    = local.target_label
    }
    spec = {
      schedule = var.weekly_cron
      template = {
        ttl                = var.weekly_ttl
        storageLocation    = var.weekly_storage_location
        includedNamespaces = [var.namespace]
        labelSelector      = { matchLabels = var.selector }
      }
    }
  })
}
