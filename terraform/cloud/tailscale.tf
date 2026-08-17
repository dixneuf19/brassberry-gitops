# Post-swap adoption: stable tailnet name for the new device, stale sibling
# records deleted. Runs where terraform runs (needs bash, curl, jq), fine
# while the layer is applied from the laptop; revisit before any autoApply.
resource "terraform_data" "tailnet_adopt" {
  input = oci_core_instance.oracle-arm.id

  provisioner "local-exec" {
    working_dir = path.module
    command     = "./scripts/tailnet-adopt.sh oracle-arm-${random_id.hostname_suffix.hex} oracle-arm"
  }
}

resource "tailscale_tailnet_key" "reverse_proxy" {
  description         = "oracle-arm reverse proxy - managed by terraform"
  reusable            = true
  preauthorized       = true
  recreate_if_invalid = "always"
  tags                = ["tag:brassberry"]
}
