# Applies the ArgoCD self-management Application once.
# After creation, ArgoCD reconciles this Application from git —
# lifecycle.ignore_changes prevents Terraform from overwriting ArgoCD's state.
resource "kubectl_manifest" "argocd_self_manage" {
  yaml_body         = file("../../argocd-manifests/argocd/application.yaml")
  server_side_apply = true
  depends_on        = [helm_release.argocd]

  lifecycle {
    ignore_changes = [yaml_body]
  }
}

# Applies the App of Apps root Application once.
# All files added to argocd-manifests/apps/ are automatically picked up and
# deployed by ArgoCD without any further Terraform involvement.
resource "kubectl_manifest" "argocd_root_app" {
  yaml_body         = file("../../argocd-manifests/root-app.yaml")
  server_side_apply = true
  depends_on        = [helm_release.argocd]

  lifecycle {
    ignore_changes = [yaml_body]
  }
}
