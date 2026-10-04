variable "name" {
  type        = string
  description = "Flow, stage and slug all take this name. The stage is what user settings lists as an enrollment option."
}

variable "slug" {
  type        = string
  default     = null
  description = "Overrides the flow slug; null keeps the name. Slugs are unique, so a second enrollment flow needs its own."
}

variable "title" {
  type        = string
  default     = null
  description = "Heading shown during setup; null derives one from friendly_name."
}

variable "friendly_name" {
  type        = string
  default     = "Passkey"
  description = "Label the user sees for the device they enroll."
}

variable "authentication" {
  type        = string
  default     = "require_authenticated"
  description = "Who may start the setup flow. Enrollment runs from user settings, so it needs a session."
}

variable "user_verification" {
  type        = string
  default     = "preferred"
  description = "How strongly the authenticator must verify the user with a PIN or biometric. `required` forces it wherever the platform supports it."

  validation {
    condition     = contains(["required", "preferred", "discouraged"], var.user_verification)
    error_message = "user_verification must be required, preferred or discouraged."
  }
}

variable "resident_key_requirement" {
  type        = string
  default     = "preferred"
  description = "Whether the credential is discoverable. Only a discoverable credential is offered for username-less login, so lowering this away from preferred or required gives up passkeys for plain second-factor keys."

  validation {
    condition     = contains(["required", "preferred", "discouraged"], var.resident_key_requirement)
    error_message = "resident_key_requirement must be required, preferred or discouraged."
  }
}

variable "authenticator_attachment" {
  type        = string
  default     = null
  description = "Restrict enrollment to a built-in (platform) or removable (cross-platform) authenticator; null lets the browser offer anything."

  validation {
    condition     = var.authenticator_attachment == null || contains(["platform", "cross-platform"], var.authenticator_attachment)
    error_message = "authenticator_attachment must be platform, cross-platform or null."
  }
}

variable "hints" {
  type        = list(string)
  default     = []
  description = "Advisory browser hints, in preference order: security-key, client-device, hybrid. Browsers without support ignore them."

  validation {
    condition     = alltrue([for hint in var.hints : contains(["security-key", "client-device", "hybrid"], hint)])
    error_message = "hints may only contain security-key, client-device or hybrid."
  }
}

variable "device_type_restrictions" {
  type        = list(string)
  default     = []
  description = "AAGUID allowlist from data.authentik_webauthn_device_type; empty accepts any authenticator the browser can register."
}

variable "max_attempts" {
  type        = number
  default     = null
  description = "Failed registration attempts before the stage denies; null applies no limit."
}
