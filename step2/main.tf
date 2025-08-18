# External Secrets Operator with Bitwarden Secrets Manager integration
# Apply this AFTER the cluster is created and kubeconfig exists

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "kubernetes" {
  config_path = "../k3s_kubeconfig.yaml"
}

provider "helm" {
  kubernetes {
    config_path = "../k3s_kubeconfig.yaml"
  }
}

# cert-manager for TLS certificate management (required for Bitwarden SDK server)
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.15.3"
  namespace  = "cert-manager"
  create_namespace = true

  set {
    name  = "crds.enabled"
    value = "true"
  }
}

# External Secrets Operator installation via Helm
resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = "0.19.2"
  namespace  = "external-secrets"
  create_namespace = true

  set {
    name  = "bitwarden-sdk-server.enabled"
    value = "true"
  }

  depends_on = [helm_release.cert_manager]
}

# Bitwarden Secrets Manager authentication secret
resource "kubernetes_secret" "bitwarden_credentials" {
  metadata {
    name      = "bitwarden-credentials"
    namespace = "external-secrets"
  }

  data = {
    token = var.bitwarden_access_token
  }

  type = "Opaque"

  depends_on = [helm_release.external_secrets]
}