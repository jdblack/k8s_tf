# Full authority INSIDE the namespace only. The Role is namespaced by construction, so there is
# no path from here to anything outside cline-home.
resource "kubernetes_service_account_v1" "cline" {
  metadata {
    name      = "cline"
    namespace = kubernetes_namespace_v1.home.metadata[0].name
    labels    = local.labels
  }
}

resource "kubernetes_role_v1" "admin" {
  metadata {
    name      = "cline-home-admin"
    namespace = kubernetes_namespace_v1.home.metadata[0].name
    labels    = local.labels
  }

  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["*"]
  }
}

resource "kubernetes_role_binding_v1" "admin" {
  metadata {
    name      = "cline-home-admin"
    namespace = kubernetes_namespace_v1.home.metadata[0].name
    labels    = local.labels
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.cline.metadata[0].name
    namespace = kubernetes_namespace_v1.home.metadata[0].name
  }

  role_ref {
    kind      = "Role"
    name      = kubernetes_role_v1.admin.metadata[0].name
    api_group = "rbac.authorization.k8s.io"
  }
}
