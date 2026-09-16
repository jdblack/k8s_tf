terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    # Only for `network/firewalls/egress` (the random_id suffix it would use for a generated
    # name; this call site sets an explicit name, so nothing is created). Same as blender.
    random = {
      source = "hashicorp/random"
    }
  }
}
