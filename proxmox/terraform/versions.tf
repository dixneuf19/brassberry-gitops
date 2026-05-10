terraform {
  required_version = "1.15.1"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.106.0"
    }
  }
}
