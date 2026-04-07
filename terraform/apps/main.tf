# ── Applications ─────────────────────────────────────────────────────────────
# Add Helm releases here (ArgoCD, cert-manager, etc.)
#
# Example — ArgoCD:
#
# resource "helm_release" "argocd" {
#   name             = "argocd"
#   repository       = "https://argoproj.github.io/argo-helm"
#   chart            = "argo-cd"
#   version          = var.argocd_version
#   namespace        = "argocd"
#   create_namespace = true
#   wait             = true
#   timeout          = 300
# }
