variable jelly_name { default = "jellyfin" }
variable namespace  { default = "media" }
variable movies_name { default = "movies" }
variable media_s3_auth { type = map }
variable domain    { type = string }
variable ingress_class { default  = "private" }
variable cert_issuer {}



