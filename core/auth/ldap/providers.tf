terraform {
  required_version = "~> 1.3.0"
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    helm = {
      version = "~> 2.8"
    }
    kubernetes = {
      version = "~> 2.17"
    }
    random = {
      version = "~> 3.4"
    }
  }
}

