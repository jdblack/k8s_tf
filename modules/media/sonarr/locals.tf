locals {
  fqdn = "${var.name}.${var.domain}"

  helm_values = {
    image = {
      tag             = "4"
      imagePullPolicy = "Always"
    }
    volumes = [
      {
        name = "media"
        persistentVolumeClaim = {
          claimName = var.movies_pvc
        }
      }
    ]
    volumeMounts = [
      {
        name      = "media"
        mountPath = "/media"
      }
    ]
    config = {
      persistence = {
        size = var.config_size
      }
    }
    securityContext = {
      runAsUser  = 1000
      runAsGroup = 1000
    }
  }
}

