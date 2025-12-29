variable namespace { default = "kube-security" }
variable name { default = "trivy" }

variable helm_repo { default = "https://aquasecurity.github.io/helm-charts/" }
variable chart { default = "trivy-operator" }



locals {

  helm_values = {
    serviceMonitor = {
      enabled = true
      namespace = "monitoring"
    }
  }
}
