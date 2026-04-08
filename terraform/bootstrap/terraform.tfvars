# Adjust these values to match your environment.
# This file is committed to git — it contains NO secrets (only IPs / version pins).

cluster_name       = "server2"
controlplane_ips   = ["192.168.1.201"]
worker_ips         = []
# cluster_vip      = ""   # Set when adding a 2nd controlplane for HA

talos_version      = "v1.12.6"
kubernetes_version = "1.35.2"

# OS install disk selector. Use type for portability, wwid for pinning to a specific disk.
# install_disk_selector = { type = "nvme" }  # ambiguous if multiple NVMe disks present
install_disk_selector = { wwid = "eui.ace42e8170382260" }  # SK hynix BC501 HFM256GDJTNG-8310A (ND88N747210509206)

# Longhorn SATA data disks (optional). Uncomment and fill in when SATA disks are present.
# Discovery: talosctl get disks -n <IP> --insecure
longhorn_disks = {
    # KINGSTON SHFS37A
  "192.168.1.201" = "/dev/disk/by-id/wwn-0x50026b725b05e218" 
}
