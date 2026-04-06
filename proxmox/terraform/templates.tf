# =============================================
# Cloud-init Ubuntu template
# Downloads the cloud image and creates a reusable VM template
# =============================================

# Download Ubuntu 24.04 cloud image directly on the Proxmox node
resource "proxmox_download_file" "ubuntu_cloud_image" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = var.proxmox_node
  url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  file_name    = "noble-server-cloudimg-amd64.img"
}

# Cloud-init vendor config for all K8s worker VMs
resource "proxmox_virtual_environment_file" "k8s_worker_cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_node

  source_raw {
    data = <<-EOF
      #cloud-config
      package_update: true
      packages:
        - qemu-guest-agent
      runcmd:
        - systemctl enable --now qemu-guest-agent
    EOF
    file_name = "k8s-worker-cloud-config.yaml"
  }
}
