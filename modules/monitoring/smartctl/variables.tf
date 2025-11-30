variable name { default = "smartctl" }
variable namespace    {  }


locals {
  smartctl = {
    serviceMonitor = {
      enabled = true
    }
  }
}




