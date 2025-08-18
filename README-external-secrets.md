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

Copy the example configuration and add your credentials:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your Bitwarden Secrets Manager credentials:

```hcl
# Bitwarden Secrets Manager configuration
bitwarden_access_token = "your-bws-access-token-here"
bitwarden_project_id   = "your-project-id-here"
```

### 2. Deploy Complete Infrastructure with Task (Recommended)

```bash
# Initialize with setup wizard
task init

# Deploy everything in one command
task deploy
```

This creates everything in one step:
- K3s cluster on Hetzner Cloud (2 nodes: 1 control plane + 1 agent)  
- Load balancer with Traefik ingress controller
- External Secrets Operator with Bitwarden SDK server
- Certificate infrastructure with proper TLS configuration
- SecretStores configured for staging and production namespaces
- Let's Encrypt ClusterIssuer for automatic HTTPS
- Kubeconfig file (`k3s_kubeconfig.yaml`)

### 3. Alternative: Manual Step-by-Step

If you prefer manual deployment:

```bash
# Deploy infrastructure
terraform init
terraform apply -auto-approve

# Setup SecretStores (update project IDs first)
kubectl --kubeconfig=./k3s_kubeconfig.yaml apply -f examples/bitwarden-secretstore.yaml

# Apply Let's Encrypt ClusterIssuer  
kubectl --kubeconfig=./k3s_kubeconfig.yaml apply -f examples/letsencrypt-issuer.yaml
```

**Important**: Update project IDs in `examples/bitwarden-secretstore.yaml` before applying.

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
    kind: ClusterSecretStore
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

### Common SecretStore Errors

**"failed to append caBundle" Error**:
- Issue: CA certificate bundle is invalid
- Solution: Ensure CA certificate is properly extracted from bootstrap certificate
- Fixed in v1.0.0 with proper CA bundle copying logic

**"Client sent an HTTP request to an HTTPS server" Error**:  
- Issue: Protocol mismatch in bitwardenServerSDKURL
- Solution: Use `https://` instead of `http://` in SecretStore configuration
- Fixed in v1.0.0 by updating examples/bitwarden-secretstore.yaml

**"Resource not found" Error (404)**:
- Issue: Secret UUIDs don't exist in Bitwarden project
- Solution: Use `generate-bitwarden-secrets.py` to list actual secret IDs
- Update application configuration with correct UUIDs from Bitwarden

### Diagnostic Commands

Check SecretStore status:
```bash
kubectl --kubeconfig=./k3s_kubeconfig.yaml get secretstores -A
kubectl --kubeconfig=./k3s_kubeconfig.yaml describe secretstore bitwarden-secretstore -n staging
```

List secrets in Bitwarden project:
```bash
python3 generate-bitwarden-secrets.py --access-token "your-token" --project-id "project-id" --organization-id "org-id"
```

## Clean Up

To completely remove all resources:

```bash
terraform destroy -auto-approve
```

This will destroy the entire cluster and all associated Hetzner Cloud resources.