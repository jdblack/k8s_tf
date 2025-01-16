
#data "kubernetes_service" "registry" {
#  metadata { 
#    name = join("-", [ var.release_name, "docker-registry" ])
#    namespace = var.namespace
#  }
#  depends_on = [ helm_release.release ]
#}

output "password" {
  value = random_password.password.result
  sensitive=true
}

#output "auth" {
  #value = local.docker_config_json
  #}

