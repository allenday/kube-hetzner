# External Secrets Operator with Bitwarden Secrets Manager (Multi-Tenant)

This setup provides a complete, idempotent Terraform configuration for deploying External Secrets Operator with Bitwarden Secrets Manager integration on a Hetzner Cloud K3s cluster. It supports multi-tenant deployments with separate Bitwarden projects for staging and production environments.

## Prerequisites

1. **Hetzner Cloud Account** with API token
2. **Bitwarden Secrets Manager** account with:
   - Access token (BWS_ACCESS_TOKEN) with permissions for both projects
   - Staging Project ID (for staging environment secrets)
   - Production Project ID (for production environment secrets)
3. **Local Tools**:
   - Terraform >= 1.5.0
   - Helm >= 3.0
   - kubectl

## Setup Steps

### 1. Configure Bitwarden Credentials

Edit `terraform.tfvars` with your Bitwarden Secrets Manager credentials:

```hcl
# Bitwarden Secrets Manager configuration
# Use an access token with permissions for both staging and production projects
bitwarden_access_token = "your-bws-access-token-here"
```

### 2. Deploy Infrastructure (Two-Step Process)

**Step 1: Deploy K3s Cluster**

```bash
terraform init
terraform apply -auto-approve
```

This creates:
- K3s cluster on Hetzner Cloud (2 nodes: 1 control plane + 1 agent)
- Load balancer with Traefik ingress controller
- Kubeconfig file (`k3s_kubeconfig.yaml`)

**Step 2: Deploy External Secrets Operator**

```bash
cd step2/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Bitwarden access token
terraform init

# Clean up any previous state (idempotent)
./cleanup.sh

# Deploy ESO with Bitwarden SDK server
terraform apply -auto-approve
cd ..
```

This creates:
- cert-manager for TLS certificate management
- External Secrets Operator with Bitwarden SDK server
- Bitwarden authentication secret
- RBAC permissions for cross-namespace secret access

**Note**: The cleanup script automatically handles certificate creation and RBAC permissions, so no manual steps are needed.

### 3. Setup Multi-Tenant SecretStores (Cluster Admin)

**Important**: Before running the setup, update the project IDs in `examples/bitwarden-secretstore.yaml`:
- Replace `"74546659-9867-4647-b7eb-b33a0105a522"` with your staging project ID
- Replace `"your-production-project-id"` with your production project ID

Run the idempotent setup script:
```bash
./setup-multi-tenant.sh
```

This script handles:
- Creating staging and production namespaces
- Copying Bitwarden credentials to each namespace
- Creating CA bundle secrets for TLS verification
- Applying the namespace-scoped SecretStores

This creates separate SecretStores for staging and production environments, each connected to their respective Bitwarden projects.

### 4. Apply Let's Encrypt ClusterIssuer (Cluster Admin)

Apply the cluster-wide certificate issuer:
```bash
kubectl --kubeconfig=./k3s_kubeconfig.yaml apply -f examples/letsencrypt-issuer.yaml
```

This provides a cluster-wide `letsencrypt-prod` ClusterIssuer that applications can reference for HTTPS certificates.

### 5. Application Deployment (Developer Scope)

**Note**: The following steps are for application developers, not cluster admins.

Create environment-specific ExternalSecrets:
```bash
kubectl --kubeconfig=./k3s_kubeconfig.yaml apply -f examples/validator-external-secret.yaml
```

Each ExternalSecret is scoped to its namespace and can only access secrets from that environment's Bitwarden project.

Applications should create their own Ingress resources with certificate annotations to request SSL certificates from the `letsencrypt-prod` ClusterIssuer.

## Developer Usage

**IMPORTANT**: The API has changed from `BitwardenSecret` to `ExternalSecret`.

**OLD** (no longer works):
```yaml
apiVersion: lerentis.uploadfilter24.eu/v1beta5
kind: BitwardenSecret
```

**NEW** (use this):
```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: your-app-secrets
  namespace: staging  # or production
spec:
  secretStoreRef:
    name: bitwarden-secretstore
    kind: SecretStore
  target:
    name: your-app-secrets
  data:
  - secretKey: SOME_ENV_VAR
    remoteRef:
      key: "your-bitwarden-secret-id"  # UUID from Bitwarden
```

The ExternalSecret will create a regular Kubernetes Secret that your pods can mount as environment variables or volumes.

## File Structure

- `kube.tf` - Main K3s cluster configuration
- `external-secrets.tf` - External Secrets Operator and authentication secret
- `variables.tf` - Variable definitions for Bitwarden credentials
- `terraform.tfvars` - Actual credential values (keep secure!)
- `examples/bitwarden-secretstore.yaml` - SecretStore configuration
- `examples/validator-external-secret.yaml` - Example ExternalSecret

## Verification

### Check Cluster Status
```bash
kubectl --kubeconfig=./k3s_kubeconfig.yaml get nodes
kubectl --kubeconfig=./k3s_kubeconfig.yaml get pods -A
```

### Check External Secrets Operator
```bash
kubectl --kubeconfig=./k3s_kubeconfig.yaml get pods -n external-secrets
kubectl --kubeconfig=./k3s_kubeconfig.yaml get secretstores -A
```

### Check Secret Synchronization
```bash
kubectl --kubeconfig=./k3s_kubeconfig.yaml get externalsecrets -A
kubectl --kubeconfig=./k3s_kubeconfig.yaml get secrets -n eas-staging
kubectl --kubeconfig=./k3s_kubeconfig.yaml describe externalsecret eas-validator-secrets -n eas-staging
```

## Idempotency Test

To verify complete idempotency:

```bash
# Destroy everything
terraform destroy -auto-approve

# Recreate everything (includes External Secrets Operator)
terraform apply -auto-approve

# Reapply SecretStores and ExternalSecrets
kubectl --kubeconfig=./k3s_kubeconfig.yaml apply -f examples/bitwarden-secretstore.yaml
kubectl --kubeconfig=./k3s_kubeconfig.yaml apply -f examples/validator-external-secret.yaml
```

## Security Considerations

1. **Credentials**: Never commit `terraform.tfvars` to version control
2. **Access**: Limit Bitwarden access token permissions to required projects only
3. **Network**: Consider restricting cluster access via firewall rules
4. **RBAC**: Implement proper Kubernetes RBAC for External Secrets access

## Troubleshooting

### External Secrets Pod Not Starting
```bash
kubectl --kubeconfig=./k3s_kubeconfig.yaml logs -n external-secrets -l app.kubernetes.io/name=external-secrets
```

### ExternalSecret Sync Issues
```bash
kubectl --kubeconfig=./k3s_kubeconfig.yaml describe externalsecret eas-validator-secrets -n eas-staging
kubectl --kubeconfig=./k3s_kubeconfig.yaml get events -n eas-staging
```

### Bitwarden SDK Server Issues
```bash
kubectl --kubeconfig=./k3s_kubeconfig.yaml logs -n external-secrets -l app.kubernetes.io/name=bitwarden-sdk-server
```

## Clean Up

To completely remove all resources:

```bash
terraform destroy -auto-approve
```

This will destroy the entire cluster and all associated Hetzner Cloud resources.