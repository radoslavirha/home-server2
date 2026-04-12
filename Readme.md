# Home Server 2

Kubernetes-based home server infrastructure provisioned with Terraform and GitOps (ArgoCD).

## Repository layout

```
home-server2/
├── argocd-manifests/
│   ├── ArgoCD.yaml           ← ArgoCD self-management Application
│   ├── RootApps.yaml         ← App-of-Apps: production + sandbox workloads (applied manually)
│   ├── RootDatastores.yaml   ← App-of-Apps: EMQX, MongoDB, InfluxDB2, Loki, Tempo (applied manually)
│   ├── RootGateway.yaml      ← App-of-Apps: Traefik + ExternalDNS (applied manually)
│   ├── RootInfra.yaml        ← App-of-Apps: OpenBao + ESO (applied manually)
│   ├── RootObservability.yaml ← App-of-Apps: KubePrometheusStack, Telegraf, OTel, UI tools (applied manually)
│   └── apps/
│       ├── apps/             ← root-apps: MiotBridge, InteractiveMapFeeder (prod + sandbox)
│       ├── datastores/       ← root-datastores: EMQX, MongoDB, InfluxDB2, Loki, Tempo
│       ├── gateway/          ← root-gateway: Traefik, ExternalDNS
│       ├── infra/            ← infra: OpenBao, External Secrets Operator
│       └── observability/    ← root-observability: KubePrometheusStack, Headlamp, Hubble, LonghornUI, Telegraf, OTel
├── credentials/              ← GITIGNORED — kubeconfig + talosconfig (written by Terraform)
├── docs/
│   └── secrets.md            ← Secrets strategy, backup guide, SOPS/remote-backend notes
├── helm-values/              ← Helm values files referenced by ArgoCD Applications
├── k8s-manifests/            ← Raw Kubernetes manifests deployed via ArgoCD
├── talos/
│   └── patches/              ← Machine config patches (no secrets — safe to commit)
│       ├── cilium.yaml           Disable default CNI + kube-proxy
│       └── scheduling.yaml       Allow scheduling on control-plane (single-node)
└── terraform/
    ├── bootstrap/            ← Phase 1: Talos machine secrets, config, credentials/
    │   ├── versions.tf
    │   ├── providers.tf
    │   ├── variables.tf
    │   ├── terraform.tfvars
    │   ├── main.tf
    │   └── outputs.tf
    ├── platform/             ← Phase 2: Gateway API CRDs, Cilium, Longhorn
    │   ├── versions.tf
    │   ├── providers.tf
    │   ├── variables.tf
    │   ├── terraform.tfvars
    │   ├── main.tf
    │   └── outputs.tf
    └── apps/                 ← Phase 3: ArgoCD (bootstrapped here, then self-managed)
        ├── versions.tf
        ├── providers.tf
        ├── variables.tf
        ├── terraform.tfvars
        ├── argocd.tf
        └── argocd-self-manage.tf
```

Terraform modules share state via a file convention: `bootstrap/` writes credentials to the
gitignored `credentials/` directory at the repo root. `platform/` and `apps/` read the kubeconfig
from that known path — no `terraform_remote_state` needed.

## Technology stack

| Component | Purpose | Version | Artifact Hub | Local values | Upstream `values.yaml` |
|-----------|---------|---------|-------------|-------------|----------------------|
| [Talos Linux](https://www.talos.dev/) | Immutable Kubernetes OS | v1.12.6 | — | — | — |
| [Cilium](https://docs.cilium.io/) | CNI (eBPF), kube-proxy replacement, Hubble, **Gateway API controller** | 1.19.2 | [cilium](https://artifacthub.io/packages/helm/cilium/cilium) | [cilium.yaml](helm-values/cilium.yaml) | [values.yaml @ v1.19.2](https://github.com/cilium/cilium/blob/v1.19.2/install/kubernetes/cilium/values.yaml) |
| [Gateway API](https://gateway-api.sigs.k8s.io/) | Standard Kubernetes ingress/routing CRDs | v1.2.1 | — | — | — |
| [Longhorn](https://longhorn.io/) | Distributed block storage | 1.11.1 | [longhorn](https://artifacthub.io/packages/helm/longhorn/longhorn) | [longhorn.yaml](helm-values/longhorn.yaml) | [values.yaml @ v1.11.1](https://github.com/longhorn/longhorn/blob/v1.11.1/chart/values.yaml) |
| [ArgoCD](https://argoproj.github.io/cd/) | GitOps continuous delivery (App-of-Apps) | 9.5.0 | [argo-cd](https://artifacthub.io/packages/helm/argo/argo-cd) | [argocd.yaml](helm-values/argocd.yaml) | [values.yaml @ argo-cd-9.5.0](https://github.com/argoproj/argo-helm/blob/argo-cd-9.5.0/charts/argo-cd/values.yaml) |
| [OpenBao](https://openbao.org/) | Secrets management (open-source Vault fork, BSL-free) | 0.27.0 | [openbao](https://artifacthub.io/packages/helm/openbao/openbao) | [openbao.yaml](helm-values/openbao.yaml) | [values.yaml @ openbao-0.27.0](https://github.com/openbao/openbao-helm/blob/openbao-0.27.0/charts/openbao/values.yaml) |
| [External Secrets Operator](https://external-secrets.io/) | Kubernetes-native secrets sync from OpenBao | 2.3.0 | [external-secrets](https://artifacthub.io/packages/helm/external-secrets-operator/external-secrets) | [external-secrets.yaml](helm-values/external-secrets.yaml) | [values.yaml @ helm-chart-2.3.0](https://github.com/external-secrets/external-secrets/blob/helm-chart-2.3.0/deploy/charts/external-secrets/values.yaml) |
| [Traefik](https://traefik.io/) | Ingress / Gateway API proxy, bare-metal load balancer | 39.0.7 | [traefik](https://artifacthub.io/packages/helm/traefik/traefik) | [traefik.yaml](helm-values/traefik.yaml) | [values.yaml @ traefik-39.0.7](https://github.com/traefik/traefik-helm-chart/blob/v39.0.7/traefik/values.yaml) |
| [Hubble UI](https://docs.cilium.io/en/stable/observability/hubble/) | Cilium network observability UI | built into Cilium | — | — | — |
| [Headlamp](https://headlamp.dev/) | Kubernetes web UI | 0.41.0 | [headlamp](https://artifacthub.io/packages/helm/headlamp/headlamp) | [headlamp.yaml](helm-values/headlamp.yaml) | [values.yaml @ headlamp-chart-0.41.0](https://github.com/kubernetes-sigs/headlamp/blob/v0.41.0/charts/headlamp/values.yaml) |
| [Longhorn UI](https://longhorn.io/) | Distributed storage UI | built into Longhorn | — | — | — |
| [External DNS](https://kubernetes-sigs.github.io/external-dns/) | Automatic DNS via UniFi webhook | 1.20.0 | [external-dns](https://artifacthub.io/packages/helm/external-dns/external-dns) | [external-dns.yaml](helm-values/external-dns.yaml) | [values.yaml @ external-dns-helm-chart-1.20.0](https://github.com/kubernetes-sigs/external-dns/blob/external-dns-helm-chart-1.20.0/charts/external-dns/values.yaml) |
| [MongoDB](https://www.mongodb.com/) | Document database | 18.6.24 | [mongodb](https://artifacthub.io/packages/helm/bitnami/mongodb) | [mongodb.yaml](helm-values/mongodb.yaml) | [values.yaml @ mongodb-18.6.24](https://github.com/bitnami/charts/blob/main/bitnami/mongodb/values.yaml) |
| [InfluxDB 2](https://www.influxdata.com/) | Time series database | 2.1.2 | [influxdb2](https://artifacthub.io/packages/helm/influxdata/influxdb2) | [influxdb2.yaml](helm-values/influxdb2.yaml) | [values.yaml @ influxdb2-2.1.2](https://github.com/influxdata/helm-charts/blob/influxdb2-2.1.2/charts/influxdb2/values.yaml) |
| [EMQX](https://www.emqx.io/) | MQTT broker | 5.8.9 | [emqx](https://artifacthub.io/packages/helm/emqx-operator/emqx) | [emqx.yaml](helm-values/emqx.yaml) | [values.yaml @ v5.8.9](https://github.com/emqx/emqx/blob/v5.8.9/deploy/charts/emqx/values.yaml) |
| [Telegraf](https://www.influxdata.com/time-series-platform/telegraf/) | MQTT → InfluxDB ingestion | 1.8.69 | [telegraf](https://artifacthub.io/packages/helm/influxdata/telegraf) | [telegraf.yaml](helm-values/telegraf.yaml) | [values.yaml @ telegraf-1.8.69](https://github.com/influxdata/helm-charts/blob/telegraf-1.8.69/charts/telegraf/values.yaml) |
| [Kube Prometheus Stack](https://github.com/prometheus-operator/kube-prometheus) | Prometheus, Grafana, Alertmanager | 83.4.0 | [kube-prometheus-stack](https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack) | [kube-prometheus-stack.yaml](helm-values/kube-prometheus-stack.yaml) | [values.yaml @ kube-prometheus-stack-83.4.0](https://github.com/prometheus-community/helm-charts/blob/kube-prometheus-stack-83.4.0/charts/kube-prometheus-stack/values.yaml) |
| [Loki](https://grafana.com/oss/loki/) | Log aggregation | 11.4.8 | [loki](https://artifacthub.io/packages/helm/grafana-community/loki) | [loki.yaml](helm-values/loki.yaml) | [values.yaml @ loki-11.4.8](https://github.com/grafana-community/helm-charts/blob/loki-11.4.8/charts/loki/values.yaml) |
| [Tempo](https://grafana.com/oss/tempo/) | Distributed tracing | 2.0.0 | [tempo](https://artifacthub.io/packages/helm/grafana-community/tempo) | [tempo.yaml](helm-values/tempo.yaml) | [values.yaml @ tempo-2.0.0](https://github.com/grafana-community/helm-charts/blob/tempo-2.0.0/charts/tempo/values.yaml) |
| [OTel Collector](https://opentelemetry.io/docs/collector/) | Telemetry pipeline | 0.149.0 | [opentelemetry-collector](https://artifacthub.io/packages/helm/opentelemetry-helm/opentelemetry-collector) | [base](helm-values/opentelemetry-collector.yaml) · [production](helm-values/production/opentelemetry-collector.yaml) · [sandbox](helm-values/sandbox/opentelemetry-collector.yaml) | [values.yaml @ opentelemetry-collector-0.149.0](https://github.com/open-telemetry/opentelemetry-helm-charts/blob/opentelemetry-collector-0.149.0/charts/opentelemetry-collector/values.yaml) |

## Cluster facts

| Property | Value |
|----------|-------|
| Machine | HP EliteDesk 705 G4 Mini |
| RAM | 32 GB |
| CPU | Ryzen PRO 2400GE |
| Install disk | M.2 NVMe 256 GB |
| Storage disk (Longhorn) | SATA SSD 240 GB |
| Node IP | `192.168.1.201` |

### Talos Image Factory schematic

Schematic ID: `613e1592b2da41ae5e265e8789429f22e121aab91cb4deb6bc3c0b6262961245`

Included extensions:
- `siderolabs/iscsi-tools` — required by Longhorn
- `siderolabs/util-linux-tools`

Installer image: `factory.talos.dev/metal-installer/<SCHEMATIC_ID>:<TALOS_VERSION>`

To create/update a schematic: <https://factory.talos.dev>

## Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| [terraform](https://developer.hashicorp.com/terraform/install) | Infrastructure as Code | `brew install terraform` |
| [talosctl](https://www.talos.dev/latest/talos-guides/install/talosctl/) | Talos CLI | `brew install siderolabs/tap/talosctl` |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | Kubernetes CLI (used by Terraform for Gateway API CRDs) | `brew install kubectl` |
| [sops](https://github.com/getsops/sops) | Encrypt/decrypt secrets | `brew install sops` |
| [age](https://github.com/FiloSottile/age) | Age key generation | `brew install age` |
| [vault](https://developer.hashicorp.com/vault/install) | OpenBao CLI (API-compatible) — used for init, unseal, and seeding secrets | `brew install hashicorp/tap/vault` |

**Required environment variable** — Terraform's SOPS provider uses this to find your age private key.
Add to `~/.zshrc` or `~/.zprofile`:

```bash
export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
```

## Applying the cluster

Each module must be initialised and applied in order: `bootstrap` → `platform` → `apps`.

### Step 1 — Bootstrap cluster

```bash
cd terraform/bootstrap
terraform init
terraform apply -auto-approve
```

Wait for the node to become healthy:

```bash
export TALOSCONFIG=$(pwd)/../../credentials/talosconfig
talosctl health
talosctl dashboard
```

### Step 2 — Deploy platform (Cilium, Longhorn, Gateway API)

```bash
cd terraform/platform
terraform init
terraform apply -auto-approve
```

### Step 3 — Deploy ArgoCD

```bash
cd terraform/apps
terraform init
terraform apply -auto-approve
```

This installs ArgoCD via Helm and applies the self-management Application.

### Step 4 — Bootstrap the SOPS age key (once only)

After ArgoCD is running, push the age private key into the cluster so the SOPS CMP sidecar can
decrypt `*.sops.yaml` manifests. This is a one-time manual step — the key is never stored in git
or Terraform state.

```bash
kubectl create secret generic sops-age-key \
  --namespace argocd \
  --from-file=keys.txt="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}" \
  --dry-run=client -o yaml | kubectl apply -f -
```

The `--dry-run=client | apply` pattern makes the command idempotent (safe to re-run).

Then restart the repo-server so it picks up the newly mounted secret:

```bash
kubectl rollout restart deployment argocd-repo-server -n argocd
kubectl rollout status deployment argocd-repo-server -n argocd
```

All `Root*.yaml` are applied manually — continue with the [deployment roots sequence](#bootstrap-sequence-first-install).

> Subsequent runs: `terraform apply -auto-approve` inside whichever module changed. Each module is
> independent — updating a chart version in `platform/` does not touch `bootstrap/`.

## ArgoCD deployment roots

Instead of a single App-of-Apps, the cluster uses **four independent root Applications**, each
pointing to a subdirectory of `argocd-manifests/apps/`. This gives a hard manual gate between
deployment phases — crucial for the initial credential ceremony and for controlled rebuilds where
data must be restored before consumers start.

| Root | Directory | Apps | Applied by |
|------|-----------|------|------------|
| `RootInfra` | `apps/infra/` | OpenBao, External Secrets Operator | Manual |
| `RootGateway` | `apps/gateway/` | Traefik, ExternalDNS | Manual |
| `RootDatastores` | `apps/datastores/` | EMQX, MongoDB, InfluxDB2, Loki, Tempo | Manual |
| `RootObservability` | `apps/observability/` | KubePrometheusStack, Headlamp, Hubble UI, Longhorn UI, Telegraf, OTel Collector ×2 | Manual |
| `RootApps` | `apps/apps/` | MiotBridge ×2, InteractiveMapFeeder ×2 | Manual |

Once a root Application is applied it is **fully GitOps** — ArgoCD auto-syncs every commit.
The manual gate only matters on first install and on rebuilds.

### Bootstrap sequence (first install)

```
Terraform apply  →  ArgoCD healthy
                 →  kubectl apply -f argocd-manifests/RootInfra.yaml
                 →  OpenBao pod running (Sealed state)
                 →  [port-forward + vault operator init  → save 5 unseal keys + root token securely]
                 →  [vault operator unseal  (×3 with different keys)]
                 →  [vault secrets enable -path=homeserver kv-v2]
                 →  [vault auth enable kubernetes + configure role + seed all secrets]
                 →  root infra healthy (ClusterSecretStore Ready)
                 →  kubectl apply -f argocd-manifests/RootGateway.yaml
                 →  root gateway healthy
                 →  kubectl apply -f argocd-manifests/RootDatastores.yaml
                 →  root datastores healthy
                 →  kubectl apply -f argocd-manifests/RootObservability.yaml
                 →  root observability healthy
                 →  kubectl apply -f argocd-manifests/RootApps.yaml
```

### OpenBao initialization (detail)

```bash
# Port-forward to the OpenBao pod
kubectl port-forward -n openbao svc/openbao 8200:8200
export VAULT_ADDR=http://localhost:8200

# Initialize — prints 5 unseal keys and the root token.  SAVE THEM SECURELY.
vault operator init

# Unseal — run three times, each time with a different unseal key from above
vault operator unseal

# Log in with the root token
vault login

# Enable KV-v2 secrets engine at homeserver/
vault secrets enable -path=homeserver kv-v2

# Enable Kubernetes auth so ESO can authenticate without a static token
vault auth enable kubernetes
vault write auth/kubernetes/config kubernetes_host="https://kubernetes.default.svc:443"

# Policy: read-only access to all homeserver secrets
vault policy write read-homeserver - <<'EOF'
path "homeserver/data/*" { capabilities = ["read"] }
EOF

# Role: bind the ESO ServiceAccount to the policy
vault write auth/kubernetes/role/external-secrets \
  bound_service_account_names=external-secrets \
  bound_service_account_namespaces=external-secrets \
  policies=read-homeserver \
  ttl=24h

# Seed a secret example (repeat for each app secret)
vault kv put homeserver/external-dns api-key=CHANGEME
```

### Intra-app waves (resource-level ordering within a single Application)

Inside each Application, individual Kubernetes resources carry sync-wave annotations to control
the deployment order of resources within that app:

| Wave | Resource type | Example |
|------|--------------|---------|
| `-100` | Namespaces | `kube-prometheus-stack/Namespace.yaml` |
| `-50` | ConfigMaps that must precede Helm chart pods | Grafana datasource ConfigMaps |
| `+100` | HTTPRoutes / IngressRouteTCPs | All `**/HTTPRoute.yaml`, `**/IngressRoute*.yaml` |

## Config patches

Patches in `talos/patches/` are applied by Terraform (`terraform/bootstrap/main.tf`) when
generating the machine configuration. They contain no secrets and are safe to commit.

| Patch | Purpose |
|-------|---------|
| `cilium.yaml` | Disables Flannel CNI + kube-proxy (replaced by Cilium) |
| `scheduling.yaml` | Allows pod scheduling on the control-plane (applied only when `worker_ips = []`) |

The installer image and NVMe `diskSelector` are inlined as `yamlencode` directly in
`terraform/bootstrap/main.tf`.

## Disk layout

- **NVMe SSD** — Talos OS + Kubernetes install, selected automatically via `diskSelector: {type: nvme}`. No device path hardcoded.
- **SATA SSD** — optional dedicated Longhorn storage, configured per-node via `longhorn_disks`.

When a node IP is listed in `longhorn_disks`, Terraform applies a Talos patch that formats the disk
and mounts it at `/var/lib/longhorn` (Longhorn's default `defaultDataPath`). If omitted, Longhorn
falls back to the NVMe (fine for single-node or testing).

```hcl
# terraform/bootstrap/terraform.tfvars
longhorn_disks = {
  "192.168.1.201" = "/dev/sda"
}
```

Discover disks before first apply (node must be booted into Talos ISO or installed maintenance mode):

```bash
talosctl get disks --insecure -n 192.168.1.201
# Look for TYPE: nvme (install) and TYPE: ssd/hdd (Longhorn candidate)
```

Wipe secondary disks if needed (e.g. old SSD with invalid format)

```bash
talosctl wipe disk XXX
```

## Credentials

After `terraform/bootstrap` apply, two files are written to `credentials/` (gitignored):

| File | Purpose |
|------|---------|
| `credentials/talosconfig` | Talos client config — used by `talosctl` |
| `credentials/kubeconfig` | Kubernetes client config — used by `kubectl` |

```bash
export TALOSCONFIG=$(pwd)/credentials/talosconfig
export KUBECONFIG=$(pwd)/credentials/kubeconfig
```

## Day-2 operations

### Update chart versions

1. Edit the version in `terraform/platform/terraform.tfvars` (or `apps/terraform.tfvars`)
2. `cd terraform/platform && terraform apply -auto-approve`

### Useful Terraform commands

```bash
# Show outputs
cd terraform/bootstrap && terraform output
cd terraform/platform  && terraform output

# Force-recreate Gateway API CRDs (e.g. version bump)
cd terraform/platform
terraform apply -auto-approve -replace=null_resource.gateway_api_crds

# Refresh kubeconfig (e.g. after cert rotation)
cd terraform/bootstrap
terraform apply -auto-approve \
  -replace=talos_cluster_kubeconfig.this \
  -replace=local_sensitive_file.kubeconfig

# Export kubeconfig using the bootstrap output (absolute path, works from any cwd)
export KUBECONFIG=$(cd terraform/bootstrap && terraform output -raw kubeconfig_path)
kubectl get nodes
```

### Useful talosctl commands

```bash
export TALOSCONFIG=$(pwd)/credentials/talosconfig

talosctl health                  # cluster health
talosctl dashboard               # live dashboard
talosctl logs kubelet            # kubelet logs
talosctl get disks               # list disks

# Upgrade Talos (bumps installer image; node reboots)
talosctl upgrade --image factory.talos.dev/metal-installer/<SCHEMATIC_ID>:<NEW_VERSION>

# Re-apply machine config after a patch change
cd terraform/bootstrap && terraform apply -auto-approve
```

## Destroying the cluster

> ⚠️ Reset the node **before** destroying Terraform state — you need credentials to reach it.

```bash
# 1. Destroy apps and platform Helm releases
cd terraform/apps     && terraform destroy -auto-approve
cd terraform/platform && terraform destroy -auto-approve

# 2. Reset Talos while bootstrap credentials are still valid.
#    Wipes only STATE (config) + EPHEMERAL (k8s data). The Talos OS remains on
#    the NVMe (A/B partitions untouched) — node reboots into maintenance mode,
#    no USB/ISO needed.
export TALOSCONFIG=$(pwd)/credentials/talosconfig
talosctl reset \
  --system-labels-to-wipe STATE \
  --system-labels-to-wipe EPHEMERAL \
  --graceful=false \
  --reboot

# 3. Destroy bootstrap state (removes local credentials/ files too)
cd terraform/bootstrap && terraform destroy -auto-approve
```

Wait for the node to reach maintenance mode (~1 min), then re-apply from Step 1 above.

## Provider versions

| Provider | Source | Version |
|----------|--------|--------|
| Talos | `siderolabs/talos` | `0.11.0-beta.2` |
| Helm | `hashicorp/helm` | `3.1.1` |
| Local | `hashicorp/local` | `2.8.0` |
| Null | `hashicorp/null` | `3.2.4` |

To pin exact versions, commit `.terraform.lock.hcl` after `terraform init`:

```bash
# Remove the lock file lines from .gitignore, then:
git add terraform/bootstrap/.terraform.lock.hcl
git add terraform/platform/.terraform.lock.hcl
git add terraform/apps/.terraform.lock.hcl
git commit -m "chore: pin terraform provider versions"
```

## Secrets

No secrets are committed to this repository.
See [docs/secrets.md](docs/secrets.md) for the full strategy and backup instructions.
