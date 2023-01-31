resource "kubernetes_role" "cinc" {
  metadata {
    namespace = var.namespace
    name = local.cinc_name
  }

  rule {
    api_groups     = [""]
    resources      = ["secrets"]
    verbs          = ["get", "create", "update", "patch"]
  }
}

resource "kubernetes_role_binding" "cinc" {
  metadata {
    name      = local.cinc_name
    namespace = var.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = local.cinc_name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = var.namespace
  }
}

