terraform {
  required_version = "1.14.7"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.99.0"
    }
  }
}
