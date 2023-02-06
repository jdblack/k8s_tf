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

resource "kubectl_manifest" "sc_rrs" {
  yaml_body = yamlencode({
    apiVersion = "storage.k8s.io/v1"
    kind = "StorageClass"

    metadata = {
      name = "jiva-rr2"
      namespace = var.namespace
    }
    parameters = {
      "cas-type" = "jiva"
      policy = "jiva-rr2"
    }
    provisioner = "jiva.csi.openebs.io"
    reclaimPolicy = "Delete"
    volumeBindingMode = "Immediate"
  })
}

resource "kubectl_manifest" "jvp_rrs" {
  yaml_body = yamlencode({
    apiVersion = "openebs.io/v1"
    kind = "JivaVolumePolicy"
    metadata = {
      name = "jiva-rr2"
      namespace = var.namespace
    }
    spec = {
      repliaSC = "openebs-hostpath"
      target = {
        replicationFactor = 2
      }
    }
  })
  depends_on =  [ helm_release.release] 
}

