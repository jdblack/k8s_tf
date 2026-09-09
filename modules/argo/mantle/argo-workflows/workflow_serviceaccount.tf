# Service account for running workflow pods (executor)
resource "kubernetes_service_account_v1" "argo_wf_workflow_runner" {
  metadata {
    name      = "${var.name}-workflow-runner"
    namespace = var.namespace
  }
  automount_service_account_token = true
}

# Workflow pods run under this SA. With the emissary executor (the only executor
# since Argo v3.4) the executor only needs create/patch on workflowtaskresults to
# report results back to the controller; the controller tracks pod lifecycle
# using its own SA. Keep this Role at the documented minimum and extend it only
# as workflows require, e.g.:
#   rule {
#     api_groups = [""]
#     resources  = ["pods"]
#     verbs      = ["get", "list"]
#   }
resource "kubernetes_role_v1" "argo_wf_workflow_runner" {
  metadata {
    name      = "${var.name}-workflow-runner"
    namespace = var.namespace
  }

  rule {
    api_groups = ["argoproj.io"]
    resources  = ["workflowtaskresults"]
    verbs      = ["create", "patch"]
  }
}

resource "kubernetes_role_binding_v1" "argo_wf_workflow_runner" {
  metadata {
    name      = "${var.name}-workflow-runner"
    namespace = var.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.argo_wf_workflow_runner.metadata[0].name
  }

  subject {
    namespace = var.namespace
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.argo_wf_workflow_runner.metadata[0].name
  }
}
