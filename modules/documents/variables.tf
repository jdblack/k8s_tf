variable "namespace" { default = "documents" }
variable "name" { default = "paperless" }

variable "domain" { type = string }
variable "cert_issuer" { type = string }

variable "hostname" {
  type        = string
  default     = null
  description = "Full hostname; default <name>.<domain>."
}

variable "gateway_name" { default = "private" }
variable "gateway_namespace" { default = "kube-network" }

variable "monitoring_namespace" { default = "monitoring" }

variable "image" { default = "ghcr.io/paperless-ngx/paperless-ngx" }

# ghcr tags carry no 'v', unlike the GitHub release names.
variable "image_tag" { default = "3.2.1" }

variable "valkey_image" { default = "valkey/valkey" }
variable "valkey_image_tag" { default = "9-alpine" }

variable "ollama_image" { default = "ollama/ollama" }
variable "ollama_image_tag" { default = "0.34.4" }

variable "storage_class" { default = "longhorn" }
variable "bulk_storage_class" { default = "seaweedfs-csi" }

variable "data_size" { default = "10Gi" }
variable "consume_size" { default = "5Gi" }
variable "media_size" { default = "1Pi" }
variable "media_pv_size" { default = "2Pi" }

# The AI backend: small and multilingual, because the archive is English and Vietnamese and
# inference is CPU-only. The generation model is swappable at any time; only a change of
# embedding model invalidates the vector index.
variable "ollama_models_size" { default = "20Gi" }
variable "ollama_cpu_limit" { default = "3" }
variable "ollama_memory_limit" { default = "4Gi" }

variable "llm_model" { default = "qwen2.5:3b" }
variable "embedding_model" { default = "embeddinggemma" }

# num_ctx for ollama, halving the prefill cost of the 8192 default.
variable "ai_context_size" { default = 4096 }

# RAG-backed suggestions take minutes on CPU, so the 120s default would time out.
variable "ai_request_timeout" { default = 600 }

variable "ai_output_language" { default = "English" }

# Staggered clear of the 03:00 velero schedules.
variable "ai_index_cron" { default = "30 2 * * *" }

variable "admin_user" { default = "admin" }
variable "admin_mail" { default = "jblack@linuxguru.net" }

variable "time_zone" { default = "Asia/Ho_Chi_Minh" }

# The image packs eng/deu/fra/ita/spa only; anything else installs from apt at container start.
variable "ocr_language" { default = "eng+vie" }
variable "ocr_languages" { default = "vie" }

variable "filename_format" { default = "{{ created_year }}/{{ correspondent }}/{{ title }}" }

variable "enable_flower" { default = true }

variable "enable_ai" {
  type        = bool
  default     = false
  description = "Turn on the AI env and the ollama workload once its endpoint exists."
}

variable "oidc_group_id" {
  type        = string
  default     = null
  description = "authentik group allowed to use the application; null leaves it unbounded."
}

variable "icon" {
  type        = string
  default     = null
  description = "authentik icon URL; null guesses the dashboard-icons CDN, empty string for no icon."
}
