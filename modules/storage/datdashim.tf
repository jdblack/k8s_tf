resource helm_release datashim {
  name = "datashim"
  namespace = var.namespace
  repository = "https://datashim-io.github.io/datashim/"
  version = "0.4.0"
  chart =  "datashim-charts"
  depends_on = [ kubernetes_namespace.storage ]
}
