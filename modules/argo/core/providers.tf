terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    # Only for the `network/firewalls/{egress,egress_peer}` calls (`random_id` naming); every call site
    # here sets an explicit name, so nothing is created.
    random = {
      source = "hashicorp/random"
    }
  }
}
