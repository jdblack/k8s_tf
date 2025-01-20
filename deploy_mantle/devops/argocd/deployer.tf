resource argocd_application deployer {
  metadata {
    name = "deployer"
    namespace = var.namespace
  }
  cascade = true
  wait = true
  spec {
    project = "devops"
    destination {
      name = "in-cluster"
      namespace = var.namespace
    }
    source {
      repo_url = var.repo
      path = "deployments"
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
  depends_on = [ argocd_project.devops ]
}
