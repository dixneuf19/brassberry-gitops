# =============================================
# LXC Containers
#
# Proxmox Backup Server (PBS) -- COMMENTED OUT
# Uncomment when you want to enable PBS for deduplicated backups.
# PBS provides client-side dedup, incremental backups, and a web UI.
# Much more efficient than raw vzdump for backing up multiple similar VMs.
#
# Prerequisites:
#   1. Download the PBS LXC template:
#      pveam download tank-templates proxmox-backup-server_3.0_amd64.tar.zst
#   2. Uncomment the resources below
#   3. terraform apply
# =============================================

# resource "proxmox_virtual_environment_container" "pbs" {
#   description = "Proxmox Backup Server"
#   node_name   = var.proxmox_node
#   vm_id       = 300
#
#   initialization {
#     hostname = "pbs"
#
#     ip_config {
#       ipv4 {
#         address = "192.168.1.31/24"
#         gateway = "192.168.1.1"
#       }
#     }
#
#     dns {
#       servers = ["192.168.1.1", "1.1.1.1"]
#     }
#
#     user_account {
#       keys = [var.ssh_public_key]
#     }
#   }
#
#   cpu {
#     cores = 2
#   }
#
#   memory {
#     dedicated = 2048
#   }
#
#   disk {
#     datastore_id = "local"
#     size         = 8
#   }
#
#   # Mount tank/backups into the container
#   mount_point {
#     volume = "/tank/backups"
#     path   = "/mnt/backups"
#   }
#
#   network_interface {
#     name   = "eth0"
#     bridge = "vmbr0"
#   }
#
#   operating_system {
#     template_file_id = "tank-templates:vztmpl/proxmox-backup-server_3.0_amd64.tar.zst"
#     type             = "debian"
#   }
#
#   unprivileged = true
#   start_on_boot = true
# }
