provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = true # Self-signed certificate

  ssh {
    agent = true
  }
}
