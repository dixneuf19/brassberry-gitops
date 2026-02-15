# Used to have a unique hostname for the VM
resource "random_id" "hostname_suffix" {
  byte_length = 3
  keepers = {
    # This will change when the userdata template changes
    userdata_template = filemd5("userdata.yaml.tpl")
    # This will change when the compute_oci.tf file itself changes
    compute_file = filemd5("compute_oci.tf")
    # This will change when the available images change
    available_images = jsonencode(data.oci_core_images.ampere-ubuntu-images.images)
    # This will change when any variables change
    all_vars = md5(jsonencode([
      var.github_user,
      var.tailscale_auth_key,
      var.node_ips,
      var.oci_compartment_id,
    ]))
  }
}
