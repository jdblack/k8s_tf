resource "helm_release" "opensearch" {
  namespace  = var.namespace
  name       = "opensearch"
  repository = "https://opensearch-project.github.io/helm-charts/"
  version = "1"
  chart      = "opensearch"
  values = local.opensearch_values

  set {
    name = "service.annotations.external-dns\\.alpha\\.kubernetes\\.io/hostname"
    value = local.fqdn
    type = "string"
  }
}
