# SSO RBAC for the web UI: users whose token carries the '<name>-admin' group
# (the Authentik group created by the oidc_provider module) are mapped to this
# ServiceAccount, which is bound to the chart's aggregated admin ClusterRole
# (local.admin_cluster_role).
resource "kubernetes_service_account_v1" "argo_wf_ui_admin" {
  metadata {
    name      = local.ui_admin_sa
    namespace = var.namespace

    annotations = {
      "workflows.argoproj.io/rbac-rule"            = "'${var.name}-admin' in groups"
      "workflows.argoproj.io/rbac-rule-precedence" = "1"
    }
  }
}

# K8s >= 1.24 no longer auto-provisions a per-SA token secret; create one
# explicitly so the server has a stable secret to read when acting as the user's
# SA.  It is listed on the server's sso.rbac.secretWhitelist in locals.tf.
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

  # The referenced ClusterRole is rendered by the Helm chart; make sure it
  # exists before the binding is created on a cold install.
  depends_on = [helm_release.workflows]
}