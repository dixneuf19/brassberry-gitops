# Created by Email Sending onboarding, reporting address from DMARC Management
resource "cloudflare_dns_record" "dmarc" {
  zone_id = data.cloudflare_zone.mangococo.zone_id
  name    = "_dmarc.mangococo.fr"
  type    = "TXT"
  content = "\"v=DMARC1; p=reject; rua=mailto:0049fee20df24bbe9beac96fea02bdec@dmarc-reports.cloudflare.net;\""
  ttl     = 1
}
