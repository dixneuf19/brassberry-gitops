# Post-swap adoption: stable tailnet name for the new device, stale sibling
# records deleted. Runs where terraform runs and needs bash, curl, jq: present
# on the laptop, and in the burrito runner via images/burrito-runner.
resource "terraform_data" "tailnet_adopt" {
  triggers_replace = oci_core_instance.oracle-arm.id

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

# Homelab hosts joined by hand as a user: tagging them makes the node key
# stop expiring, like the brassberry Pis.
data "tailscale_device" "homelab" {
  for_each = toset(["jonbonas", "k8s-worker-1"])
  hostname = each.key
}

resource "tailscale_device_tags" "homelab" {
  for_each  = data.tailscale_device.homelab
  device_id = each.value.node_id
  tags      = ["tag:brassberry"]
}

resource "tailscale_device_key" "homelab" {
  for_each            = data.tailscale_device.homelab
  device_id           = each.value.node_id
  key_expiry_disabled = true
}
