locals {
  userdata_vars = {
    github_user = var.github_user
    ip_addrs    = var.node_ips
    debug       = var.debug
  }
}

# Used to have a unique hostname for the VM
resource "random_id" "hostname_suffix" {
  byte_length = 3
  # If this rotates in an apply where the key fails to create, the VM
  # replacement is stranded (replace_triggered_by only fires on same-plan
  # changes), so order the key first.
  depends_on = [tailscale_tailnet_key.reverse_proxy]
  keepers = {
    # Userdata render with the auth key redacted and the suffix pinned, so a
    # key-only rotation never rebuilds the VM on its own
    userdata_fingerprint = sha256(templatefile("userdata.yaml.tpl", merge(local.userdata_vars, {
      tailscale_auth_key = "redacted"
      hostname_suffix    = "fingerprint"
    })))
    # This will change when the compute_oci.tf file itself changes
    compute_file = filemd5("compute_oci.tf")
    # This will change when the available images change
    available_images = jsonencode(data.oci_core_images.ampere-ubuntu-images.images)
    # This will change when the remaining variables change
    oci_compartment_id = var.oci_compartment_id
  }
}
