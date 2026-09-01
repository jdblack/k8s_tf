locals {
  helm_values = {
    args = ["--kubelet-insecure-tls"]
  }
}
