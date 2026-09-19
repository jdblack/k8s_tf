resource "helm_release" "velero" {
  name       = "velero"
  repository = "https://vmware-tanzu.github.io/helm-charts"
  chart      = "velero"
  version    = var.helm_version
  namespace  = kubernetes_namespace_v1.namespace.metadata[0].name
  wait       = true
  timeout    = 600
  values     = [yamlencode(local.helm_values)]

  depends_on = [
    kubernetes_secret_v1.credentials,
    terraform_data.provision,
  ]
}
