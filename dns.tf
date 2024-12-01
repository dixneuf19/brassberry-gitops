resource "gandi_livedns_record" "oracle_arm" {
  name   = "brassberry"
  ttl    = 300
  type   = "A"
  values = [oci_core_instance.oracle-arm.public_ip]
  zone   = "dixneuf19.fr"
}

resource "gandi_livedns_record" "wildcard" {
  name   = "*"
  ttl    = 1800
  type   = "CNAME"
  values = ["brassberry.dixneuf19.fr"]
  zone   = "dixneuf19.fr"
}

resource "gandi_livedns_record" "upptime" {
  name   = "upptime"
  ttl    = 1800
  type   = "CNAME"
  values = ["dixneuf19.github.io"]
  zone   = "dixneuf19.fr"
}

resource "gandi_livedns_record" "bandajoe" {
  name   = "@"
  ttl    = 300
  type   = "A"
  values = [oci_core_instance.oracle-arm.public_ip]
  zone   = "bandajoe.fr"
}

resource "gandi_livedns_record" "bandajoe_www" {
  name   = "www"
  ttl    = 300
  type   = "CNAME"
  values = ["bandajoe.fr."]
  zone   = "bandajoe.fr"
}
