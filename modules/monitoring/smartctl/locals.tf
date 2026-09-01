locals {
  helm_values = {
    serviceMonitor = {
      enabled = true
    }
  }
}
