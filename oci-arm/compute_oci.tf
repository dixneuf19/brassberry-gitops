resource "oci_core_instance" "oracle-arm" {
  display_name   = "oracle-arm-${random_id.hostname_suffix.hex}"
  compartment_id = var.oci_compartment_id

  shape = data.oci_core_images.ampere-ubuntu-images.shape
  shape_config {
    memory_in_gbs = "12"
    ocpus         = "2"
  }
  source_details {
    boot_volume_size_in_gbs = "100"
    source_id               = data.oci_core_images.ampere-ubuntu-images.images[0].id
    source_type             = "image"
  }

  metadata = {
    "user_data" = base64encode(
      templatefile(
        "userdata.yaml.tpl",
        {
          github_user        = var.github_user,
          tailscale_auth_key = var.tailscale_auth_key,
          ip_addrs           = var.node_ips
          hostname_suffix    = random_id.hostname_suffix.hex
        }
      )
    )
  }

  create_vnic_details {
    assign_private_dns_record = "true"
    assign_public_ip          = "false"
    hostname_label            = "oracle-arm-${random_id.hostname_suffix.hex}"
    subnet_id                 = oci_core_subnet.subnet_0.id
  }

  availability_config {
    recovery_action = "RESTORE_INSTANCE"
  }
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name

  instance_options {
    are_legacy_imds_endpoints_disabled = "false"
  }
  is_pv_encryption_in_transit_enabled = "true"

  agent_config {
    is_management_disabled = "false"
    is_monitoring_disabled = "false"
    plugins_config {
      desired_state = "DISABLED"
      name          = "Vulnerability Scanning"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Compute Instance Monitoring"
    }
  }
}
