

resource "kubernetes_namespace" "namespace" {
  metadata {
    name = var.namespace
  }
}


module corsless {
  source = "../../service_modules/corsless"
  domain = var.deployment.common.domain
  deployment = var.deployment
  namespace = var.namespace
  depends_on =  [ module.registry ]

}


