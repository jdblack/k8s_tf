resource argocd_project project {
  metadata {
    name = var.name
    namespace = var.deployment_namespace
  }
  spec {
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

