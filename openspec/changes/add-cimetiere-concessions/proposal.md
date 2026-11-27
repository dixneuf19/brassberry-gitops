## Why

`cimetiere@mangococo.fr` is one anonymous list for the whole band, and only Julen (or Claude) can change its members, by editing a Bitwarden secret and applying Terraform. The band wants members to let people in themselves, and to talk in smaller private groups that nobody outside them, Julen included, can see.

## What Changes

- **Two levels:**
    - **The cimetière** is the common list everyone shares, at `cimetiere@mangococo.fr` (alias `ragots@`). Entry is restricted: only a member can bury someone there, and Julen is told about every entry.
    - **A concession** is a private sub-group of cimetière members, at `cimetiere+<concession>@mangococo.fr`. Members join by invitation from someone already inside. Nobody outside a concession can list it, read its members or learn it exists, and Julen is not told about it.
- **The fossoyeur:** `fossoyeur@mangococo.fr` takes commands written in the mail body, in French cemetery words: `enterrer` someone in the cimetière or a concession, `exhumer` yourself, `acheter` a concession, read a `registre`, see your `plan`, choose your `surnom`. Anything it does not understand gets the help text back.
- **Nicknames:** every cimetière member has a `surnom`, shown in the registers and usable instead of an address when inviting someone to a concession.
- **All members in Workers KV:** the cimetière, the concessions and the nicknames live in KV, written by the Worker. The Bitwarden secret `ragots-members`, `TF_VAR_ragots_members` and `scripts/ragots.py` are deleted.
- **Registration and welcome:** burying a new person in the cimetière registers their address with Cloudflare (verification required on the free plan); a 15-minute cron trigger welcomes them once they have verified.
- **Subaddressing** is turned on for the zone, so `cimetiere+<concession>@` matches the existing `cimetiere@` rule.

## Capabilities

### New Capabilities

- `cimetiere`: the cimetière and its concessions, who can post, how copies are anonymised and addressed, what each member can see, and where members and nicknames are stored.
- `fossoyeur`: the command mailbox, its vocabulary and permissions, registration and welcome of new people, and Julen's notifications.

### Modified Capabilities

None. `openspec/specs/` holds nothing about mail yet.

## Impact

- **Terraform (`terraform/cloudflare`, Burrito auto-apply):** a KV namespace, an account-owned API token for the Worker, `support_subaddress` on the zone, a cron trigger, new bindings on `cloudflare_workers_script.ragots`, `fossoyeur@` added to the `ragots` rules. `var.ragots_members` is removed.
- **Cloudflare token used by Terraform:** needs "Account API Tokens Write" and "Workers KV Storage Write", added by Julen in the dashboard.
- **Bitwarden:** `ragots-members` is deleted after the migration, with its `.envrc` export and ExternalSecret key.
- **`contact@mangococo.fr`:** not touched. Its Worker, rule and Bitwarden map stay exactly as they are.
- **Band:** a short how-to mail on the cimetière once it is live.
