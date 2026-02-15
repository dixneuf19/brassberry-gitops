# =============================================
# Outputs
# =============================================

# output "k8s_worker_ips" {
#   description = "IP addresses of K8s worker VMs"
#   value = [
#     for vm in proxmox_virtual_environment_vm.k8s_worker :
#     "192.168.1.${40 + index(proxmox_virtual_environment_vm.k8s_worker, vm)}"
#   ]
# }

# output "k8s_worker_names" {
#   description = "Names of K8s worker VMs"
#   value       = [for vm in proxmox_virtual_environment_vm.k8s_worker : vm.name]
# }

output "storage_ids" {
  description = "Proxmox storage IDs"
  value = {
    fastpool       = proxmox_virtual_environment_storage_zfspool.fastpool.id
    tank_backups   = proxmox_virtual_environment_storage_directory.tank_backups.id
    tank_iso       = proxmox_virtual_environment_storage_directory.tank_iso.id
    tank_templates = proxmox_virtual_environment_storage_directory.tank_templates.id
  }
}
