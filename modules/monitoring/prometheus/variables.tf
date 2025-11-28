variable prometheus_name { default = "prometheus" }

variable namespace    {  }
variable cert_issuer  {  }
variable domain       {  }
variable grafana_name { default = "grafana" }

locals {
  prometheus = {
    grafana = {
      enabled = true
      adminPassword = "prom-operator"
      persistence = {
        enabled = true
        size = "1Gi"
      }
      ingress = {
        enabled = true
        ingressClassName = "private"
        annotations = {
          "grafana.ingress.annotations.cert-manager.io/cluster-issuer" = var.cert_issuer
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






