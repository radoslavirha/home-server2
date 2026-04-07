# ── Cluster identity ────────────────────────────────────────────────────────
variable "cluster_name" {
  type        = string
  description = "Name of the Talos / Kubernetes cluster."
}

# ── Node network ────────────────────────────────────────────────────────────
variable "controlplane_ips" {
  type        = list(string)
  description = "IP addresses of control-plane nodes. First IP is used for bootstrap and as kubeconfig endpoint."

  validation {
    condition = (
      length(var.controlplane_ips) > 0 &&
      length(var.controlplane_ips) == length(distinct(var.controlplane_ips)) &&
      alltrue([for ip in var.controlplane_ips : trimspace(ip) != ""])
    )
    error_message = "controlplane_ips must contain at least one unique, non-empty IP address."
  }
}

variable "worker_ips" {
  type        = list(string)
  description = "IP addresses of worker nodes. Leave empty for a single-node cluster."
  default     = []
}

variable "cluster_vip" {
  type        = string
  description = "Virtual IP for the cluster API endpoint (required for HA, optional for single-node). Leave empty to use the first controlplane IP."
  default     = ""
}

# ── Talos ────────────────────────────────────────────────────────────────────
variable "talos_version" {
  type        = string
  description = "Talos Linux version to target."
  default     = "v1.12.6"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version to target."
  default     = "1.35.2"
}

# Talos Image Factory schematic ID.
# Current schematic includes: siderolabs/iscsi-tools + siderolabs/util-linux-tools
# (required for Longhorn iSCSI support).
# Generate a new schematic at: https://factory.talos.dev
variable "talos_schematic_id" {
  type        = string
  description = "Talos Image Factory schematic ID (controls which system extensions are baked in)."
  default     = "613e1592b2da41ae5e265e8789429f22e121aab91cb4deb6bc3c0b6262961245"
}

# ── Longhorn data disks ──────────────────────────────────────────────────────
# Optional: configure a dedicated SATA SSD for Longhorn storage on specific nodes.
# If a node IP is not listed here, Longhorn stores data on the OS (NVMe) disk.
variable "longhorn_disks" {
  type        = map(string)
  description = "Per-node SATA disk path for Longhorn storage. Key = node IP, value = disk device path."
  default     = {}
  # Example:
  # longhorn_disks = {
  #   "192.168.1.201" = "/dev/sda"
  # }
}
