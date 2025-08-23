locals {
  helm_longhorn_url = "https://charts.longhorn.io"
  helm_longhorn_chart = "longhorn"

  #  helm_openebs_url = "https://openebs.github.io/charts"  # 3.10 and earlier
  helm_openebs_url = "https://openebs.github.io/openebs"
  helm_openebs_chart = "openebs"
}

variable "namespace" {
  type = string
  default = "kube-openebs"
}


variable "storage_nodes" {
  default = ""
}

variable "storage_disk" {
  default = "/dev/mapper/ubuntu--vg-mayastor--lv"
}

