resource argocd_project devops {
  metadata {
    name = "devops"
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
    }
    role {
      name = "admin"
      description = "Administraative access for devops"
      policies = [
        "p, proj:devops:admin, applications, *, devops/*, allow",
        "p, proj:devops:admin, applicationsets, *, devops/*, allow",
        "p, proj:devops:admin, logs, *, devops/*, allow",
      ]
      groups = [
        "/argocd-admin",
        "/argocd-admin-devops" 
      ]
    }
  }
}


