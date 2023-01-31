
variable "namespace" {
  type = string
}

variable "release_name" {
  default = "jenkins"
}

variable "volume_name" {
  type = string
  default = "jenkins-claim"
}
