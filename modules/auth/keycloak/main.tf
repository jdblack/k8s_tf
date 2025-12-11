


resource helm_release helm {
  name  = var.name
  repository = var.helm_repo
  chart = var.chart
  namespace = var.namespace
  values = [yamlencode(local.helm_values)]
}

output admin_user { value = var.adminuser }
output admin_pass { value = random_password.keycloak_admin.result }
output url        { value = local.url }

