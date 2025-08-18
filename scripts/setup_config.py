#!/usr/bin/env python3
"""Interactive configuration wizard for kube-hetzner."""

import os
import shutil
import sys

def check_config():
    """Check what configuration is already present."""
    needs_config = []
    
    # Check Hetzner token (environment variable is preferred)
    hcloud_token = os.environ.get("TF_VAR_hcloud_token")
    if hcloud_token:
        print("✅ Hetzner Cloud token: Set via environment variable")
    else:
        print("❌ Hetzner Cloud token: Not configured")
        print("   Set TF_VAR_hcloud_token environment variable or add hcloud_token to terraform.tfvars")
        needs_config.append("hcloud_token")
    
    # Check Bitwarden config (environment variables preferred)
    bitwarden_access_token = os.environ.get("TF_VAR_bitwarden_access_token")
    bitwarden_project_id = os.environ.get("TF_VAR_bitwarden_project_id")
    
    if bitwarden_access_token:
        print("✅ Bitwarden access token: Set via environment variable")
    else:
        # Check terraform.tfvars
        tfvars_has_access_token = False
        if os.path.exists("terraform.tfvars"):
            with open("terraform.tfvars", "r") as f:
                content = f.read()
                # Look for non-empty value (ignore commented lines)
                import re
                match = re.search(r'^[^#]*bitwarden_access_token\s*=\s*"([^"]*)"', content, re.MULTILINE)
                if match and match.group(1).strip():
                    tfvars_has_access_token = True
        
        if tfvars_has_access_token:
            print("✅ Bitwarden access token: Set in terraform.tfvars")
        else:
            print("❌ Bitwarden access token: Not configured")
            needs_config.append("bitwarden_access_token")
    
    if bitwarden_project_id:
        print("✅ Bitwarden project ID: Set via environment variable")
    else:
        # Check terraform.tfvars
        tfvars_has_project_id = False
        if os.path.exists("terraform.tfvars"):
            with open("terraform.tfvars", "r") as f:
                content = f.read()
                # Look for non-empty value (ignore commented lines)
                import re
                match = re.search(r'^[^#]*bitwarden_project_id\s*=\s*"([^"]*)"', content, re.MULTILINE)
                if match and match.group(1).strip():
                    tfvars_has_project_id = True
        
        if tfvars_has_project_id:
            print("✅ Bitwarden project ID: Set in terraform.tfvars")
        else:
            print("❌ Bitwarden project ID: Not configured")
            needs_config.append("bitwarden_project_id")
    
    return needs_config

def main():
    """Run the configuration setup wizard."""
    print("⚙️  Configuration Setup Wizard")
    
    # Copy template if needed
    if not os.path.exists("terraform.tfvars"):
        print("📄 Creating terraform.tfvars from template...")
        shutil.copy("terraform.tfvars.example", "terraform.tfvars")
    
    print()
    needs_config = check_config()
    
    if not needs_config:
        print("🎉 All configuration is complete!")
        return
    
    print()
    print("📝 Please configure the following:")
    
    if "hcloud_token" in needs_config:
        print("   - HETZNER_CLOUD_TOKEN in terraform.tfvars (or set TF_VAR_hcloud_token env var)")
        print("     🌐 Get token: https://console.hetzner.cloud/ → Security → API Tokens")
    
    if any("bitwarden" in item for item in needs_config):
        print("   - Bitwarden credentials (via env vars or terraform.tfvars):")
        for item in needs_config:
            if "bitwarden" in item:
                env_var = f"TF_VAR_{item}"
                print(f"     - {item} (or set {env_var})")
        print("     🔐 Get token: https://vault.bitwarden.com/ → Settings → Access tokens")
    
    print()
    print("❌ Configuration incomplete. Please set the required variables and run 'task init' again.")
    sys.exit(1)

if __name__ == "__main__":
    main()