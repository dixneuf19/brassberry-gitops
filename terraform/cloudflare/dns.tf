# Created by Email Sending onboarding, reporting address from DMARC Management
import {
  to = cloudflare_dns_record.dmarc
  id = "b5951af72b9fe8129ac777dca9a45f23/f20676b083c32d1f8dc43dd900993ab4"
}

resource "cloudflare_dns_record" "dmarc" {
  zone_id = data.cloudflare_zone.mangococo.zone_id
  name    = "_dmarc.mangococo.fr"
  type    = "TXT"
  content = "\"v=DMARC1; p=reject; rua=mailto:0049fee20df24bbe9beac96fea02bdec@dmarc-reports.cloudflare.net;\""
  ttl     = 1
}
