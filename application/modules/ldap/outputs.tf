data "kubernetes_service" "service" {
  metadata { 
    name = local.res_name
    namespace = var.namespace
  }
  depends_on = [ helm_release.release ]
}

data "kubernetes_secret" "ldap" {
  metadata { 
    name = local.res_name
    namespace = var.namespace
  }
  depends_on = [ helm_release.release ]
}

output "passwords" {
  value = data.kubernetes_secret.ldap.data
}

output "lb" {
  value = data.kubernetes_service.service.load_balancer_ingress.0.ip
}
