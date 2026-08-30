locals {
  image = {
    repository = "ghcr.io/haveagitgat/tdarr"
    tag        = "2.58.02"
  }
  node = {
    image = {
      repository = "ghcr.io/haveagitgat/tdarr_node"
      tag        = "2.58.02"
    }
  }
}
