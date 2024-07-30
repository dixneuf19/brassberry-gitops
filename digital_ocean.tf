resource "digitalocean_droplet" "proxy" {
  image     = "ubuntu-24-04-x64"
  name      = "brassberry-proxy"
  region    = "ams3"
  size      = "s-1vcpu-512mb-10gb"
  user_data = templatefile(
        "userdata.yaml.tpl",
        {
          github_user        = var.github_user,
          tailscale_auth_key = var.tailscale_auth_key,
          ip_addrs           = var.node_ips
        }
      )
}
