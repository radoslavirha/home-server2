output "cilium_version" {
  description = "Deployed Cilium chart version."
  value       = helm_release.cilium.version
}

output "longhorn_version" {
  description = "Deployed Longhorn chart version."
  value       = helm_release.longhorn.version
}
