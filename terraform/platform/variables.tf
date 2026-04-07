variable "kubeconfig_path" {
  type        = string
  description = "Path to the kubeconfig file written by the bootstrap module."
  default     = "../../credentials/kubeconfig"
}

variable "cilium_version" {
  type        = string
  description = "Cilium Helm chart version."
  default     = "1.19.2"
}

variable "longhorn_version" {
  type        = string
  description = "Longhorn Helm chart version."
  default     = "1.11.1"
}

variable "gateway_api_version" {
  type        = string
  description = "Gateway API CRD release tag (without leading 'v'). See https://github.com/kubernetes-sigs/gateway-api/releases"
  default     = "1.2.1"
}
