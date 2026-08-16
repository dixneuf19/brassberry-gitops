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
        merge(local.userdata_vars, {
          tailscale_auth_key = tailscale_tailnet_key.reverse_proxy.key
          hostname_suffix    = random_id.hostname_suffix.hex
        })
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

  # Blue/green rotation: the replacement VM boots and finishes cloud-init while
  # the old edge keeps serving; the reserved public IP re-attaches afterwards.
  # 2 OCPU/12GB = half the Always Free ARM quota, so both fit during the swap
  # (but the two 100GB boot volumes use the full 200GB block storage quota).
  # If OCI is out of ARM capacity the create fails and the old edge stays up.
  # The auth key only matters at boot, so a key-only rotation must not replace
  # the VM: the user_data diff is ignored and replacement is driven instead by
  # the hostname_suffix keepers, whose userdata fingerprint excludes the key.
  lifecycle {
    create_before_destroy = true
    ignore_changes        = [metadata]
    replace_triggered_by  = [random_id.hostname_suffix]
  }
}
