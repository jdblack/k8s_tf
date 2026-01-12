
resource kubernetes_service_account_v1 argo_wf_ui_admin {
  metadata {
    name = "${var.name}-ui-admin"
		namespace = var.namespace

    annotations = {
      "workflows.argoproj.io/rbac-rule"                = "'${var.name}-admin' in groups"
      "workflows.argoproj.io/rbac-rule-precedence"     = "1"
    }
  }
  automount_service_account_token = true  
}


resource kubernetes_secret_v1 argo_wf_ui_admin_token {
  metadata {
    name = "${var.name}-ui-admin.service-account-token"
    namespace = var.namespace
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.argo_wf_ui_admin.metadata.0.name
    }
  }

  type = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true
}



resource kubernetes_cluster_role_binding_v1 argo_wf_ui_admin {
  metadata {
    name = "${var.name}-ui-admin"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "${var.name}-argo-workflows-admin"
  }

  subject {
    namespace = var.namespace
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.argo_wf_ui_admin.metadata[0].name
  }
}


