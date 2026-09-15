# SSO RBAC for the web UI: users whose token carries the '<name>-admin' group (the
# Authentik group created by the oidc_provider module) are mapped to this
# ServiceAccount, bound to the chart's aggregated admin ClusterRole.
resource "kubernetes_service_account_v1" "argo_wf_ui_admin" {
  metadata {
    name      = local.ui_admin_sa
    namespace = var.namespace

    annotations = {
      # `authentik Admins` is the built-in superuser group, matched in addition to
      # the app's own group so a global admin need not be hand-added per app group
      # -- group membership only reaches the claims at login time, so every change
      # costs a re-login.
      "workflows.argoproj.io/rbac-rule"            = "'${var.name}-admin' in groups || '${var.admin_group}' in groups"
      "workflows.argoproj.io/rbac-rule-precedence" = "1"
    }
  }
}

# K8s >= 1.24 no longer auto-provisions a per-SA token secret; the server needs a
# stable secret to read when acting as the user's SA.
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

  # The ClusterRole is rendered by the chart: on a cold install the binding must wait
  # for it.
  depends_on = [helm_release.workflows]
}