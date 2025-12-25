variable namespace { type = string }
variable name { default = "" }
variable project { default = "" }
variable repo { }
variable deployment_path {}
variable deployment_namespace { default="devops-argocd" }

locals {
  name = coalesce(var.name, var.namespace)
  project = coalesce(var.project, local.name)
}

locals {
  helm = {
    postgres = {
      repo = "oci://registry-1.docker.io/bitnamicharts" 
      chart = "postgresql" 
    }
  }
}

