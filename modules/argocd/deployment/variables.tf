variable namespace { }
variable name { default = "ai" }
variable project { default = "" }
variable repo { }
variable deployment_path {}
variable realm {} 
variable deployment_namespace { default="devops-argo" }

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

