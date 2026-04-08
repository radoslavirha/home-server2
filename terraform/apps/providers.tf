# Helm provider reads the kubeconfig written to disk by the bootstrap module.
# Run terraform/bootstrap first, then this module.
provider "helm" {
  # Helm provider v3 uses object-typed kubernetes configuration.
  kubernetes = {
    config_path = var.kubeconfig_path
  }
}

# SOPS provider decrypts secrets using the age private key at
# ~/.config/sops/age/keys.txt (or SOPS_AGE_KEY_FILE env var).
provider "sops" {}

provider "kubectl" {
  config_path       = var.kubeconfig_path
  apply_retry_count = 5
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}
