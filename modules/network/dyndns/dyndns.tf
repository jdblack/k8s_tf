
locals {
  dyndns_host_labels = { name = var.name } 
}

resource "kubernetes_deployment" "dyndns" {
  metadata  {
    namespace = var.namespace
    name = var.name
  }
  timeouts {
    create = "2m"  # Set the create timeout to 10 minutes
  }
  wait_for_rollout = false
  spec {
    replicas = 1
    selector { match_labels = { name = var.name } }
    template {
      metadata { labels = { name = var.name }  }
      spec {
        container {
          name = var.name
          image = "${var.registry}/${var.image}"
          env {
            name = "ZONE"
            value = var.r53_zone
          }
          env {
            name = "FQDN"
            value = var.domain
          }
          env {
            name = "AWS_ACCESS_KEY_ID"
            value = var.AWS_ACCESS_KEY_ID
          }
          env {
            name = "AWS_SECRET_ACCESS_KEY"
            value = var.AWS_SECRET_ACCESS_KEY
          }
          env {
            name = "AWS_REGION"
            value = var.AWS_REGION
          }


        }
      }
    }
  }
}


