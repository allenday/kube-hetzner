#!/usr/bin/env python3
"""Check for required dependencies and provide installation instructions."""

import subprocess
import sys
import shutil

def check_command(cmd, name, install_url):
    """Check if a command exists and is working."""
    print(f"Checking {name}...")
    
    if not shutil.which(cmd):
        print(f"❌ {name} not found. Install from: {install_url}")
        return False
    
    try:
        result = subprocess.run([cmd, "version"], capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            print(f"✅ {name}: {result.stdout.strip().split()[0]}")
            return True
        else:
            print(f"❌ {name} found but not working properly")
            return False
    except (subprocess.TimeoutExpired, FileNotFoundError):
        print(f"❌ {name} found but not responding")
        return False

def main():
    """Check all required dependencies."""
    print("🔍 Checking dependencies...")
    
    deps = [
        ("terraform", "Terraform", "https://terraform.io/downloads"),
        ("kubectl", "kubectl", "https://kubernetes.io/docs/tasks/tools/"),
        ("helm", "Helm", "https://helm.sh/docs/intro/install/")
    ]
    
    all_good = True
    for cmd, name, url in deps:
        if not check_command(cmd, name, url):
            all_good = False
    
    if all_good:
        print("✅ All dependencies satisfied")
        sys.exit(0)
    else:
        print("❌ Some dependencies are missing")
        sys.exit(1)

if __name__ == "__main__":
    main()