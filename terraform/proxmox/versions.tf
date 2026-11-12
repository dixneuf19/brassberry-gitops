terraform {
  required_version = "1.17.1"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.121.0"
    }
  }
}
