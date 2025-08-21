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

  wait = false  # Don't wait for pods to be ready - bitwarden-sdk-server needs certificates first
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

# Wait for cert-manager to be fully ready before creating ClusterIssuers
resource "null_resource" "wait_for_cert_manager" {
  provisioner "local-exec" {
    command = <<-EOF
      echo "⏳ Waiting for cert-manager to be fully ready..."
      kubectl --kubeconfig="../k3s_kubeconfig.yaml" wait --for=condition=available --timeout=600s deployment/cert-manager -n cert-manager
      kubectl --kubeconfig="../k3s_kubeconfig.yaml" wait --for=condition=available --timeout=600s deployment/cert-manager-cainjector -n cert-manager
      kubectl --kubeconfig="../k3s_kubeconfig.yaml" wait --for=condition=available --timeout=600s deployment/cert-manager-webhook -n cert-manager
      echo "⏳ Additional wait for webhook to be fully ready..."
      sleep 30
      echo "✅ cert-manager is fully ready"
    EOF
  }
  
  depends_on = [helm_release.external_secrets]
}

# Self-signed ClusterIssuer for bootstrapping Bitwarden certificates
resource "kubernetes_manifest" "bitwarden_bootstrap_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "bitwarden-bootstrap-issuer"
    }
    spec = {
      selfSigned = {}
    }
  }
  
  depends_on = [null_resource.wait_for_cert_manager]
}

# Bootstrap certificate to create CA for Bitwarden
resource "kubernetes_manifest" "bitwarden_bootstrap_certificate" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "bitwarden-bootstrap-certificate"
      namespace = "cert-manager"
    }
    spec = {
      commonName = "cert-manager-bitwarden-tls"
      isCA       = true
      secretName = "bitwarden-ca-bundle"
      subject = {
        organizations = ["external-secrets.io"]
      }
      dnsNames = [
        "bitwarden-sdk-server.external-secrets.svc.cluster.local",
        "external-secrets-bitwarden-sdk-server.external-secrets.svc.cluster.local",
        "localhost"
      ]
      ipAddresses = ["127.0.0.1", "::1"]
      privateKey = {
        algorithm = "RSA"
        encoding  = "PKCS8"
        size      = 2048
      }
      issuerRef = {
        name  = "bitwarden-bootstrap-issuer"
        kind  = "ClusterIssuer"
        group = "cert-manager.io"
      }
    }
  }

  depends_on = [kubernetes_manifest.bitwarden_bootstrap_issuer]
}

# CA-based ClusterIssuer using the bootstrap certificate
resource "kubernetes_manifest" "bitwarden_certificate_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "bitwarden-certificate-issuer"
    }
    spec = {
      ca = {
        secretName = "bitwarden-ca-bundle"
      }
    }
  }

  depends_on = [kubernetes_manifest.bitwarden_bootstrap_certificate]
}

# TLS certificate for bitwarden-sdk-server service
resource "kubernetes_manifest" "bitwarden_tls_certificate" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "bitwarden-tls-certs"
      namespace = "external-secrets"
    }
    spec = {
      secretName = "bitwarden-tls-certs"
      dnsNames = [
        "bitwarden-sdk-server.external-secrets.svc.cluster.local",
        "external-secrets-bitwarden-sdk-server.external-secrets.svc.cluster.local",
        "localhost"
      ]
      ipAddresses = ["127.0.0.1", "::1"]
      privateKey = {
        algorithm = "RSA"
        encoding  = "PKCS8"
        size      = 2048
      }
      issuerRef = {
        name  = "bitwarden-certificate-issuer"
        kind  = "ClusterIssuer"
        group = "cert-manager.io"
      }
    }
  }

  depends_on = [kubernetes_manifest.bitwarden_certificate_issuer]
}