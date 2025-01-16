variable helm_openebs_url {
  default = "https://openebs.github.io/openebs"
  type = string
}
variable openebs_chart {
  type = string
  default = "openebs"
}

variable "namespace" {
  type = string
  default = "kube-openebs"
}

