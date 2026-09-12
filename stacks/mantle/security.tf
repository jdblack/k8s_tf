# Namespace for security tooling. The trivy-operator module that used to live
# here (modules/security/trivy) was removed 2026-09; this namespace is kept
# because it is applied infrastructure (present in state), not because any
# workload still requires it. Drop the resource when you want it gone.
resource "kubernetes_namespace_v1" "ns" {
  metadata {
    name = "kube-security"
  }
}

