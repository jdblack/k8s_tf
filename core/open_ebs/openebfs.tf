resource "kubernetes_namespace" "openebs" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "release" {
  name  = "openebs"
  namespace = var.namespace
  repository = var.helm_openebs_url
  chart = var.openebs_chart
  set {
    name = "localprovisioner.hostpathClass.isDefaultClass"
    value = true
  }
  set {
    name = "jiva.enabled"
    value = true
  }
  set {
    name = "jiva.replicas"
    value = 2
  }
}

