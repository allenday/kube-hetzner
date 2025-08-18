#!/usr/bin/env python3
"""Wait for Kubernetes cluster to be ready."""

import subprocess
import time
import sys

def run_kubectl(args, kubeconfig="./k3s_kubeconfig.yaml"):
    """Run kubectl command with specified kubeconfig."""
    cmd = ["kubectl", f"--kubeconfig={kubeconfig}"] + args
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        return result.returncode == 0, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return False, "", "Command timed out"

def main():
    """Wait for cluster to be ready."""
    print("⏳ Waiting for cluster to be ready...")
    
    for i in range(1, 31):  # Try for 30 iterations (5 minutes)
        success, stdout, stderr = run_kubectl(["get", "nodes"])
        
        if success:
            print("✅ Cluster is ready")
            print(stdout)
            sys.exit(0)
        
        print(f"Waiting for cluster... ({i}/30)")
        time.sleep(10)
    
    print("❌ Cluster failed to become ready within timeout")
    sys.exit(1)

if __name__ == "__main__":
    main()