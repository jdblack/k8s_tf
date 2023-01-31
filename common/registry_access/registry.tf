locals {
  user = data.kubernetes_secret.registry_secret.data.name
  pass = data.kubernetes_secret.registry_secret.data.pass
  server = data.kubernetes_secret.registry_secret.data.server
  auth   = base64encode("${local.user}:${local.pass}")
  docker_config_json  = jsonencode({
      "auths" : {
        (local.server) : {
          username = local.user
          password = local.pass
          auth     = local.auth
        }
      }
    })

}


data kubernetes_secret registry_secret  {
  metadata {
    namespace = var.registry_ns
    name = var.registry_secret
  }
}


resource "kubernetes_secret" "image-puller" {
  type = "kubernetes.io/dockerconfigjson"
  metadata {
    namespace = var.dest_ns
    name = var.dest_secret
  }
  data = { ".dockerconfigjson" = local.docker_config_json }
}

