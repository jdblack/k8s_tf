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

