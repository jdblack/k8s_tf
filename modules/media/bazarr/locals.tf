locals {
  fqdn = "${var.name}.${var.domain}"

  helm_values = {
    image = {
      pullPolicy = "Always"
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
    # 1000:1000 across the arrs sharing the `media` PVC -- see README.md.
    securityContext = {
      runAsUser  = 1000
      runAsGroup = 1000
    }
  }
}
