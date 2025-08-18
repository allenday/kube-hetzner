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
kubectl --kubeconfig="$KUBECONFIG" delete clusterissuer bitwarden-certificate-issuer --ignore-not-found=true
kubectl --kubeconfig="$KUBECONFIG" delete clusterissuer bitwarden-bootstrap-issuer --ignore-not-found=true

# Recreate certificates and issuers
echo "Applying certificate configuration..."
kubectl --kubeconfig="$KUBECONFIG" apply -f ../examples/bitwarden-cert-issuers.yaml

# Wait for CA issuer to be ready
echo "Waiting for CA issuer to be ready..."
kubectl --kubeconfig="$KUBECONFIG" wait --for=condition=Ready clusterissuer/bitwarden-certificate-issuer --timeout=60s

echo "Cleanup complete. Ready for terraform apply."