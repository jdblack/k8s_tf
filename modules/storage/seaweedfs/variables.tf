variable "namespace" { type = string }
variable "cert_issuers" { type = map(any) }
variable "name" { default = "seaweedfs" }
variable "helm_repo" { default = "https://seaweedfs.github.io/seaweedfs/helm" }
variable "chart" { default = "seaweedfs" }
variable "visibility" { default = "private" }
variable "domains" { type = map(any) }
variable "data_center" { type = string }
variable "admin_password" {
  type      = string
  sensitive = true
}
variable "volume_replicas" { default = 6 }
variable "worker_replicas" { default = 3 }
variable "host_path_prefix" { default = "/ssd" }
variable "helm_version" { default = "4.40.0" }

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }
