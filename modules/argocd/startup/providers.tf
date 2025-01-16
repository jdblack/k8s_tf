
terraform {
  required_providers {
    argocd = {
      source = "argoproj-labs/argocd"
      version = "7.3.0"
    }
  }
}

provider "argocd" {
  server_addr = "${var.argocd_host}:443"
  username = var.argocd_user
  password = var.argocd_pass
}

