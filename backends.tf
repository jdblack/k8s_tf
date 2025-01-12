
terraform {
  backend "kubernetes" {
    namespace = "kube-system"
    secret_suffix = "tfstate"
    config_path = "~/.kube/config"
  }
}

