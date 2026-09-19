# kubectl_manifest: the Velero CRD is installed by core, so it may not exist at plan time.
resource "kubectl_manifest" "schedule" {
  for_each = local.selected

  yaml_body = yamlencode({
    apiVersion = "velero.io/v1"
    kind       = "Schedule"
    metadata = {
      name      = "${var.namespace}-${each.key}"
      namespace = var.velero_namespace
    }
    spec = {
      schedule = each.value.cron
      template = {
        ttl                = each.value.ttl
        includedNamespaces = [var.namespace]
      }
    }
  })
}
