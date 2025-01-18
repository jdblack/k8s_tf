locals {
  helm = {
    postgres = {
      repo = "oci://registry-1.docker.io/bitnamicharts" 
      chart = "postgresql" 
    }
  }
}

