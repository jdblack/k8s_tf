output "outpost_name" {
  value = authentik_outpost.outpost.name
}

output "outpost_token" {
  value     = authentik_token.outpost.key
  sensitive = true
}

output "apps" {
  value = {
    for slug, app in authentik_application.app :
    slug => {
      slug          = app.slug
      external_host = var.apps[slug].external_host
    }
  }
}
