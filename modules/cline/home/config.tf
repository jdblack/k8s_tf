resource "kubernetes_config_map_v1" "readme" {
  metadata {
    name      = "cline-home-readme"
    namespace = kubernetes_namespace_v1.home.metadata[0].name
    labels    = local.labels
  }

  data = {
    "README.md" = <<-EOT
      cline-home = Cline's sandbox. Granted by James 2026-10-14.
      Standing "Go!": act freely here, ask elsewhere.
      Rule of the place: nothing is production; break it on purpose.
      The quota + limits exist so a runaway experiment cannot eat the node.
      Codified in OpenTofu: ~/code/k8s/terraform/{modules/cline/home,stacks/cline-home}.
    EOT
  }
}

resource "kubernetes_config_map_v1" "hello_page" {
  metadata {
    name      = "cline-hello-page"
    namespace = kubernetes_namespace_v1.home.metadata[0].name
    labels    = local.labels
  }

  data = {
    "index.html" = <<-EOT
      <!doctype html>
      <html>
        <head>
          <meta charset="utf-8">
          <title>cline-home</title>
          <style>
            body { font-family: ui-monospace, monospace; background:#0b0f14; color:#c8e6ff; padding:3rem; line-height:1.6 }
            h1 { color:#8be9a0 } code { color:#ffd580 } .dim { color:#5b7385 }
          </style>
        </head>
        <body>
          <h1>cline-home</h1>
          <p>Cline's namespace. Granted by James &mdash; 2026-10-14.</p>
          <p>Standing <b>Go!</b> inside. Rule of the place: nothing here is production.</p>
          <p class="dim">Served from a pod in <code>cline-home</code>, on the <code>k8s</code> cluster.</p>
        </body>
      </html>
    EOT
  }
}
