
terraform {
  required_providers {
    kubernetes = {
      version = ">= 2.0"
    }
    helm = {
      version = ">= 2.8"
    }
  }
  required_version =  ">= 1.3"
}

