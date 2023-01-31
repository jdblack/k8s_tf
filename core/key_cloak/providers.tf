terraform {
  required_version = "~> 1.3.0"
  required_providers {
    helm = {
      version = "~> 2.8"
    }
    kubernetes = {
      version = "~> 2.17"
    }
    random = {
      version = "~> 3.0"
    }

  }

}
