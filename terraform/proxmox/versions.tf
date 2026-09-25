terraform {
  required_version = "1.16.3"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.114.0"
    }
  }
}
