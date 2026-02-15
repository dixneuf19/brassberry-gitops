# =============================================
# Proxmox Storage Definitions
# These register the ZFS pools (created by Ansible) as Proxmox storage
# =============================================

import {
  to = proxmox_virtual_environment_storage_zfspool.fastpool
  id = "fastpool"
}

import {
  to = proxmox_virtual_environment_storage_directory.tank_backups
  id = "tank-backups"
}

import {
  to = proxmox_virtual_environment_storage_directory.tank_iso
  id = "tank-iso"
}

import {
  to = proxmox_virtual_environment_storage_directory.tank_templates
  id = "tank-templates"
}

# fastpool -- NVMe 2TB ZFS pool for VM disks
resource "proxmox_virtual_environment_storage_zfspool" "fastpool" {
  id       = "fastpool"
  zfs_pool = "fastpool/vm-disks"
  nodes    = [var.proxmox_node]
  content  = ["images", "rootdir"]
}

# tank/backups -- HDD pool for vzdump backups
resource "proxmox_virtual_environment_storage_directory" "tank_backups" {
  id      = "tank-backups"
  path    = "/tank/backups"
  nodes   = [var.proxmox_node]
  content = ["backup"]
}

# tank/iso -- HDD pool for ISO images
resource "proxmox_virtual_environment_storage_directory" "tank_iso" {
  id      = "tank-iso"
  path    = "/tank/iso"
  nodes   = [var.proxmox_node]
  content = ["iso", "import"]
}

# tank/templates -- HDD pool for container templates
resource "proxmox_virtual_environment_storage_directory" "tank_templates" {
  id      = "tank-templates"
  path    = "/tank/templates"
  nodes   = [var.proxmox_node]
  content = ["vztmpl"]
}
