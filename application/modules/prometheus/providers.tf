
terraform {
  required_version =  ">= 1.3"
  required_providers {
    kubernetes = {
      version = ">= 2.0"
    }
    helm = {
      version = ">= 2.8"
    }
    keycloak = {
      source = "mrparkers/keycloak"
      version = "4.1.0"
    }
    random = {
      version = "~> 3.4"
    }
  }
}

