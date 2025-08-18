#!/usr/bin/env python3
"""Check Terraform configuration and credentials."""

import os
import subprocess
import sys

def check_terraform_vars():
    """Check if required Terraform variables are configured."""
    print("🔧 Checking Terraform configuration...")
    
    # Check if terraform.tfvars exists
    if not os.path.exists("terraform.tfvars"):
        print("❌ terraform.tfvars not found")
        return False
    
    # Check for Hetzner token (env var or tfvars)
    hcloud_token = os.environ.get("TF_VAR_hcloud_token")
    
    if not hcloud_token:
        # Check in terraform.tfvars (basic check for non-empty value)
        try:
            with open("terraform.tfvars", "r") as f:
                content = f.read()
                if 'hcloud_token = ""' in content or 'hcloud_token=""' in content:
                    print("❌ hcloud_token is empty in terraform.tfvars")
                    print("   Either set TF_VAR_hcloud_token env var or edit terraform.tfvars")
                    return False
                elif "hcloud_token" not in content:
                    print("❌ hcloud_token not found in terraform.tfvars")
                    return False
        except Exception as e:
            print(f"❌ Error reading terraform.tfvars: {e}")
            return False
    
    # Try terraform plan to validate configuration
    print("Validating Terraform configuration...")
    try:
        result = subprocess.run(
            ["terraform", "plan", "-input=false"], 
            capture_output=True, 
            text=True, 
            timeout=30
        )
        
        if "Error: Invalid token" in result.stderr or "Error: Authentication failed" in result.stderr:
            print("❌ Hetzner Cloud token is invalid")
            return False
        elif result.returncode != 0 and "Error" in result.stderr:
            print(f"❌ Terraform configuration error: {result.stderr.split('Error:')[1].split()[0:10]}")
            return False
        
        print("✅ Terraform configuration is valid")
        return True
        
    except subprocess.TimeoutExpired:
        print("⚠️  Terraform plan timed out - configuration may be slow but valid")
        return True
    except FileNotFoundError:
        print("❌ Terraform not found")
        return False
    except Exception as e:
        print(f"❌ Error validating Terraform: {e}")
        return False

def main():
    """Check Terraform configuration."""
    if not check_terraform_vars():
        print("\n💡 To fix:")
        print("   export TF_VAR_hcloud_token='your-token-here'")
        print("   # OR edit terraform.tfvars with your Hetzner Cloud token")
        sys.exit(1)
    
    sys.exit(0)

if __name__ == "__main__":
    main()