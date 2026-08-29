variable "namespace" { type = string }
variable "name" { default = "seaweedfs" }
variable "helm_repo" { default = "https://seaweedfs.github.io/seaweedfs-csi-driver/helm" }
variable "chart" { default = "seaweedfs-csi-driver" }
variable "helm_version" { default = "0.2.35" }
