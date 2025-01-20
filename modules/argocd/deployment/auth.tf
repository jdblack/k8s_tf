locals {
  group_types = ["admin", "editor", "viewer"]

  project_groups = flatten([
    for role in local.group_types : [{
      group_name = "argocd-${local.project}-${role}"
      role       = role
    }]
  ])
}

data "keycloak_group" "parent_group" {
  for_each = toset(local.group_types)
  realm_id = var.realm
  name     = "argocd-${each.key}"
}

resource "keycloak_group" "project_groups" {
  for_each  = { for group in local.project_groups : group.group_name => group }

  name      = each.value.group_name
  realm_id  = var.realm
  parent_id = data.keycloak_group.parent_group[each.value.role].id
}


