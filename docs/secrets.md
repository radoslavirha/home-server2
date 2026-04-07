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

## Future: encrypting secrets with SOPS + age

When you want secrets (e.g. ArgoCD values, application passwords) committed to git:

1. Install [age](https://github.com/FiloSottile/age) and [SOPS](https://github.com/getsops/sops)
2. Generate a key: `age-keygen -o ~/.config/sops/age/keys.txt`
3. Create `.sops.yaml` at the repo root:
   ```yaml
   creation_rules:
     - path_regex: secrets/.*\.yaml$
       age: >-
         <your-age-public-key>
   ```
4. Encrypt a file: `sops -e -i secrets/my-secret.yaml`
5. Decrypt for use: `sops -d secrets/my-secret.yaml`
6. Use [terraform-provider-sops](https://github.com/carlpett/terraform-provider-sops) to consume
   encrypted secrets directly in Terraform.

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
