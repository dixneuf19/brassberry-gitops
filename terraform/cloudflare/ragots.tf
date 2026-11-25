locals {
  ragots_address   = "cimetiere@mangococo.fr"
  ragots_addresses = [local.ragots_address, "ragots@mangococo.fr"]
  ragots_members   = distinct([for m in var.ragots_members : lower(m)])
}

resource "cloudflare_workers_script" "ragots" {
  account_id         = local.account_id
  script_name        = "mangococo-ragots"
  content            = file("${path.module}/worker/ragots.js")
  main_module        = "ragots.js"
  compatibility_date = "2026-11-01"

  bindings = [
    {
      name = "MEMBERS"
      type = "secret_text"
      text = jsonencode(local.ragots_members)
    },
    {
      name                     = "SEND"
      type                     = "send_email"
      allowed_sender_addresses = [local.ragots_address]
    },
  ]

  observability = {
    enabled            = true
    head_sampling_rate = 1
    logs = {
      enabled            = true
      head_sampling_rate = 1
      invocation_logs    = true
      persist            = true
    }
    traces = {
      enabled            = false
      head_sampling_rate = 1
      persist            = true
    }
  }

  depends_on = [cloudflare_email_sending_subdomain.mangococo]
}

resource "cloudflare_email_sending_subdomain" "mangococo" {
  zone_id = data.cloudflare_zone.mangococo.zone_id
  name    = "mangococo.fr"
}

moved {
  from = cloudflare_email_routing_rule.ragots
  to   = cloudflare_email_routing_rule.ragots["ragots@mangococo.fr"]
}

resource "cloudflare_email_routing_rule" "ragots" {
  for_each = toset(local.ragots_addresses)

  zone_id = data.cloudflare_zone.mangococo.zone_id
  name    = each.key == local.ragots_address ? "Mailing list ${each.key}" : "Mailing list ${local.ragots_address} (alias ${each.key})"
  enabled = true

  matchers = [{
    type  = "literal"
    field = "to"
    value = each.key
  }]

  actions = [{
    type  = "worker"
    value = [cloudflare_workers_script.ragots.script_name]
  }]

  depends_on = [cloudflare_email_routing_address.destination]

  lifecycle {
    precondition {
      condition     = !contains(nonsensitive(keys(local.forwards)), each.key)
      error_message = "${each.key} is the mailing list, remove it from mangococo_email_forwards."
    }
  }
}
