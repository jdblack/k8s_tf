data kubernetes_secret_v1 initial_admin_pass {
  metadata {
    name = "argocd-initial-admin-secret"
    namespace = var.namespace
  }
  depends_on = [ helm_release.argocd ]
}


output initial_pass {
  value = data.kubernetes_secret_v1.initial_admin_pass.data.password
}

output initial_user {
 value = "admin"
}
