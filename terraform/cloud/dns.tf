resource "gandi_livedns_record" "oracle_arm" {
  name   = "brassberry"
  ttl    = 300
  type   = "A"
  values = [oci_core_public_ip.oracle_arm.ip_address]
  zone   = "dixneuf19.fr"
}

resource "gandi_livedns_record" "wildcard" {
  name   = "*"
  ttl    = 1800
  type   = "CNAME"
  values = ["brassberry.dixneuf19.fr."]
  zone   = "dixneuf19.fr"
}

resource "gandi_livedns_record" "root" {
  name   = "@"
  ttl    = 300
  type   = "A"
  values = [oci_core_public_ip.oracle_arm.ip_address]
  zone   = "dixneuf19.fr"
}

resource "gandi_livedns_record" "upptime" {
  name   = "upptime"
  ttl    = 1800
  type   = "CNAME"
  values = ["dixneuf19.github.io."]
  zone   = "dixneuf19.fr"
}

resource "gandi_livedns_record" "bandajoe" {
  name   = "@"
  ttl    = 300
  type   = "A"
  values = [oci_core_public_ip.oracle_arm.ip_address]
  zone   = "bandajoe.fr"
}

resource "gandi_livedns_record" "bandajoe_www" {
  name   = "www"
  ttl    = 300
  type   = "CNAME"
  values = ["bandajoe.fr."]
  zone   = "bandajoe.fr"
}

# Mail for loudnaround.org is hosted on Google Workspace
resource "gandi_livedns_record" "loudnaround_dmarc" {
  provider = gandi.loudnaround

  name   = "_dmarc"
  ttl    = 3600
  type   = "TXT"
  values = ["\"v=DMARC1; p=none;\""]
  zone   = "loudnaround.org"
}

resource "gandi_livedns_record" "loudnaround_root_txt" {
  provider = gandi.loudnaround

  name = "@"
  ttl  = 10800
  type = "TXT"
  values = [
    "\"google-site-verification=frngER4qPi34xADuIOGw4Wi7wlmaN0xTbKXSokb1RL0\"",
    "\"google-site-verification=_O6oOJITIsEvaNcZ7Ku7MZYkwAmtaL7Bzsa6N7W-Jg4\"",
    "\"google-site-verification=-vnsrVXt5Z-DmLQ2KS0JICZyWmMMN024P_VVVlOiWkM\"",
    "\"v=spf1 include:_spf.google.com ~all\"",
  ]
  zone = "loudnaround.org"
}

import {
  provider = gandi.loudnaround
  to       = gandi_livedns_record.loudnaround_root_txt
  id       = "loudnaround.org/@/TXT"
}

# Generated in the Google Workspace admin console (Gmail > Authenticate email),
# split in 255-character strings
resource "gandi_livedns_record" "loudnaround_dkim" {
  provider = gandi.loudnaround

  name   = "google._domainkey"
  ttl    = 3600
  type   = "TXT"
  values = ["\"v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA6atk9FAyjzOfB9lE5A3NzLx6Y/KCsHHP8Yp47Vu5JVKIlBaxv2XZLBfsEFldkzbc602YKcKiQr+vpTvMq2FQScfLa1FSYe0wbE0y+Y+GUr6TB5tWhmk1nNMlqbNMKmZAnNiSpcGn4kBR1JnuRaXfUAFrZEJvkl+NtXHprHn84K2abCtWivuJF8Z7k9B6mMtcC\" \"gFtq1h9NLRmNHFEB8Q488Yj/E5ykmkmryk50tGoQG8Jdva+XSg6krvcxdVBsyg0A2v6Gzf9ZwP4kZa8gnWD6UzzydCof2qE3mur3Syvx4LO8r89h6R0qIJe3xF3b9i/Wd9SBKBx+q9/e2tvW+dL+wIDAQAB\""]
  zone   = "loudnaround.org"
}
