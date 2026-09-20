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
