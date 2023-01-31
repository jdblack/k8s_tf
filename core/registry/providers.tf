terraform {
  required_version = "~> 1.3.0"
  required_providers { 
    random = {
      version = "~> 3.4"
    }
    kubernetes = {
      version = "~>2.17"
    }
    helm = {
      version = "~>2.8"
    }
  }
}
