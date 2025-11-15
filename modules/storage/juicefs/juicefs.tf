locals {
  juice_helm_repository = "https://juicedata.github.io/charts/"
  operator_config = {
  }
  csi_config = {
  }
}

resource helm_release juicefs_operator {
  name = "juicefs-operator"
  namespace = var.namespace
  repository = local.juice_helm_repository
  chart =  "juicefs-operator"
  set = [
    for key, value in local.operator_config : {
      name  = key
      value = value
    }
  ]

}

resource helm_release juicefs_csi {
  name = "juicefs-csi"
  chart = "juicefs-csi-driver"
  namespace = var.namespace
  repository = local.juice_helm_repository
  set = [
    for key, value in local.csi_config : {
      name  = key
      value = value
    }
  ]

}
