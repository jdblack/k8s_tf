locals {
  projects    = ["default", "devops"]
  group_types = ["admin", "editor", "viewer"]

  project_groups = flatten([
    for project in local.projects : [
      for role in local.group_types : {
        group_name = "argocd-${project}-${role}"
        role       = role
      }
    ]
  ])

  parent_groups = [for role in local.group_types : "argocd-${role}"]
}

resource "keycloak_group" "parent_groups" {
  realm_id = var.realm
  for_each = toset(local.parent_groups)

  name = each.value
}

resource "keycloak_group" "project_groups" {
  realm_id  = var.realm
  for_each  = { for group in local.project_groups : group.group_name => group }

  name      = each.key
  parent_id = keycloak_group.parent_groups["argocd-${each.value.role}"].id  # Updated access method
}


