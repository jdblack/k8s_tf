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
      namespaces = [ var.namespace ]
      schedule = "* * * * *"
      timezone = "UTC"
    }
    description = "AoA deplyment for #{local.project}"
    source_repos = [ "*" ]
    source_namespaces = ["*"]
    destination {
      name = "in-cluster"
      namespace = var.namespace
    }
    destination {
      name = "in-cluster"
      namespace = var.deployment_namespace
    }
    role {
      name = "admin"
      description = "Administrative access for project ${local.project}"
      policies = [
        "p, proj:${local.project}:admin, applications, *, ${local.project}/*, allow",
        "p, proj:${local.project}:admin, logs, *, ${local.project}/*, allow",
      ]
      groups = [
        "argo-cd-admin",
        "argo-cd-admin-${local.project}" 
      ]
    }
  }
}

