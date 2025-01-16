variable name { default = "prometheus" }
variable repo { default = "https://prometheus-community.github.io/helm-charts" }
variable chart        { default = "kube-prometheus-stack" }

variable namespace    {  }
variable cert_issuer  {  }
variable domain       {  }
variable grafana_name { default = "grafana" }

locals {
  grafana = {
    name = var.grafana_name
    fqdn = "${var.grafana_name}.${var.domain}"
  }
}






