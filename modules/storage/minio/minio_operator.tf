variable namespace { }
variable volumes_per_server { default =  1 }

locals {
  helm_url = "https://operator.min.io"
  operator_chart = "operator"
  tenant_chart = "tenant"
}

resource helm_release operator {
  name  = "minio-operator"
  namespace = "${var.namespace}-operator"
  create_namespace = true
  repository = local.helm_url
  chart = local.operator_chart
  depends_on = [
    kubernetes_namespace.operator
  ]
}

resource kubernetes_namespace operator {
  metadata { 
    name = "${var.namespace}-operator"
  }
}

resource kubernetes_namespace tenant {
  metadata { 
    name = "${var.namespace}-tenant"
  }
}

resource helm_release tenant {
  name = "minio-tenant"
  namespace = "${var.namespace}-tenant"
  create_namespace = true
  repository = local.helm_url
  chart = local.tenant_chart
  set =  [ 
    {
      name = "tenant.pools[0].name"
      value = "mineminemine"
    },
    {
      name = "tenant.pools[0].servers"
      value = 6
    },
    {
      name = "tenant.pools[0].volumesPerServer"
      value = 1
    },
  ]
  depends_on = [
    kubernetes_namespace.tenant,
    helm_release.operator
  ]
}



