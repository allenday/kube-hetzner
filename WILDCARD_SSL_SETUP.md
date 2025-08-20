# Wildcard SSL Certificate Setup

This cluster now supports wildcard SSL certificates for `*.staging.cyberstorm.dev` and `*.cyberstorm.dev` domains using DNS-01 challenges with Cloudflare.

## Prerequisites

1. **Cloudflare API Token** with Zone:DNS:Edit permissions for `cyberstorm.dev`
2. **Domain DNS** must be managed by Cloudflare

## Setup Steps

### 1. Add Cloudflare API Token to Bitwarden

First, get your Cloudflare API token:
1. Go to https://dash.cloudflare.com/profile/api-tokens
2. Create token with:
   - **Zone:DNS:Edit** permissions
   - **Zone Resources**: Include specific zone `cyberstorm.dev`
3. Add the token to Bitwarden Secrets Manager with name `CLOUDFLARE_API_TOKEN`
4. Note the Bitwarden secret UUID for the next step

### 2. Setup External Secret for Cloudflare Token

Edit the UUID in the ExternalSecret:
```bash
# Edit examples/cloudflare-external-secret.yaml
# Replace REPLACE_WITH_BITWARDEN_SECRET_UUID with actual UUID
kubectl apply -f examples/cloudflare-external-secret.yaml
```

### 3. Apply Updated ClusterIssuer

```bash
kubectl apply -f examples/letsencrypt-issuer.yaml
```

### 4. Request Wildcard Certificates

Option A - Using Certificate resources:
```bash
kubectl apply -f examples/wildcard-certificate.yaml
```

Option B - Using Ingress annotations:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-app
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    traefik.ingress.kubernetes.io/router.entrypoints: "websecure"
spec:
  tls:
  - hosts:
    - "app.staging.cyberstorm.dev"
    - "api.staging.cyberstorm.dev"
    secretName: app-wildcard-tls
  rules:
  - host: app.staging.cyberstorm.dev
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: example-service
            port:
              number: 80
```

## Verification

Check certificate status:
```bash
# Check ClusterIssuer
kubectl get clusterissuer letsencrypt-prod

# Check certificates
kubectl get certificates -A

# Check certificate details
kubectl describe certificate wildcard-cyberstorm-staging
```

## Supported Domains

The DNS-01 solver will automatically handle:
- `*.staging.cyberstorm.dev` (staging wildcard)
- `*.cyberstorm.dev` (production wildcard)  
- `cyberstorm.dev` (apex domain)
- `staging.cyberstorm.dev` (staging subdomain)

Other domains will fall back to HTTP-01 challenge.

## Troubleshooting

If certificate generation fails:

1. **Check DNS propagation**:
   ```bash
   dig TXT _acme-challenge.staging.cyberstorm.dev
   ```

2. **Check cert-manager logs**:
   ```bash
   kubectl logs -n cert-manager -l app=cert-manager
   ```

3. **Check certificate events**:
   ```bash
   kubectl describe certificate your-cert-name
   kubectl get challenges
   ```

4. **Verify Cloudflare API token**:
   - Token has correct permissions
   - Domain is managed by Cloudflare
   - Token is not expired