data "kubernetes_service" "grafana" {
  metadata { 
    name = "prometheus-grafana"
    namespace = var.namespace
  }
  depends_on = [ helm_release.release ]
}

data "kubernetes_secret" "grafana" {
  metadata { 
    name = "prometheus-grafana"
    namespace = var.namespace
  }
  depends_on = [ helm_release.release ]
}

#  value = data.kubernetes_service.grafana.load_balancer_ingress.0.ip
output "grafana-lb" {
  value = data.kubernetes_service.grafana.status[0].load_balancer[0]
}

output "grafana-admin" {
  value = data.kubernetes_secret.grafana.data["admin-user"]
}

output "grafana-pass" {
  value = data.kubernetes_secret.grafana.data["admin-password"]
}
