variable name {
  type = string
}

variable helm_url {
  type = string
}

variable chart  {
  default = null
  type = string
}

variable "namespace" {
  default = null
  type = string
}

locals {
  chart = coalesce(var.chart, var.name)
  namespace = coalesce(var.namespace, var.name)
}
