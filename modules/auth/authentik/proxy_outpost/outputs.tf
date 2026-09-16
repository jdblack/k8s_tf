output "outpost_name" {
  value = authentik_outpost.outpost.name
}

# The outpost's API token is deliberately not an output: it is consumed by the Secret in
# this module, and nothing else should hold it.
output "apps" {
  value = {
    for slug, app in authentik_application.app :
    slug => {
      slug          = app.slug
      external_host = var.apps[slug].external_host
    }
  }
}
