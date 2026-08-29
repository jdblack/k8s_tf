variable namespace  { default = "media" }
variable movies_name { default = "movies" }
variable movies_pvc { default = "movies-archive" }
variable plex_claim { default = "" }

variable domain { type = string }
variable cert_authorities  { type = map }
variable domains { type = map }

locals {
  private_ingress_name = "${var.namespace}-private"
  local_issuer = var.cert_authorities["private"]
}