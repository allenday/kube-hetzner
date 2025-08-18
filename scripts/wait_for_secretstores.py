#!/usr/bin/env python3
"""Wait for SecretStores to be ready."""

import subprocess
import time
import sys
import json

def run_kubectl(args, kubeconfig="./k3s_kubeconfig.yaml"):
    """Run kubectl command with specified kubeconfig."""
    cmd = ["kubectl", f"--kubeconfig={kubeconfig}"] + args
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        return result.returncode == 0, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return False, "", "Command timed out"

def check_secretstores_ready():
    """Check if SecretStores are ready."""
    success, stdout, stderr = run_kubectl([
        "get", "secretstores", "-A", 
        "-o", "jsonpath={.items[*].status.conditions[?(@.type==\"Ready\")].status}"
    ])
    
    if success and "True" in stdout:
        return True
    return False

def main():
    """Wait for SecretStores to be ready."""
    print("⏳ Waiting for SecretStores to be ready...")
    
    for i in range(1, 31):  # Try for 30 iterations (5 minutes)
        if check_secretstores_ready():
            print("✅ SecretStores are ready")
            # Show current status
            success, stdout, stderr = run_kubectl(["get", "secretstores", "-A"])
            if success:
                print(stdout)
            sys.exit(0)
        
        print(f"Waiting for SecretStores... ({i}/30)")
        time.sleep(10)
    
    print("❌ SecretStores failed to become ready within timeout")
    sys.exit(1)

if __name__ == "__main__":
    main()