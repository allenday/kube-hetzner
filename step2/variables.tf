# Variables for External Secrets configuration

variable "bitwarden_access_token" {
  description = "Bitwarden Secrets Manager access token"
  type        = string
  sensitive   = true
}