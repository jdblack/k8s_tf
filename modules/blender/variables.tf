variable "namespace" { default = "blender" }
variable "name" { default = "blender" }
variable "samba_user" { default = "jblack" }
variable "domain" { type = string }

# Pinned by tag, not digest: dockurr/samba publishes real release tags, so the pin stays
# readable. Bump deliberately.
variable "samba_image" {
  type    = string
  default = "dockurr/samba:4.23.10"
}

# The mDNS/Bonjour advertisement that makes macOS list the share in Finder. Costs one
# hostNetwork pod (mdns.tf); false drops both resources -- the share is unaffected.
variable "mdns_enabled" {
  type    = bool
  default = true
}

# Pinned by digest, not tag: flungo/avahi publishes no version line (only
# `latest`/`main`), so a tag pin is not reproducible.
variable "mdns_image" {
  type    = string
  default = "flungo/avahi@sha256:5f22bd9a431373f3008c64dcb05dcf3b6c7ff3e7909be1fe2a2c29a0e39b36a7"
}

# Empty = the scheduler picks. Pin it if a node already runs its own mDNS stack, since
# 5353 is a node-level port for this pod.
variable "mdns_node_selector" {
  type    = map(string)
  default = {}
}
