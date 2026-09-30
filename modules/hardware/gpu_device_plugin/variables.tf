variable "namespace" { type = string }
variable "image_repository" { type = string }
variable "image_tag" { type = string }
variable "shared_dev_num" { type = number }
variable "node_selector" { type = map(string) }
variable "name" { default = "intel-gpu-plugin" }
