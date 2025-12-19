
module firewall {
  source = "../network/firewalls/basic_internet"
  namespace = var.namespace
  allow_to_services = false
}

