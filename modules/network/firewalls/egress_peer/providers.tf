terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    # Suffix for name_prefix. Unpinned here like kubernetes: the stacks pin versions.
    random = {
      source = "hashicorp/random"
    }
  }
}
