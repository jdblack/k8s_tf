terraform { 

  required_version = "~> 1.3.0"

  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    http = {
      version = "~> 3.2"
    }
    helm = {
      version= "~> 2.8"
    }
  }

}


