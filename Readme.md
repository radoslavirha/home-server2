# Home Server 2

Kubernetes-based home server infrastructure provisioned with Terraform and GitOps (ArgoCD).

## Repository layout

```
home-server2/
├── argocd-manifests/
│   ├── root-app.yaml         ← App-of-Apps root (applied once by Terraform)
│   └── apps/                 ← One file per ArgoCD Application (auto-synced)
│       ├── traefik.yaml
│       ├── hubble.yaml
│       ├── headlamp.yaml
│       ├── longhorn-ui.yaml
│       └── external-dns.yaml
├── credentials/              ← GITIGNORED — kubeconfig + talosconfig (written by Terraform)
├── docs/
│   └── secrets.md            ← Secrets strategy, backup guide, SOPS/remote-backend notes
├── helm-values/              ← Helm values files referenced by ArgoCD Applications
│   ├── argocd.yaml
│   ├── cilium.yaml
│   ├── external-dns.yaml
│   ├── headlamp.yaml
│   ├── longhorn.yaml
│   └── traefik.yaml
├── k8s-manifests/            ← Raw Kubernetes manifests deployed via ArgoCD
│   ├── cilium/
│   │   └── HTTPRoute.yaml        ← Hubble UI route
│   ├── external-dns/
│   │   └── SealedSecret.yaml     ← Unifi credentials (re-seal before apply)
│   └── longhorn/
│       └── HTTPRoute.yaml        ← Longhorn UI route
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
    └── apps/                 ← Phase 3: ArgoCD (root app bootstrapped here)
        ├── versions.tf
        ├── providers.tf
        ├── variables.tf
        ├── terraform.tfvars
        └── main.tf
```

Terraform modules share state via a file convention: `bootstrap/` writes credentials to the
gitignored `credentials/` directory at the repo root. `platform/` and `apps/` read the kubeconfig
from that known path — no `terraform_remote_state` needed.

## Technology stack

### Core infrastructure

| Component | Purpose | Version | Managed by |
|-----------|---------|---------|-----------|
| [Talos Linux](https://www.talos.dev/) | Immutable Kubernetes OS | v1.12.6 | Terraform (`siderolabs/talos`) |
| [Cilium](https://docs.cilium.io/) | CNI (eBPF), kube-proxy replacement, Hubble observability, **Gateway API controller** | 1.19.2 | Terraform (Helm) |
| [Gateway API](https://gateway-api.sigs.k8s.io/) | Standard Kubernetes ingress/routing CRDs | v1.2.1 | Terraform (`kubectl apply`) |
| [Longhorn](https://longhorn.io/) | Distributed block storage | 1.11.1 | Terraform (Helm) |
| [ArgoCD](https://argoproj.github.io/cd/) | GitOps continuous delivery (App-of-Apps) | 9.4.17 (chart) | Terraform (Helm), then self-managed |

### GitOps applications (ArgoCD App-of-Apps)

| Application | Purpose | Hostname | Chart version |
|-------------|---------|----------|--------------|
| [Traefik](https://traefik.io/) | Ingress / Gateway API proxy, bare-metal load balancer | `traefik.server2.home` | 39.0.5 |
| [Hubble UI](https://docs.cilium.io/en/stable/observability/hubble/) | Cilium network observability UI | `hubble.server2.home` | built into Cilium |
| [Headlamp](https://headlamp.dev/) | Kubernetes web UI | `headlamp.server2.home` | 0.41.0 |
| [Longhorn UI](https://longhorn.io/) | Distributed storage UI (HTTPRoute into existing release) | `longhorn.server2.home` | built into Longhorn |
| [External DNS](https://kubernetes-sigs.github.io/external-dns/) | Auto DNS via UniFi webhook | — | 1.20.0 |

## Cluster facts

| Property | Value |
|----------|-------|
| Node IP | `192.168.1.201` |
| API endpoint | `https://192.168.1.201:6443` |
| Install disk | NVMe — selected via `diskSelector: {type: nvme}` |
| Network interface | `eno1` |
| Talos version | `v1.12.6` |
| Kubernetes version | `1.35.2` |
| Cluster type | Single-node (control-plane + worker) |

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

### Step 3 — Deploy apps

```bash
cd terraform/apps
terraform init
terraform apply -auto-approve
```

> Subsequent runs: `terraform apply -auto-approve` inside whichever module changed. Each module is
> independent — updating a chart version in `platform/` does not touch `bootstrap/`.

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
|----------|--------|---------|
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
