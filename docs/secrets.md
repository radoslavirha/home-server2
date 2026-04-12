# Secrets management

## Strategy

This repository contains **no secrets**. The approach for server2:

| Secret type | Where it lives | Committed to git? |
|-------------|---------------|-------------------|
| Talos CA, bootstrap token, machine keys | `terraform/bootstrap/terraform.tfstate` (local, gitignored) | ❌ |
| `credentials/talosconfig` | Written by `terraform apply`, gitignored | ❌ |
| `credentials/kubeconfig` | Written by `terraform apply`, gitignored | ❌ |
| Helm values | `helm-values/*.yaml` — no secrets in these | ✅ |
| Talos patches | `talos/patches/*.yaml` — no secrets | ✅ |
| Terraform variable values | `terraform/bootstrap/terraform.tfvars`, `terraform/platform/terraform.tfvars` — IPs + versions only | ✅ |
| ArgoCD admin password | `secrets/argocd.sops.yaml` — SOPS/age encrypted, read by Terraform at bootstrap | ✅ |
| App secrets (current) | `k8s-manifests/**/*.sops.yaml` — SOPS/age encrypted, decrypted by ArgoCD CMP | ✅ |
| App secrets (target) | OpenBao KV-v2 (`homeserver/*`), synced to Kubernetes by ESO `ExternalSecret` resources | n/a |
| age private key | `{path to}/sops/age/keys.txt` — operator machine only, bootstrapped into cluster once via `kubectl create secret` | ❌ |

## What to back up

The Terraform state files are the **source of truth** for cluster secrets and deployed state.
The `bootstrap` state is the most critical — it holds the Talos CA, bootstrap token, and machine
keys. Without it the cluster must be fully re-created. The `platform` and `apps` states can be
reconstructed by importing existing resources, but backing them up simplifies recovery.

```bash
# Back up all three state files after apply
cp terraform/bootstrap/terraform.tfstate ~/backup/server2-bootstrap-tfstate-$(date +%Y%m%d).json
cp terraform/platform/terraform.tfstate  ~/backup/server2-platform-tfstate-$(date +%Y%m%d).json
cp terraform/apps/terraform.tfstate      ~/backup/server2-apps-tfstate-$(date +%Y%m%d).json
```

If the **bootstrap** state is lost, the cluster must be re-created (`talosctl reset` + full apply).
If only platform/apps state is lost, run `terraform apply` in the affected module to reconcile
Terraform's view with the live cluster.

## OpenBao + External Secrets Operator (ESO)

App secrets are migrating from SOPS to **OpenBao** (open-source Vault fork) + **ESO**.
OpenBao is deployed by `RootInfra` and initialized manually over `kubectl port-forward` during
the first cluster bootstrap. ESO runs a `ClusterSecretStore` that uses Kubernetes auth
(no static tokens) to read from OpenBao and push `Kubernetes Secret` objects into each app namespace.

### KV-v2 path layout (mount: `homeserver/`)

| Path | Keys |
|------|------|
| `homeserver/external-dns` | `api-key` |
| `homeserver/emqx` | `dashboard-username`, `dashboard-password` |
| `homeserver/mongodb` | `root-password` |
| `homeserver/influxdb2` | `admin-password`, `admin-token` |
| `homeserver/grafana` | `admin-user`, `admin-password`, `influxdb2-token` |
| `homeserver/telegraf` | `influxdb2-token`, `mqtt-username`, `mqtt-password` |
| `homeserver/miot-bridge/production` | MongoDB + MQTT credentials |
| `homeserver/miot-bridge/sandbox` | MongoDB + MQTT credentials |

### Adding a new app secret (ESO)

```bash
# 1. Seed the secret in OpenBao (port-forward or from inside the cluster)
vault kv put homeserver/my-app key=VALUE

# 2. Create an ExternalSecret manifest in k8s-manifests/my-app/ExternalSecret.yaml
# 3. Add the ArgoCD Application k8s-manifests source to pick it up
```

Example `ExternalSecret`:
```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: my-app
  namespace: my-app
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: openbao
    kind: ClusterSecretStore
  target:
    name: my-app
  data:
    - secretKey: key
      remoteRef:
        key: homeserver/my-app
        property: key
```

### Verification

```bash
kubectl get clustersecretstore openbao        # Ready=True
kubectl get externalsecret -A                 # all Ready=True
```

## SOPS + age (legacy, kept for ArgoCD admin password only)

The `secrets/argocd.sops.yaml` file remains SOPS-encrypted because it is consumed by Terraform
during bootstrap, before OpenBao or ArgoCD exist. All other `k8s-manifests/**/*.sops.yaml` files
are candidates for migration to ESO `ExternalSecret` resources.



| Path | Consumer | Format |
|------|----------|--------|
| `secrets/*.sops.yaml` | Terraform (`data "sops_file"`) | Plain key: value YAML |
| `k8s-manifests/**/*.sops.yaml` | ArgoCD SOPS CMP sidecar | Full Kubernetes manifest |

### ArgoCD SOPS CMP (Config Management Plugin)

ArgoCD's repo-server runs a sidecar (`sops-cmp`) that decrypts `*.sops.yaml` files during sync. The sidecar:
- gets the `sops` binary via an initContainer that downloads it at startup
- gets the age private key from the `sops-age-key` Kubernetes secret (bootstrapped once via `kubectl create secret`, see Step 3 in the Readme)
- outputs the decrypted manifest YAML, which ArgoCD applies normally

An Application source enables the plugin explicitly:
```yaml
sources:
  - repoURL: https://github.com/radoslavirha/home-server2
    path: k8s-manifests/my-app
    plugin:
      name: sops
```

### Adding a new app secret (ArgoCD-managed)

```bash
# 1. Write the plaintext k8s Secret manifest to a temp file (NOT inside the repo)
cat > /tmp/my-secret.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
  namespace: my-app
type: Opaque
stringData:
  key: REAL_VALUE_HERE
EOF

# 2. Encrypt it in-place to the target path in k8s-manifests/
mkdir -p k8s-manifests/my-app
sops --encrypt /tmp/my-secret.yaml > k8s-manifests/my-app/my-secret.sops.yaml
rm /tmp/my-secret.yaml  # never leave plaintext in the repo

# 3. Commit the encrypted file
git add k8s-manifests/my-app/my-secret.sops.yaml

# 4. Add the sops source to the ArgoCD Application manifest
#    (see argocd-manifests/apps/external-dns.yaml for an example)
```



### Adding a Terraform-consumed secret (e.g. ArgoCD admin password)

1. Create plaintext values file (gitignored by `secrets/*.yaml` pattern):
   ```bash
   echo "my_key: CHANGEME" > secrets/my-app.yaml
   ```
2. Fill in the real value, encrypt, commit:
   ```bash
   sops -e secrets/my-app.yaml > secrets/my-app.sops.yaml
   git add secrets/my-app.sops.yaml
   ```
3. Reference in Terraform:
   ```hcl
   data "sops_file" "my_app" {
     source_file = "../../secrets/my-app.sops.yaml"
   }
   ```

### Key management

The age private key lives at `{path to}/sops/age/keys.txt` (or `$SOPS_AGE_KEY_FILE`). Back it up securely — losing it means all SOPS-encrypted files must be re-created.

The key is bootstrapped into the cluster **once** during initial setup (see Step 3a in the Readme):
```bash
kubectl create secret generic sops-age-key \
  --namespace argocd \
  --from-file=keys.txt="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}" \
  --dry-run=client -o yaml | kubectl apply -f -
```
After that, Terraform never touches it. The secret persists in the cluster independent of any CI/CD tooling.

## Future: remote Terraform backend

For team collaboration or to avoid relying on a local state file, migrate to a remote backend.

**Option A — Terraform Cloud (free tier):**
```hcl
# Add to each module's versions.tf (use a distinct workspace per module)
terraform {
  cloud {
    organization = "<your-org>"
    workspaces {
      name = "home-server2-bootstrap"   # or -platform / -apps
    }
  }
}
```

**Option B — S3-compatible (MinIO on home NAS):**
```hcl
# Add to each module's versions.tf (use a distinct key per module)
terraform {
  backend "s3" {
    bucket                      = "terraform-state"
    key                         = "home-server2/bootstrap/terraform.tfstate"   # or platform / apps
    region                      = "us-east-1"  # dummy for MinIO
    endpoint                    = "http://192.168.1.x:9000"
    force_path_style            = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
  }
}
```
