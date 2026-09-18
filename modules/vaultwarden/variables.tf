variable "namespace" { default = "vaultwarden" }
variable "name" { default = "vaultwarden" }

variable "domain" { type = string }

variable "cert_issuer" { type = string }

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }

variable "zone_id" { type = string }

variable "private_gateway_ip" { type = string }

variable "image" { default = "vaultwarden/server" }
variable "image_tag" { default = "1.37.3" }

variable "port" { default = 80 }

variable "storage_class" { default = "longhorn" }
variable "storage_size" { default = "2Gi" }

variable "signups_allowed" { default = false }
