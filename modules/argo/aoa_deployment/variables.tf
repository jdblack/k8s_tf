variable "argo_namespace" { type = string }
variable "name" { type = string }
variable "namespace" { default = "" }
variable "create_namespace" { default = false }
variable "project" { default = "" }
variable "aoa_name" { default = "" }

variable "deployer_repo" { type = string }
variable "deployer_path" { type = string }
