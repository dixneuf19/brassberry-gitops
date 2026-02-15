terraform {
  required_version = "1.14.5"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "= 0.95.0"
    }
  }
}
