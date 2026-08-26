resource argocd_project project {
  metadata {
    name = local.project
    namespace = var.argo_namespace
  }
  spec {
    sync_window {
      duration = "1h"
      kind = "allow"
      manual_sync = true
      namespaces = [ local.namespace ]
      schedule = "* * * * *"
      timezone = "UTC"
    }
    description = "AoA for ${local.project}"
    source_namespaces = [ var.argo_namespace ]
    source_repos = [ "*" ]
    destination {
      name = "in-cluster"
      namespace = local.namespace
    }
    destination {
      name = "in-cluster"
      namespace = var.argo_namespace
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

