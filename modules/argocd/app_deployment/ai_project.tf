resource argocd_project project {
  metadata {
    name = var.name
    namespace = var.deployment_namespace
  }
  spec {
    sync_window {
      duration = "1h"
      kind = "allow"
      manual_sync = true
      namespaces = [ "ai" ]
      schedule = "* * * * *"
      timezone = "UTC"
    }
    description = "AI Deployments"
    source_repos = [ "*" ]
    source_namespaces = ["*"]
    destination {
      name = "in-cluster"
      namespace = "ai"
    }
    destination {
      name = "in-cluster"
      namespace = "devops-argo"
    }
    role {
      name = "admin"
      description = "Administraative access for project ${local.project}"
      policies = [
        "p, proj:${local.project}:admin, applications, *, ${local.project}/*, allow",
        "p, proj:${local.project}:admin, logs, *, ${local.project}/*, allow",
      ]
      groups = [
        "/argocd-admin",
        "/argocd-admin-${local.project}" 
      ]
    }
  }
}

