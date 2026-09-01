locals {
  helm_values = {
    grafana = {
      enabled       = true
      adminPassword = var.grafana_admin_password != "" ? var.grafana_admin_password : random_password.grafana_admin.result
      persistence = {
        enabled = true
        size    = "1Gi"
      }
    }
    prometheus = {
      prometheusSpec = {
        podMonitorSelectorNilUsesHelmValues     = false
        serviceMonitorSelectorNilUsesHelmValues = false
      }
    }
  }
}
