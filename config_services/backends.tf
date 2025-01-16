
terraform {
  backend "kubernetes" {
    namespace = "kube-system"
    secret_suffix = "tfstate-platform"
    config_path = "~/.kube/config"
  }
}

