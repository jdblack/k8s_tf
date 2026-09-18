variable "zone_id" {
  type        = string
  description = "Literal Route53 hosted zone id (e.g. Z3FM4Y4P2572E4). Pass it from tfvars: data \"aws_route53_zone\" needs route53:GetHostedZone, which the deployment key is denied."
}

variable "name" {
  type        = string
  description = "Fully qualified record name, e.g. vaultwarden.linuxguru.net."
}

variable "records" {
  type        = list(string)
  description = "Record values, e.g. [\"192.168.0.100\"]. With allow_overwrite, a pre-existing multi-value round-robin set collapses to exactly this list."
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
  description = "Take over a pre-existing record with the same name+type instead of erroring. The provider refreshes the record set on every plan, so an out-of-band edit shows up as an in-place update that re-asserts these values; false makes AWS refuse rather than clobber."
}
