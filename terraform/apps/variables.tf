variable "kubeconfig_path" {
  type        = string
  description = "Path to the kubeconfig file written by the bootstrap module."
  default     = "../../credentials/kubeconfig"
}
