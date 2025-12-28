
resource kubernetes_namespace_v1 ns {
  metadata {
    name = "kube-security"
  }

}

module trivy {
  source = "../modules/security/trivy"
}

