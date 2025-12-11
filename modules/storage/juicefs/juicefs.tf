locals {
  juice_helm_repository = "https://juicedata.github.io/charts/"
  operator_config = {
  }
  helm_csi = {
    metrics = {
      enabled = true
    }
    dashboard = {
      enabled = false
    }

    mountOptions = [
      "cache-dir=/mnt/archive",
      "cache-size=235000",
      "free-space-ratio=0.1"
    ]
  }
}



resource helm_release juicefs_csi {
  name = "juicefs-csi"
  chart = "juicefs-csi-driver"
  namespace = var.namespace
  repository = local.juice_helm_repository
  values = [yamlencode(local.helm_csi)]

}
