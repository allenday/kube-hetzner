# Variables for External Secrets and Bitwarden configuration

variable "bitwarden_access_token" {
  description = "Bitwarden Secrets Manager access token"
  type        = string
  sensitive   = true
  default     = ""
}

variable "bitwarden_project_id" {
  description = "Bitwarden Secrets Manager project ID"
  type        = string
  default     = ""
}