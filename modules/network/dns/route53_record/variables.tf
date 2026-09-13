variable "zone_id" {
  type        = string
  description = "Literal Route53 hosted zone id (e.g. Z3FM4Y4P2572E4). Pass it from tfvars -- do NOT look it up with data \"aws_route53_zone\", which needs route53:GetHostedZone and is denied to the deployment key."
}

variable "name" {
  type        = string
  description = "Record name (fully qualified), e.g. vaultwarden.linuxguru.net."
}

variable "records" {
  type        = list(string)
  description = "Record values, e.g. [\"192.168.0.100\"]. With allow_overwrite any pre-existing multi-value round-robin set collapses to exactly this list."
}

variable "type" {
  type    = string
  default = "A"
}

variable "ttl" {
  type        = number
  default     = 60
  description = "Seconds. 60 matches the existing *.linuxguru.net wildcard, so changes and drift reverts settle fast."
}

variable "allow_overwrite" {
  type        = bool
  default     = true
  description = <<-EOT
    Take ownership of a pre-existing record with the same name+type instead of
    erroring. This is what makes the record "authoritative": the first apply
    replaces whatever is there, and because the provider refreshes the record
    set on every plan, an out-of-band edit (console, another tool) shows up as
    an in-place update that re-asserts these values.

    Set false only if you want AWS to refuse rather than clobber.
  EOT
}
