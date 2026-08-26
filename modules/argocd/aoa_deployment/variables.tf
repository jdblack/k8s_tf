variable namespace { type = string }
variable name { default = "" }
variable project { default = "" }
variable repo { }
variable deployment_path {}
variable deployment_namespace { default="argo" }

locals {
  name = coalesce(var.name, var.namespace)
  project = coalesce(var.project, local.name)
}
