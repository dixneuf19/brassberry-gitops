variable "proxmox_endpoint" {
  description = "Proxmox API endpoint URL (uses Tailscale hostname)"
  type        = string
  default     = "https://jonbonas:8006"
}

variable "proxmox_api_token" {
  description = "Proxmox API token (format: user@realm!token-name=secret)"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  default     = "jonbonas"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

variable "vm_user" {
  description = "Default user for cloud-init VMs"
  type        = string
  default     = "dixneuf19"
}

variable "k8s_worker_count" {
  description = "Number of Kubernetes worker VMs to create"
  type        = number
  default     = 2
}

variable "k8s_worker_cores" {
  description = "Number of CPU cores per K8s worker VM"
  type        = number
  default     = 4
}

variable "k8s_worker_memory" {
  description = "Memory in MB per K8s worker VM"
  type        = number
  default     = 8192
}

variable "k8s_worker_disk_size" {
  description = "Disk size in GB per K8s worker VM"
  type        = number
  default     = 50
}
