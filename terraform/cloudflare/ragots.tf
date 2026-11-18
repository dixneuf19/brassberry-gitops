locals {
  ragots_address = "ragots@mangococo.fr"
  ragots_members = distinct([for m in var.ragots_members : lower(m)])
}

resource "cloudflare_workers_script" "ragots" {
  account_id         = local.account_id
  script_name        = "mangococo-ragots"
  content            = file("${path.module}/worker/ragots.js")
  main_module        = "ragots.js"
  compatibility_date = "2026-11-01"

  bindings = [{
    name = "MEMBERS"
    type = "secret_text"
    text = jsonencode(local.ragots_members)
  }]
}

resource "cloudflare_email_routing_rule" "ragots" {
  zone_id = data.cloudflare_zone.mangococo.zone_id
  name    = "Mailing list ${local.ragots_address}"
  enabled = true

  matchers = [{
    type  = "literal"
    field = "to"
    value = local.ragots_address
  }]

  actions = [{
    type  = "worker"
    value = [cloudflare_workers_script.ragots.script_name]
  }]

  depends_on = [cloudflare_email_routing_address.destination]

  lifecycle {
    precondition {
      condition     = !contains(nonsensitive(keys(local.forwards)), local.ragots_address)
      error_message = "${local.ragots_address} is the mailing list, remove it from mangococo_email_forwards."
    }
  }
}
