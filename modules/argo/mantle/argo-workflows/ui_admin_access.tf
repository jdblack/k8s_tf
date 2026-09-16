# SSO RBAC for the web UI: tokens carrying the '<name>-admin' group (created by oidc_provider) map to
# this SA, bound to the chart's aggregated admin ClusterRole.
resource "kubernetes_service_account_v1" "argo_wf_ui_admin" {
  metadata {
    name      = local.ui_admin_sa
    namespace = var.namespace

    annotations = {
      # `authentik Admins` (built-in superuser) is matched too, so a global admin need not be hand-added
      # per app group. Group membership only reaches the claims at login, so every change costs a re-login.
      "workflows.argoproj.io/rbac-rule"            = "'${var.name}-admin' in groups || '${var.admin_group}' in groups"
      "workflows.argoproj.io/rbac-rule-precedence" = "1"
    }
  }
}

# K8s >= 1.24 no longer auto-provisions a per-SA token secret, and the server needs a stable one to
# read when acting as the user's SA.
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

  # The ClusterRole is chart-rendered, so wait for it on a cold install.
  depends_on = [helm_release.workflows]
}