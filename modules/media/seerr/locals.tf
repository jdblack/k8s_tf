locals {
  fqdn = "${var.name}.${var.domain}"

  helm_values = {
    nameOverride = var.name

    config = {
      persistence = {
        size = var.config_size
      }
    }

    route = {
      main = {
        enabled = false
      }
    }

  }
}
