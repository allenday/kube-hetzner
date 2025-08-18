locals {
  # You have the choice of setting your Hetzner API token here or define the TF_VAR_hcloud_token env
  # within your shell, such as: export TF_VAR_hcloud_token=xxxxxxxxxxx
  # If you choose to define it in the shell, this can be left as is.

  # Your Hetzner token can be found in your Project > Security > API Token (Read & Write is required).
  hcloud_token = ""
}

module "kube-hetzner" {
  providers = {
    hcloud = hcloud
  }
  hcloud_token = var.hcloud_token != "" ? var.hcloud_token : local.hcloud_token

  # Official kube-hetzner module
  source = "kube-hetzner/kube-hetzner/hcloud"

  # SSH Configuration
  ssh_public_key = file("~/.ssh/hetzner_kube_key.pub")
  ssh_private_key = file("~/.ssh/hetzner_kube_key")

  # Networking
  network_region = "eu-central"

  # Control Plane Nodes - minimal setup
  control_plane_nodepools = [
    {
      name        = "control-plane-fsn1"
      server_type = "cx22"
      location    = "fsn1"
      labels      = []
      taints      = []
      count       = 1
    }
  ]

  # Agent Nodes - minimal setup  
  agent_nodepools = [
    {
      name        = "agent-small"
      server_type = "cx22"
      location    = "fsn1"
      labels      = []
      taints      = []
      count       = 1
    }
  ]

  # Use klipper-lb with single NAT IP instead of Hetzner Cloud LoadBalancer
  enable_klipper_metal_lb = "true"

  # Control plane load balancer
  use_control_plane_lb = false

  # Ingress Controller Configuration
  ingress_controller = "traefik"
  
  # Traefik Configuration
  traefik_values = <<-EOT
    deployment:
      replicas: 1
    service:
      type: LoadBalancer
      spec:
        externalTrafficPolicy: "Cluster"
    ports:
      web:
        port: 8000
        exposedPort: 80
      websecure:
        port: 8443
        exposedPort: 443
    additionalArguments:
      - "--providers.kubernetesingress.ingressendpoint.publishedservice=traefik/traefik"
  EOT

  # DNS Configuration
  dns_servers = [
    "1.1.1.1",
    "8.8.8.8",
    "2606:4700:4700::1111",
  ]

  # Base domain for cluster (optional)
  # base_domain = "yourdomain.com"

}

# Note: ClusterIssuer for Let's Encrypt is defined in examples/letsencrypt-issuer.yaml
# Apply it manually after cluster creation: kubectl apply -f examples/letsencrypt-issuer.yaml

provider "hcloud" {
  token = var.hcloud_token != "" ? var.hcloud_token : local.hcloud_token
}

provider "kubernetes" {
  config_path = "./k3s_kubeconfig.yaml"
}

provider "helm" {
  kubernetes = {
    config_path = "./k3s_kubeconfig.yaml"
  }
}

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.51.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
  }
}

output "kubeconfig" {
  value     = module.kube-hetzner.kubeconfig
  sensitive = true
}

output "ingress_public_ipv4" {
  description = "The public IPv4 address of the Hetzner load balancer for ingress"
  value       = module.kube-hetzner.ingress_public_ipv4
}

output "ingress_public_ipv6" {
  description = "The public IPv6 address of the Hetzner load balancer for ingress" 
  value       = module.kube-hetzner.ingress_public_ipv6
}

output "control_plane_public_ipv4" {
  description = "The public IPv4 address of the control plane"
  value       = module.kube-hetzner.control_planes_public_ipv4
}

variable "hcloud_token" {
  sensitive = true
  default   = ""
}
