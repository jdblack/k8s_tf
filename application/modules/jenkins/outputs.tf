data "kubernetes_service" "jenkins" {
  metadata { 
    name = var.release_name
    namespace = var.namespace
  }
  depends_on = [ helm_release.release ]
}

output "password" {
  value = random_password.password.result
}

output "lb" {
  value = data.kubernetes_service.jenkins.load_balancer_ingress.0.ip
}

