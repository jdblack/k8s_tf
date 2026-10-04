variable "name" { type = string }
variable "redirect_uri" { type = string }

variable "client_id" {
  type        = string
  default     = null
  description = "Overrides the id authentik issues; null keeps the application slug. A client whose id is compiled in cannot be changed, so the provider matches it."
}

variable "extra_redirect_uris" {
  type        = list(string)
  default     = []
  description = "Additional authorization redirect URIs; a mobile client's custom scheme cannot be the single one."
}

variable "regex_redirect_uris" {
  type        = list(string)
  default     = []
  description = "Authorization redirect URIs matched as patterns (fullmatch on the whole URI); a client choosing a random loopback port cannot be listed exactly."
}

variable "group_id" {
  type        = string
  default     = null
  description = "authentik group allowed to use the application; null leaves it unbounded."
}

variable "bind_app" {
  type        = bool
  default     = false
  description = "Bind the application to this module's own <name>-admin and <name>-user groups; off leaves the app unbounded unless group_id is set."
}

variable "email_verified" {
  type        = bool
  default     = false
  description = "Replace the built-in email scope mapping (email_verified: false) with one that asserts it true; clients such as pingvin-share reject the false claim."
}

variable "client_type" {
  type        = string
  default     = "confidential"
  description = "OAuth2 client type. A browser app cannot keep a secret, so a frontend doing the code exchange itself needs `public` -- as `confidential` it fails authentication at the token endpoint."

  validation {
    condition     = contains(["confidential", "public"], var.client_type)
    error_message = "client_type must be confidential or public."
  }
}

variable "meta_icon" {
  type    = string
  default = null
}

variable "meta_launch_url" {
  type        = string
  default     = null
  description = "Dashboard launch URL; null leaves the tile present but unlinked."
}

variable "open_in_new_tab" {
  type    = bool
  default = false
}

variable "access_token_validity" {
  type        = string
  default     = "days=7"
  description = "OAuth2 access-token lifetime as an authentik duration. The minutes=10 default signs an idle client out mid-session, since its next in-page call cannot follow the login redirect it gets."
}

variable "refresh_token_validity" {
  type        = string
  default     = "days=30"
  description = "Refresh-token lifetime as an authentik duration; authentik only issues a refresh token to a client that requests the offline_access scope."
}
