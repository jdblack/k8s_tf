locals {
  group_types = ["admin", "editor", "viewer"]
  top_groups = [for role in local.group_types : "argocd-${role}"]
}

resource "keycloak_group" "top_groups" {
  realm_id = var.realm
  for_each = toset(local.top_groups)
  name = each.value

  lifecycle {
    ignore_changes = [attributes]
  }


}

