# The whole workload -- Deployment, Services, PVC mount, ServiceMonitor, admin and OAuth
# bootstrap -- is the official Forgejo chart now; see locals.tf for the values it is fed.
resource "helm_release" "forgejo" {
  name       = var.name
  namespace  = kubernetes_namespace_v1.namespace.metadata[0].name
  repository = var.chart_repository
  chart      = var.chart
  version    = var.chart_version

  wait    = true
  timeout = 900

  values = [yamlencode(local.helm_values)]

  # The release reads the S3 credentials at first start, so they have to exist first. The OIDC client
  # used to be a submodule here; it is the `oidc` input now, so it is no longer an ordering edge.
  depends_on = [
    module.bucket,
    module.s3_user,
  ]
}
