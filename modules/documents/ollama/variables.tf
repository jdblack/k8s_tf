variable "namespace" { type = string }

# Names the deployment, service and claim in one shot.
variable "name" { type = string }

variable "image" { default = "ollama/ollama" }
variable "image_tag" { default = "0.34.4" }

variable "port" { default = 11434 }

# Pulled by the init container into the models claim; the first boot needs egress.
variable "models" { type = list(string) }

variable "models_size" { default = "20Gi" }
variable "storage_class" { default = "longhorn" }

# Unload after this long idle: resident weights are the whole idle cost of this deployment.
variable "keep_alive" { default = "5m" }

variable "max_loaded_models" { default = 1 }
variable "num_parallel" { default = 1 }

variable "cpu_limit" { default = "3" }
variable "memory_limit" { default = "4Gi" }

# The ollama image's own user.
variable "uid" { default = 1000 }
variable "gid" { default = 1000 }
