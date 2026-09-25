variable "namespace" { type = string }
variable "name" { default = "authentik" }

variable "helm_version" { default = "2026.8.2" }

variable "pod_cidr" { type = string }

variable "domain" { type = string }
variable "cert_issuer" { type = string }
variable "fqdn" { default = "" }

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }

variable "outpost_namespaces" {
  type    = list(string)
  default = ["media", "kube-storage", "calico-system", "monitoring"]
}
