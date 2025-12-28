terraform {
  backend "kubernetes" {
    namespace = "kube-system"
    secret_suffix = "deployment"
    config_path = "~/.kube/config"
  }
}

provider "helm" {
  kubernetes = { 
    config_path = "~/.kube/config"
  }
}

