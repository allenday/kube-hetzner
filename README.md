# Hetzner Cloud K3s with External Secrets

A complete, production-ready Kubernetes cluster on Hetzner Cloud with External Secrets Operator and Bitwarden Secrets Manager integration.

## Quick Start (Automated with Task)

### Option A: Golden Path (4 Commands) 🚀

```bash
# Install Task runner (if not already installed)
./install-task.sh

# Golden path - complete cluster in 4 commands:
task init     # 1. Setup wizard (keys, tokens, config)
task deploy   # 2. Deploy complete cluster (~10 min)
task doctor   # 3. Verify everything works
task destroy  # 4. Clean teardown when done
```

That's it! The Task runner handles all dependencies, timing, and configuration automatically.

### Option B: Manual Step-by-Step

If you prefer manual control or don't want to use Task:

#### 1. Prerequisites

- **Hetzner Cloud Account** - [Create account](https://accounts.hetzner.com/)
- **SSH Key Pair** - For cluster access
- **Terraform** >= 1.5.0
- **kubectl** - For cluster management

#### 2. Initial Setup

**Generate SSH Keys** (if you don't have them):
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/hetzner_kube_key
```

**Get Hetzner Cloud API Token**:
1. Go to [Hetzner Cloud Console](https://console.hetzner.cloud/)
2. Select your project
3. Go to Security → API Tokens
4. Generate a new token with Read & Write permissions

**Configure Hetzner Token** (choose one method):

Option A - Environment variable (recommended):
```bash
export TF_VAR_hcloud_token="your-hetzner-api-token-here"
```

Option B - Edit `kube.tf`:
```hcl
locals {
  hcloud_token = "your-hetzner-api-token-here"  # Add your token here
}
```

#### 3. Deploy the Cluster

```bash
# Clone or initialize this repository
git clone <this-repo> # or use existing files
cd kube-hetzner

# Initialize Terraform
terraform init

# Deploy the cluster (takes ~5-10 minutes)
terraform apply
```

This creates:
- **2-node K3s cluster** (1 control plane + 1 worker)
- **Traefik ingress controller** with load balancer
- **External Secrets Operator** with Bitwarden integration
- **kubeconfig file** at `./k3s_kubeconfig.yaml`

#### 4. Verify Cluster

```bash
# Check cluster status
kubectl --kubeconfig=./k3s_kubeconfig.yaml get nodes

# Check all pods
kubectl --kubeconfig=./k3s_kubeconfig.yaml get pods -A

# Get cluster info
terraform output
```

You should see your cluster's public IP addresses for ingress and control plane access.

## Configuration Overview

### Core Files

- **`kube.tf`** - Main cluster configuration based on [kube-hetzner](https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner)
- **`external-secrets.tf`** - External Secrets Operator with Bitwarden integration
- **`variables.tf`** - Variable definitions
- **`terraform.tfvars.example`** - Configuration template

### Default Cluster Specs

- **Control Plane**: 1x Hetzner CX22 (2 vCPU, 4GB RAM) in fsn1
- **Worker Nodes**: 1x Hetzner CX22 (2 vCPU, 4GB RAM) in fsn1  
- **Network**: Private network with klipper-lb load balancer
- **Ingress**: Traefik with automatic HTTPS via Let's Encrypt
- **External Secrets**: Bitwarden Secrets Manager integration

## External Secrets Integration

This setup includes a complete External Secrets Operator configuration with Bitwarden Secrets Manager. See **[README-external-secrets.md](./README-external-secrets.md)** for:

- 🔐 **Bitwarden Secrets Manager** setup
- 🏢 **Multi-tenant configuration** (staging/production)
- 📝 **Developer usage examples**
- 🔄 **Complete idempotency testing**

## Customization

### Scaling the Cluster

Edit `kube.tf` to modify cluster size:

```hcl
# Add more control plane nodes
control_plane_nodepools = [
  {
    name        = "control-plane-fsn1"
    server_type = "cx22"
    location    = "fsn1"
    count       = 3  # Change from 1 to 3 for HA
  }
]

# Scale worker nodes
agent_nodepools = [
  {
    name        = "agent-small"
    server_type = "cx32"  # Upgrade to cx32 for more resources
    location    = "fsn1"
    count       = 3      # Scale to 3 workers
  }
]
```

### Changing Regions

```hcl
# Available regions: eu-central, us-east, us-west
network_region = "us-east"

# Update node locations accordingly
location = "ash"  # Ashburn for us-east
```

### Custom Domain Setup

1. Point your domain's A record to the ingress IP from `terraform output`
2. Update applications to use your domain in Ingress resources
3. Let's Encrypt will automatically provision SSL certificates

See [DOMAIN_SETUP.md](./DOMAIN_SETUP.md) if it exists for detailed domain configuration.

## Task-Based Operations

### Common Commands
```bash
task --list          # Show all available commands
task init            # Initialize project with setup wizard
task deploy          # Deploy complete cluster (infrastructure + ESO + secretstores)
task doctor          # Health check and diagnostics
task destroy         # Clean teardown with confirmation
task logs            # Show External Secrets logs
```

### Advanced Operations  
```bash
task check-deps      # Verify tool dependencies
task setup-keys      # Generate SSH keys if missing
task setup-config    # Interactive configuration wizard
task reset           # Reset configuration and start over
```

## Maintenance

### Backup
```bash
# Automated backup
task backup

# Manual backup
cp terraform.tfstate terraform.tfstate.backup
cp k3s_kubeconfig.yaml ~/.kube/config-hetzner
```

### Updates
```bash
# Task-based update
task upgrade

# Manual update
terraform plan
terraform apply
kubectl --kubeconfig=./k3s_kubeconfig.yaml rollout restart deployment -n external-secrets
```

### Monitoring
```bash
# Task-based monitoring  
task doctor

# Manual monitoring
kubectl --kubeconfig=./k3s_kubeconfig.yaml get nodes
kubectl --kubeconfig=./k3s_kubeconfig.yaml top nodes
kubectl --kubeconfig=./k3s_kubeconfig.yaml get ingress -A
```

## Cost Optimization

**Default monthly cost**: ~€20-30/month for 2x CX22 instances + load balancer

**Optimization options**:
- Use CX21 instances for development: ~€10-15/month
- Enable cluster autoscaling for variable workloads
- Use shared CPX instances for cost-effective scaling

## Cleanup

```bash
# Destroy everything
terraform destroy

# This removes all Hetzner Cloud resources and stops billing
```

## Troubleshooting

### Common Issues

**Terraform timeout during apply**:
```bash
# Increase timeout in provider configuration
# Or retry: terraform apply
```

**SSH connection issues**:
```bash
# Verify SSH key path in kube.tf
# Check Hetzner Cloud firewall rules
```

**External Secrets not working**:
- See [README-external-secrets.md](./README-external-secrets.md) troubleshooting section
- Check Bitwarden token permissions
- Verify project IDs

### Getting Help

1. Check [kube-hetzner documentation](https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner)
2. Review Terraform and kubectl logs
3. Check Hetzner Cloud console for infrastructure issues

## Architecture

This setup is based on the excellent [kube-hetzner](https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner) Terraform module with additional External Secrets integration for production-ready secret management.

**Key differences from vanilla kube-hetzner**:
- 🔐 External Secrets Operator pre-installed
- 🔑 Bitwarden Secrets Manager integration  
- 🏢 Multi-tenant secret management
- 📋 Complete deployment documentation
- 🛡️ Security-first configuration with gitignore

## Security

- ✅ SSH key-based authentication only
- ✅ Private container registry support
- ✅ Network policies ready
- ✅ Secrets managed via External Secrets Operator
- ✅ No hardcoded secrets in version control
- ✅ Let's Encrypt automatic HTTPS

## License

This configuration builds on [kube-hetzner](https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner) (MIT License).