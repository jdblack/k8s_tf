variable "argo_namespace" {} # The AoA deployer goes into the argocd namespace
variable "name" {}
variable "namespace" { default = "" }
variable "create_namespace" { default = false }
variable "project" { default = "" }
variable "aoa_name" { default = "" }

variable "deployer_repo" { type = string }
variable "deployer_path" { type = string }
