resource "kubernetes_service_account_v1" "argo_wf_ui_admin" {
  metadata {
    name      = local.ui_admin_sa
    namespace = var.namespace

    annotations = {
      "workflows.argoproj.io/rbac-rule"            = "'${var.name}-admin' in groups || '${var.admin_group}' in groups"
      "workflows.argoproj.io/rbac-rule-precedence" = "1"
    }
  }
}

resource "kubernetes_secret_v1" "argo_wf_ui_admin_token" {
  metadata {
    name      = local.ui_admin_token_secret
    namespace = var.namespace
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.argo_wf_ui_admin.metadata[0].name
    }
  }

  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true
}

resource "kubernetes_cluster_role_binding_v1" "argo_wf_ui_admin" {
  metadata {
    name = local.ui_admin_sa
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = local.admin_cluster_role
  }

  subject {
    namespace = var.namespace
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.argo_wf_ui_admin.metadata[0].name
  }

  depends_on = [helm_release.workflows]
}
