locals {
  helm_longhorn_url = "https://charts.longhorn.io"
  helm_longhorn_chart = "longhorn"
}


variable helm_longhorn_url  { default = "https://charts.longhorn.io" }
variable helm_longhorn_chart { default = "longhorn" }


resource kubernetes_namespace longhorn {
  metadata {
    name = "longhorn-system"
  }
}

resource "helm_release" longhorn {
  name  = "longhorn"
  namespace = "longhorn-system"
  repository = var.helm_longhorn_url
  chart = var.helm_longhorn_chart
  depends_on = [ kubernetes_namespace.longhorn ]
  wait_for_jobs = true
  wait = true
  set =  [ 
    {
      name = "persistence.defaultDataLocality"
      value = "best-effort"
    },
    {
      name = "metrics.serviceMonitor.enabled"
      value = "true"
    } , {
      name = "persistence.defaultClassReplicaCount"
      value = "2"
    } , {
      name = "longhornUI.replicas"
      value = "0"
    }
  ]
  provisioner "local-exec" {
    when = destroy
    command = "kubectl -n longhorn-system patch lhs deleting-confirmation-flag -p '{\"value\": \"true\"}' --type=merge"
  }
}


