


resource helm_release helm {
  name  = var.name
  repository = "https://charts.goauthentik.io"
  chart = "authentik"
  namespace = var.namespace
  values = [yamlencode(local.helm_values)]
}


