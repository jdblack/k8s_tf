
variable namespace     { type = string }
variable name          { default = "argo-events" }

variable repo { default = "https://argoproj.github.io/argo-helm" }
variable chart { default = "argo-events" }


locals {
  config = {
  }
}
