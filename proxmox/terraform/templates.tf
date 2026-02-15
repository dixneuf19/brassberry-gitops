# =============================================
# Cloud-init Ubuntu template
# Downloads the cloud image and creates a reusable VM template
# =============================================

# Download Ubuntu 24.04 cloud image directly on the Proxmox node
resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = var.proxmox_node
  url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  file_name    = "noble-server-cloudimg-amd64.img"
}
