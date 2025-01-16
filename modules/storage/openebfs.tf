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
    value = false
  }
  set {
    name = "engines.replicated.mayastor.enabled"
    value =false
  }
  set {
    name = "engines.local.zfs.enabled"
    value = false
  }
}

resource "kubernetes_storage_class" "openebs_lvmpv" {
  metadata {
    name = "openebs-lvmpv"
    annotations = { "storageclass.kubernetes.io/is-default-class" = "true" }
  }


  allow_volume_expansion = true
  reclaim_policy = "Delete"

  parameters = {
    storage  = "lvm"
    volgroup = "ubuntu-vg"
    shared = "yes"
    thinProvision = "yes"
  }

  storage_provisioner = "local.csi.openebs.io"
}


