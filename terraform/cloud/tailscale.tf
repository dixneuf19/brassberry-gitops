resource "tailscale_tailnet_key" "reverse_proxy" {
  description         = "oracle-arm reverse proxy - managed by terraform"
  reusable            = true
  preauthorized       = true
  recreate_if_invalid = "always"
  tags                = ["tag:brassberry"]
}
