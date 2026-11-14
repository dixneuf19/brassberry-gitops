terraform {
  required_version = "1.17.2"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.120.0"
    }
  }
}
