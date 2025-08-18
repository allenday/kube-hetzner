#!/usr/bin/env python3
"""Interactive configuration wizard for kube-hetzner."""

import os
import shutil

def main():
    """Run the configuration setup wizard."""
    print("⚙️  Configuration Setup Wizard")
    
    # Copy template if needed
    if not os.path.exists("terraform.tfvars"):
        print("Creating terraform.tfvars from template...")
        shutil.copy("terraform.tfvars.example", "terraform.tfvars")
    
    print()
    print("📝 Please edit terraform.tfvars with your credentials:")
    print("   - HETZNER_CLOUD_TOKEN (or set TF_VAR_hcloud_token env var)")
    print("   - bitwarden_access_token")
    print("   - bitwarden_project_id")
    print()
    print("🌐 Get Hetzner token: https://console.hetzner.cloud/ → Security → API Tokens")
    print("🔐 Get Bitwarden token: https://vault.bitwarden.com/ → Settings → Access tokens")
    print()
    
    input("Press Enter when you've updated terraform.tfvars...")
    print("✅ Configuration wizard complete")

if __name__ == "__main__":
    main()