#!/usr/bin/env python3
"""Check cluster health and show diagnostic information."""

import subprocess
import sys

def run_kubectl(args, kubeconfig="./k3s_kubeconfig.yaml"):
    """Run kubectl command with specified kubeconfig."""
    cmd = ["kubectl", f"--kubeconfig={kubeconfig}"] + args
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        return result.returncode == 0, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return False, "", "Command timed out"

def check_nodes():
    """Check node status."""
    print("📊 Cluster Status:")
    success, stdout, stderr = run_kubectl(["get", "nodes"])
    if success:
        print(stdout)
    else:
        print(f"❌ Failed to get nodes: {stderr}")

def check_failing_pods():
    """Check for pods that are not running."""
    print("🏃 Checking for failing pods...")
    success, stdout, stderr = run_kubectl([
        "get", "pods", "-A", 
        "--field-selector=status.phase!=Running,status.phase!=Succeeded"
    ])
    
    if success:
        lines = stdout.strip().split('\n')
        if len(lines) <= 1 or (len(lines) == 2 and lines[1].strip() == ""):
            print("All pods are running ✅")
        else:
            print("Non-running pods found:")
            print(stdout)
    else:
        print(f"❌ Failed to check pods: {stderr}")

def check_eso_pods():
    """Check External Secrets Operator pods."""
    print("\n🔐 External Secrets Operator:")
    success, stdout, stderr = run_kubectl(["get", "pods", "-n", "external-secrets"])
    if success:
        print(stdout)
    else:
        print(f"❌ Failed to get ESO pods: {stderr}")

def check_secretstores():
    """Check SecretStores status."""
    print("\n🗝️  SecretStores:")
    success, stdout, stderr = run_kubectl(["get", "secretstores", "-A"])
    if success:
        print(stdout)
    else:
        print(f"❌ Failed to get SecretStores: {stderr}")

def check_externalsecrets():
    """Check ExternalSecrets status."""
    print("\n🔄 ExternalSecrets:")
    success, stdout, stderr = run_kubectl(["get", "externalsecrets", "-A"])
    if success:
        if "No resources found" in stdout:
            print("No ExternalSecrets found")
        else:
            print(stdout)
    else:
        print(f"❌ Failed to get ExternalSecrets: {stderr}")

def main():
    """Run comprehensive cluster health check."""
    print("🩺 Running cluster diagnostics...")
    
    check_nodes()
    print()
    check_failing_pods()
    check_eso_pods()
    check_secretstores()
    check_externalsecrets()
    
    print("\n🏥 Diagnostics complete")

if __name__ == "__main__":
    main()