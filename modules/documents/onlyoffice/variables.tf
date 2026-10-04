variable "namespace" { default = "documents" }
variable "name" { default = "onlyoffice" }

variable "domain" { type = string }
variable "hostname" { default = "office" }

variable "cert_issuer" { type = string }

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }

variable "image" { default = "onlyoffice/documentserver" }
variable "image_tag" { default = "9.2" }

variable "port" { default = 80 }

variable "storage_class" { default = "longhorn" }

# The WOPI proof keys live here; lose them and every in-flight document open fails.
variable "data_size" { default = "10Gi" }
