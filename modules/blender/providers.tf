terraform {
  required_providers {
    kubernetes = {
    }
    random = {
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}
