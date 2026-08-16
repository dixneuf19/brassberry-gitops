resource "tailscale_tailnet_key" "reverse_proxy" {
  description         = "oracle-arm reverse proxy VM (terraform/cloud)"
  reusable            = true
  preauthorized       = true
  recreate_if_invalid = "always"
  tags                = ["tag:brassberry"]
}
