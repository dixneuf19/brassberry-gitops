data "cloudflare_zone" "mangococo" {
  filter = {
    name = "mangococo.fr"
  }
}

locals {
  account_id = data.cloudflare_zone.mangococo.account.id

  forwards = { for src, dests in var.mangococo_email_forwards : lower(src) => [for d in dests : lower(d)] }

  # Destination mailboxes are private (public repo, plans posted on PRs): key them by hash
  destinations = { for d in distinct(flatten(values(local.forwards))) : sha256(d) => d }
}

# Each destination must be verified by clicking the link Cloudflare emails to it
resource "cloudflare_email_routing_address" "destination" {
  for_each = nonsensitive(toset(keys(local.destinations)))

  account_id = local.account_id
  email      = local.destinations[each.key]
}

resource "cloudflare_workers_script" "email_forward" {
  account_id         = local.account_id
  script_name        = "mangococo-email-forward"
  content            = file("${path.module}/worker/email-forward.js")
  main_module        = "email-forward.js"
  compatibility_date = "2026-11-01"

  bindings = [{
    name = "FORWARDS"
    type = "secret_text"
    text = jsonencode(local.forwards)
  }]
}

resource "cloudflare_email_routing_rule" "forward" {
  for_each = nonsensitive(toset(keys(local.forwards)))

  zone_id = data.cloudflare_zone.mangococo.zone_id
  name    = "Forward ${each.key} via worker"
  enabled = true

  matchers = [{
    type  = "literal"
    field = "to"
    value = each.key
  }]

  actions = [{
    type  = "worker"
    value = [cloudflare_workers_script.email_forward.script_name]
  }]

  depends_on = [cloudflare_email_routing_address.destination]
}
