variable "namespace" { default = "blender" }
variable "name" { default = "blender" }
variable "samba_user" { default = "jblack" }
variable "domain" { type = string }

# The mDNS/Bonjour advertisement that makes macOS list the share in Finder's
# "Shared"/"Network". Costs one tiny hostNetwork pod (see mdns.tf and README.md);
# set to false to drop both resources -- the share itself is unaffected.
variable "mdns_enabled" {
  type    = bool
  default = true
}

# Pinned by digest, not tag: flungo/avahi publishes no version line (only
# `latest`/`main`), so a tag pin is not reproducible and not reviewable. Bump
# deliberately:
#   curl -s 'https://hub.docker.com/v2/repositories/flungo/avahi/tags/?page_size=5' \
#     | jq -r '.results[] | .name + " " + .digest + " " + .last_updated'
variable "mdns_image" {
  type    = string
  default = "flungo/avahi@sha256:5f22bd9a431373f3008c64dcb05dcf3b6c7ff3e7909be1fe2a2c29a0e39b36a7"
}

# Empty = the scheduler picks. Pin it (e.g.
# { "kubernetes.io/hostname" = "k8sn3" }) if a specific node already runs its own
# mDNS stack, since 5353 is a node-level port for this pod.
variable "mdns_node_selector" {
  type    = map(string)
  default = {}
}
