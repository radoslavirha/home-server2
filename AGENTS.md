# Agent Guidelines — home-server2

Kubernetes home server: Talos Linux + Terraform (bootstrap) + ArgoCD GitOps (day-2).
See [Readme.md](Readme.md) for full architecture, technology stack table, and operational commands.

## Two installation paths

### 1. Terraform-managed (bootstrap / platform)

Core infrastructure installed by Terraform before ArgoCD exists.

| Component | Version pin location |
|-----------|---------------------|
| Talos Linux | `terraform/bootstrap/terraform.tfvars` — `talos_version` |
| Cilium | `terraform/platform/terraform.tfvars` — `cilium_version` |
| Longhorn | `terraform/platform/terraform.tfvars` — `longhorn_version` |
| Gateway API CRDs | `terraform/platform/terraform.tfvars` — `gateway_api_version` |
| ArgoCD | `terraform/apps/terraform.tfvars` — `argocd_chart_version` |

To apply a version change: `cd terraform/<module> && terraform apply -auto-approve`

Helm values overrides are in `helm-values/` and referenced by ArgoCD manifests, **not** passed through Terraform (Terraform only installs ArgoCD itself).

### 2. ArgoCD-managed (GitOps)

All other apps. Each app has an Application CRD in the appropriate subdirectory:
- `argocd-manifests/apps/infra/` — OpenBao, External Secrets Operator
- `argocd-manifests/apps/gateway/` — Traefik, ExternalDNS
- `argocd-manifests/apps/datastores/` — EMQX, MongoDB, InfluxDB2, Loki, Tempo
- `argocd-manifests/apps/observability/` — KubePrometheusStack, Headlamp, Hubble, LonghornUI, Telegraf, OTel
- `argocd-manifests/apps/apps/` — MiotBridge, InteractiveMapFeeder (prod + sandbox)

Version is `targetRevision` in that file. ArgoCD auto-syncs on commit — no manual apply needed.

Helm values overrides live in `helm-values/<name>.yaml` (or subdirectories for environment variants) and are referenced via `$values` multi-source in the Application manifest.

Raw Kubernetes manifests (HTTPRoutes, Secrets, ConfigMaps) live in `k8s-manifests/<app>/` and are also deployed via ArgoCD multi-source.

## Version sync rules — MUST follow

When changing any version:

1. **ArgoCD app** — update `targetRevision` in the Application CRD under `argocd-manifests/apps/<group>/<Name>.yaml`
2. **Terraform component** — update the variable in the relevant `terraform.tfvars`
3. **Always** update the `Version` column in the `## Technology stack` table in [Readme.md](Readme.md)
4. **Always** update the `Upstream values.yaml` link in that same table row to the new version tag

The upstream `values.yaml` links are version-pinned GitHub blob URLs. Tag format varies by chart:
- Most charts: `<chart-name>-<version>` (e.g. `argo-cd-9.4.17`, `traefik-39.0.5`)
- Cilium / Longhorn / Talos: `v<version>` (e.g. `v1.19.2`)
- ExternalDNS: `external-dns-helm-chart-<version>`
- ExternalSecrets: `helm-chart-<version>`

## App documentation rules

- Every app deployed in this cluster **must have a row** in the `## Technology stack` table in [Readme.md](Readme.md).
- Every row must have: version, Artifact Hub link (if the chart is on Artifact Hub), local values file link, and upstream `values.yaml` link.
- If an app has no Helm chart (e.g. Gateway API CRDs, Hubble UI built into Cilium) use `—` for chart-specific columns.
- If an app is removed from the cluster, remove its row from the table.
- OTel Collector has three environment variants (base / production / sandbox) — all three local values files must be linked in a single row.

## Adding a new ArgoCD app

1. Create `argocd-manifests/apps/<group>/<Name>.yaml` — copy an existing Application from the same group as a template.
   Choose the group that matches the app's role: `infra`, `gateway`, `datastores`, `observability`, or `apps`.
2. Add helm values override at `helm-values/<name>.yaml`.
3. Add raw manifests to `k8s-manifests/<name>/` if needed.
4. Add a row to the `## Technology stack` table in [Readme.md](Readme.md) with all required columns.

## Upgrading a chart

1. Update `targetRevision` (ArgoCD) or `*_version` tfvar (Terraform).
2. Update `Version` and `Upstream values.yaml` in the README table.
3. Review diff between old and new upstream `values.yaml` against the local override file to catch removed/renamed keys.

## Secrets

App secrets are stored in **OpenBao** (Vault-compatible) and synced into Kubernetes via **External Secrets Operator**.
See [docs/secrets.md](docs/secrets.md) for the full strategy, KV path layout, initialization ceremony, and backup instructions.

The only remaining SOPS-encrypted file is `secrets/argocd.sops.yaml` — consumed by Terraform for the ArgoCD admin password.

## Operational commands

### Run freely (read-only / safe)

```bash
# Kubernetes
kubectl get <resource>
kubectl describe <resource>
kubectl logs <pod>
kubectl events

# ArgoCD status (no CLI login needed)
kubectl get applications -n argocd
kubectl describe application <name> -n argocd

# Talos
talosctl health
talosctl dashboard
talosctl logs <service>
talosctl get disks

# Terraform
terraform plan
terraform validate
terraform output

# SOPS (decrypt to inspect)
sops --decrypt <file>

# Git (local only)
git status / git diff / git log
```

### Run freely (intended write operations)

```bash
terraform apply -auto-approve      # version bumps and config changes
sops --encrypt --in-place <file>   # encrypting new secrets

# ArgoCD — force refresh or kill stuck sync (safe, only re-applies git state)
kubectl annotate application <name> -n argocd argocd.argoproj.io/refresh=normal
kubectl patch application <name> -n argocd --type merge -p '{"operation": null}'
```

### Ask before running (destructive / irreversible)

```bash
terraform destroy
talosctl upgrade
talosctl reset
talosctl wipe disk
kubectl delete <resource>
rm -rf / any deletion of credentials/
```
