variable "namespace" { type = string }
variable "network_namespace" { default = "kube-network" }
variable "system_namespace" { default = "kube-system" }
variable "allow_internet" { default = true }
variable "allow_dns" { default = true }
variable "allow_to_ns" { default = true }
variable "allow_to_services" { default = false }
