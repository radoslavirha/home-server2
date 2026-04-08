variable "kubeconfig_path" {
  type        = string
  description = "Path to the kubeconfig file written by the bootstrap module."
  default     = "../../credentials/kubeconfig"
}

variable "argocd_chart_version" {
  type        = string
  description = "Version of the argo-cd Helm chart. Check latest: helm search repo argo/argo-cd --versions"
}
