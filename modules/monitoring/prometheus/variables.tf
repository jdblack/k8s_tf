variable prometheus_name { default = "prometheus" }

variable namespace    {  }
variable cert_issuer  {  }
variable domain       {  }
variable grafana_name { default = "grafana" }
variable grafana_admin_password { default = "" }
variable ingress_class { default = "private" }

locals {
  prometheus = {
    grafana = {
      enabled = true
      adminPassword = var.grafana_admin_password != "" ? var.grafana_admin_password : random_password.grafana_admin.result
      persistence = {
        enabled = true
        size = "1Gi"
      }
      ingress = {
        enabled = true
        ingressClassName = var.ingress_class
        annotations = {
          "cert-manager.io/cluster-issuer" = var.cert_issuer
        }
        tls = [
          {
            secretName = "prometheus-grafana-cert"
            hosts = [
              var.grafana_name,
              "${var.grafana_name}.${var.domain}"
            ]
          }
        ]
        hosts = [
          var.grafana_name,
          "${var.grafana_name}.${var.domain}"
        ]
      }
    }
    prometheus = {
      prometheusSpec = {
        podMonitorSelectorNilUsesHelmValues = false
        serviceMonitorSelectorNilUsesHelmValues = false
      }
    }
  }
}






