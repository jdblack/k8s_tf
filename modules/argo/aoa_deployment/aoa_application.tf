
resource argocd_application deployer {
  metadata {
    name = local.aoa_name
    namespace = var.argo_namespace
  }
  cascade = true
  wait = true
  spec {
    project = local.project
    destination {
      name = "in-cluster"
      namespace = local.namespace
    }
    source {
      repo_url = var.deployer_repo
      path = var.deployer_path
      target_revision = "HEAD"
    }
    sync_policy {
      automated {
        prune = true
        self_heal = true
        allow_empty = true
      }
    }

  }
  lifecycle {
    ignore_changes = [ spec[0].destination ]
  }
  depends_on = [ argocd_project.project ]
}
