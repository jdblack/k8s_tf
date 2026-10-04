variable "validate_stage_name" {
  type        = string
  default     = "passkey-validate"
  description = "Name of the WebAuthn validation stage the login form offers passkeys from."
}

variable "user_verification" {
  type        = string
  default     = "preferred"
  description = "User-verification requirement for passkey sign-in; mirrors the setup stage."

  validation {
    condition     = contains(["required", "preferred", "discouraged"], var.user_verification)
    error_message = "user_verification must be required, preferred or discouraged."
  }
}

variable "identification_stage_name" {
  type        = string
  default     = "default-authentication-identification"
  description = "Login flow's identification stage the passkey offer hangs off; the built-in one unless a custom authentication flow replaces it."
}
