variable "namespace" { default = "blender" }
variable "name" { default = "blender" }
variable "samba_user" { default = "jblack" }
variable "domain" { type = string }

# Pinned by tag, not digest: dockurr/samba publishes real release tags, so the pin
# stays readable. Bump deliberately.
variable "samba_image" {
  type    = string
  default = "dockurr/samba:4.23.10"
}

# The mDNS/Bonjour advertisement that makes macOS list the share in Finder's
# "Shared"/"Network". Costs one tiny hostNetwork pod (see mdns.tf); set to false to
# drop both resources -- the share itself is unaffected.
variable "mdns_enabled" {
  type    = bool
  default = true
}

# Pinned by digest, not tag: flungo/avahi publishes no version line (only
# `latest`/`main`), so a tag pin is not reproducible. Bump deliberately.
variable "mdns_image" {
  type    = string
  default = "flungo/avahi@sha256:5f22bd9a431373f3008c64dcb05dcf3b6c7ff3e7909be1fe2a2c29a0e39b36a7"
}

# Empty = the scheduler picks. Pin it if a specific node already runs its own mDNS
# stack, since 5353 is a node-level port for this pod.
variable "mdns_node_selector" {
  type    = map(string)
  default = {}
}
