terraform {
  required_version = "1.14.6"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.97.0"
    }
  }
}
