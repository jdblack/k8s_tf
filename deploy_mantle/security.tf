
resource kubernetes_namespace_v1 ns {
  metadata {
    name = "kube-security"
  }

}

module trivy {
  count = 0
  source = "../modules/security/trivy"
}

