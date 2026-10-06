# A launcher-only application: no SSO provider is attached, so authentik never sits in
# front of the app -- the tile is just a link to the app's own login. The bindings are
# therefore the whole access model; they decide who sees the tile.
resource "authentik_application" "app" {
  name            = var.name
  slug            = var.slug
  meta_launch_url = var.launch_url
  meta_icon       = var.icon
  open_in_new_tab = var.open_in_new_tab
}

resource "authentik_group" "admin" {
  name = "${var.name}-admin"
}

resource "authentik_group" "user" {
  name = "${var.name}-user"
}

resource "authentik_policy_binding" "own_groups" {
  for_each = {
    admin = authentik_group.admin.id
    user  = authentik_group.user.id
  }

  target = authentik_application.app.uuid
  group  = each.value
  order  = 0
}
