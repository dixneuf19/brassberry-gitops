terraform {
  required_version = "1.15.5"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.107.0"
    }
  }
}
