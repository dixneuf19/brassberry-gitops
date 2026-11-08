# =============================================
# devbox: NixOS VM running the Rex login server
# Config lives in nixos/; the VM pulls main and applies it on its own
# =============================================

locals {
  # Release published by .github/workflows/nixos.yaml; only used when the VM is created
  nixos_base_release = "nixos-base-0000000"
  nixos_base_sha256  = "0000000000000000000000000000000000000000000000000000000000000000"
}

resource "proxmox_virtual_environment_download_file" "nixos_base_image" {
  content_type            = "iso"
  datastore_id            = "local"
  node_name               = var.proxmox_node
  url                     = "https://github.com/dixneuf19/brassberry-gitops/releases/download/${local.nixos_base_release}/nixos-base.qcow2.zst"
  file_name               = "${local.nixos_base_release}.img"
  decompression_algorithm = "zst"
  checksum                = local.nixos_base_sha256
  checksum_algorithm      = "sha256"
}

resource "proxmox_virtual_environment_file" "devbox_user_data" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_node

  source_raw {
    data = "#cloud-config\n${yamlencode({
      hostname = "devbox"
      write_files = [{
        path        = "/var/lib/tailscale/authkey"
        permissions = "0600"
        content     = data.terraform_remote_state.cloud.outputs.devbox_tailscale_auth_key
      }]
    })}"
    file_name = "devbox-user-data.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "devbox" {
  name      = "devbox"
  node_name = var.proxmox_node
  vm_id     = 210

  machine = "q35"
  bios    = "ovmf"

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 8192
  }

  disk {
    datastore_id = proxmox_storage_zfspool.fastpool.id
    file_id      = proxmox_virtual_environment_download_file.nixos_base_image.id
    interface    = "virtio0"
    size         = 64
    discard      = "on"
  }

  efi_disk {
    datastore_id = proxmox_storage_zfspool.fastpool.id
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  initialization {
    datastore_id = proxmox_storage_zfspool.fastpool.id
    ip_config {
      ipv4 {
        address = "192.168.1.50/24"
        gateway = "192.168.1.254"
      }
    }

    dns {
      servers = ["192.168.1.254", "1.1.1.1"]
    }

    user_data_file_id = proxmox_virtual_environment_file.devbox_user_data.id
  }

  agent {
    enabled = true
  }

  on_boot = true
  started = true

  lifecycle {
    ignore_changes = [
      started,
      disk[0].file_id, # a new base image must not replace a running devbox
      initialization,  # the single-use tailscale key rotates once spent
    ]
  }
}
