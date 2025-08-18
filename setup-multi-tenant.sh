#!/bin/bash
set -e

# Idempotent setup script for multi-tenant Bitwarden SecretStores
# Run this as cluster admin after step2 terraform completes

KUBECONFIG="./k3s_kubeconfig.yaml"

echo "Setting up multi-tenant Bitwarden SecretStores..."

# Create namespaces (idempotent)
echo "Creating namespaces..."
kubectl --kubeconfig="$KUBECONFIG" create namespace staging --dry-run=client -o yaml | kubectl --kubeconfig="$KUBECONFIG" apply -f -
kubectl --kubeconfig="$KUBECONFIG" create namespace production --dry-run=client -o yaml | kubectl --kubeconfig="$KUBECONFIG" apply -f -

# Copy Bitwarden credentials to each namespace (idempotent)
echo "Copying Bitwarden credentials to staging namespace..."
kubectl --kubeconfig="$KUBECONFIG" get secret bitwarden-credentials -n external-secrets -o yaml | \
  sed 's/namespace: external-secrets/namespace: staging/' | \
  sed '/resourceVersion:/d' | \
  sed '/uid:/d' | \
  kubectl --kubeconfig="$KUBECONFIG" apply -f -

echo "Copying Bitwarden credentials to production namespace..."
kubectl --kubeconfig="$KUBECONFIG" get secret bitwarden-credentials -n external-secrets -o yaml | \
  sed 's/namespace: external-secrets/namespace: production/' | \
  sed '/resourceVersion:/d' | \
  sed '/uid:/d' | \
  kubectl --kubeconfig="$KUBECONFIG" apply -f -

# Copy CA bundle to each namespace for TLS verification (idempotent)
echo "Creating CA bundle secret in staging namespace..."
kubectl --kubeconfig="$KUBECONFIG" get secret bitwarden-ca-certs -n cert-manager -o jsonpath='{.data.ca\.crt}' | \
  base64 -d | \
  kubectl --kubeconfig="$KUBECONFIG" create secret generic bitwarden-ca-bundle --from-file=ca.crt=/dev/stdin -n staging --dry-run=client -o yaml | \
  kubectl --kubeconfig="$KUBECONFIG" apply -f -

echo "Creating CA bundle secret in production namespace..."
kubectl --kubeconfig="$KUBECONFIG" get secret bitwarden-ca-certs -n cert-manager -o jsonpath='{.data.ca\.crt}' | \
  base64 -d | \
  kubectl --kubeconfig="$KUBECONFIG" create secret generic bitwarden-ca-bundle --from-file=ca.crt=/dev/stdin -n production --dry-run=client -o yaml | \
  kubectl --kubeconfig="$KUBECONFIG" apply -f -

# Apply SecretStores (idempotent)
echo "Applying SecretStore configurations..."
kubectl --kubeconfig="$KUBECONFIG" apply -f examples/bitwarden-secretstore.yaml

echo "Multi-tenant setup complete!"
echo ""
echo "Developers can now create ExternalSecrets in staging and production namespaces."