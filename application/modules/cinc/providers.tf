

terraform {
  required_version = "~> 1.3"
  required_providers {
    random = {
      version = "~> 3.4"
    }
    kubernetes = {
      version = "~> 2.17"
    }

  }
}
