# Applies the ArgoCD self-management Application once.
# After creation, ArgoCD reconciles this Application from git —
# lifecycle.ignore_changes prevents Terraform from overwriting ArgoCD's state.
resource "kubectl_manifest" "argocd_self_manage" {
  yaml_body         = file("../../argocd-manifests/ArgoCD.yaml")
  server_side_apply = true
  depends_on        = [helm_release.argocd]

  lifecycle {
    ignore_changes = [yaml_body]
  }
}
