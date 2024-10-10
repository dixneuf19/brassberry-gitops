resource "gandi_livedns_record" "oracle_arm" {
  name   = "brassberry"
  ttl    = 300
  type   = "A"
  values = [oci_core_instance.oracle-arm.public_ip]
  zone   = "dixneuf19.fr"
}

resource "gandi_livedns_record" "old_redirection" {
  name   = "brassberry"
  ttl    = 300
  type   = "A"
  values = [oci_core_instance.oracle-arm.public_ip]
  zone   = "dixneuf19.me"
}
