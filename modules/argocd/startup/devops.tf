variable project { default = "devops" }
variable branch { default = "main" }

resource argocd_project devops {
  metadata {
    name = var.project
    namespace = var.namespace
  }
  spec {
    description = "Devops related deployments"
    source_repos = [ var.repo ]
    destination {
      server = "https://kubernetes.default.svc"
      namespace = "*"
    }
    sync_window {
      kind = "allow"
      applications = ["*"]
      namespaces = ["*"]
      clusters = [ "*" ]
      duration = "1h"
      schedule = "* * * * *"
      manual_sync = true
    }
  }
}


resource argocd_repository devops_repo {
  repo = var.repo
  username = "git"
  ssh_private_key = var.deploy_key
}

resource argocd_application deployer {
  metadata {
    name = "deployer"
    namespace = var.namespace
  }
  cascade = true
  wait = true
  spec {
    project = var.project
    destination {
      server = "https://kubernetes.default.svc"
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
      }
    }

  }
}

