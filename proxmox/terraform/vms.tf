# # =============================================
# # Kubernetes Worker VMs
# # Cloud-init Ubuntu VMs on fastpool for K8s workloads
# # =============================================

# resource "proxmox_virtual_environment_vm" "k8s_worker" {
#   count     = var.k8s_worker_count
#   name      = "k8s-worker-${count.index + 1}"
#   node_name = var.proxmox_node
#   vm_id     = 200 + count.index

#   # Machine type
#   machine = "q35"
#   bios    = "ovmf"

#   # Resources
#   cpu {
#     cores = var.k8s_worker_cores
#     type  = "host"
#   }

#   memory {
#     dedicated = var.k8s_worker_memory
#   }

#   # Boot disk from cloud image on fastpool
#   disk {
#     datastore_id = proxmox_virtual_environment_storage_zfspool.fastpool.id
#     file_id      = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
#     interface    = "virtio0"
#     size         = var.k8s_worker_disk_size
#     discard      = "on"
#   }

#   # EFI disk
#   efi_disk {
#     datastore_id = proxmox_virtual_environment_storage_zfspool.fastpool.id
#   }

#   # Network
#   network_device {
#     bridge = "vmbr0"
#     model  = "virtio"
#   }

#   # Cloud-init configuration
#   initialization {
#     ip_config {
#       ipv4 {
#         address = "192.168.1.${40 + count.index}/24"
#         gateway = "192.168.1.1"
#       }
#     }

#     dns {
#       servers = ["192.168.1.1", "1.1.1.1"]
#     }

#     user_account {
#       username = var.vm_user
#       keys     = [var.ssh_public_key]
#     }
#   }

#   # QEMU guest agent
#   agent {
#     enabled = true
#   }

#   # Start on boot
#   on_boot = true

#   # Don't start automatically after creation (we'll start when ready)
#   started = false

#   lifecycle {
#     ignore_changes = [
#       # Ignore changes to started state (managed manually)
#       started,
#     ]
#   }
# }
