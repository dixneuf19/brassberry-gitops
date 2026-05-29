terraform {
  required_version = "1.15.4"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.107.0"
    }
  }
}
