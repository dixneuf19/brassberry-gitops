resource "gandi_livedns_record" "oracle_arm" {
  name   = "brassberry"
  ttl    = 300
  type   = "A"
  values = [digitalocean_droplet.proxy.ipv4_address]
  zone   = "dixneuf19.me"
}
