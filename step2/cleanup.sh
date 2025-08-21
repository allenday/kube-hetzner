#!/bin/bash
set -e

# Idempotent cleanup script for step2
# Run this before terraform apply to ensure clean state

KUBECONFIG="../k3s_kubeconfig.yaml"

echo "Cleaning up external-secrets resources..."

# Remove any failed Helm releases (idempotent)
if helm --kubeconfig="$KUBECONFIG" list -n external-secrets -q | grep -q external-secrets; then
    echo "Removing existing external-secrets Helm release..."
    helm --kubeconfig="$KUBECONFIG" uninstall external-secrets -n external-secrets || true
fi

# Delete and recreate namespace (idempotent)
echo "Recreating external-secrets namespace..."
kubectl --kubeconfig="$KUBECONFIG" delete namespace external-secrets --ignore-not-found=true
kubectl --kubeconfig="$KUBECONFIG" create namespace external-secrets

# Clean up any existing certificate issuers (they cache state)
echo "Cleaning up certificate issuers..."
# Only delete ClusterIssuers if cert-manager CRDs exist
if kubectl --kubeconfig="$KUBECONFIG" get crd clusterissuers.cert-manager.io >/dev/null 2>&1; then
    kubectl --kubeconfig="$KUBECONFIG" delete clusterissuer bitwarden-certificate-issuer --ignore-not-found=true
    kubectl --kubeconfig="$KUBECONFIG" delete clusterissuer bitwarden-bootstrap-issuer --ignore-not-found=true
else
    echo "cert-manager CRDs not found, skipping ClusterIssuer cleanup"
fi

# Clean up any existing certificates
echo "Cleaning up certificates..."
# Only delete certificates if cert-manager CRDs exist
if kubectl --kubeconfig="$KUBECONFIG" get crd certificates.cert-manager.io >/dev/null 2>&1; then
    kubectl --kubeconfig="$KUBECONFIG" delete certificate --all -n external-secrets --ignore-not-found=true
else
    echo "cert-manager CRDs not found, skipping certificate cleanup"
fi

echo "Cleanup complete. Terraform will recreate certificates and issuers."