# Helm provider reads the kubeconfig written to disk by the bootstrap module.
# Run terraform/bootstrap first, then this module.
provider "helm" {
  # Helm provider v3 uses object-typed kubernetes configuration.
  kubernetes = {
    config_path = var.kubeconfig_path
  }
}
