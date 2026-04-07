# Adjust these values to match your environment.
# This file is committed to git — it contains NO secrets (only IPs / version pins).

cluster_name       = "server2"
controlplane_ips   = ["192.168.1.201"]
worker_ips         = []
# cluster_vip      = ""   # Set when adding a 2nd controlplane for HA

talos_version      = "v1.12.6"
kubernetes_version = "1.35.2"

# Longhorn SATA data disks (optional). Uncomment and fill in when SATA disks are present.
# Discovery: talosctl get disks -n <IP> --insecure
# longhorn_disks = {
#   "192.168.1.201" = "/dev/sda"
# }
