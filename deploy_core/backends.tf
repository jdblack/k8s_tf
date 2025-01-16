
terraform {
  backend "kubernetes" {
    namespace = "kube-system"
    secret_suffix = "core"
    config_path = "~/.kube/config"
  }
}

