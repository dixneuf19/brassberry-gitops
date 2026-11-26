## 1. Prerequisites

- [ ] 1.1 Julen adds "Account API Tokens Write" and "Workers KV Storage Write" to the token in `cloudflare-api-token`
- [ ] 1.2 Check the Email Sending free allowance in the dashboard
- [ ] 1.3 Check whether Email Sending accepts `cimetiere+<name>@mangococo.fr` as sender, and the conditions of `message.reply()`; pick the header variant in design.md accordingly

## 2. KV and main list (PR 1, terraform/cloudflare)

- [ ] 2.1 `cloudflare_workers_kv_namespace.cimetiere` and its binding on `cloudflare_workers_script.ragots`
- [ ] 2.2 `cloudflare_email_routing_settings` with `support_subaddress = true` (import the existing settings first)
- [ ] 2.3 `worker/email-forward.js` strips the `+` part of the recipient; test
- [ ] 2.4 `worker/ragots.js` reads the main list from `concession:cimetiere`, falling back to the `MEMBERS` binding when the key is missing; tests
- [ ] 2.5 `scripts/cimetiere.py` (uv script): `list`, `registre`, `add`, `rm`, `delete`, `import` (from `ragots-members`), `export`
- [ ] 2.6 `terraform plan` shows the namespace, the settings change and the Worker update, nothing else; apply
- [ ] 2.7 `scripts/cimetiere.py import`, then one post to `cimetiere@` reaches the 10 members as before

## 3. Concessions and fossoyeur (PR 2)

- [ ] 3.1 Vendor `postal-mime` under `worker/vendor/postal-mime/`, uploaded through the script's `files`; exclude it from `tsc`
- [ ] 3.2 Router on the recipient: main list, concession, fossoyeur
- [ ] 3.3 Concession posts: membership check, anonymous copies, concession headers (From, Reply-To, To, List-Id, `[name]` subject prefix)
- [ ] 3.4 Command parser (body, signature and quote cut-off, accents, 10-command cap) with unit tests on real mails from Gmail, Hotmail, Yahoo, free.fr and La Poste
- [ ] 3.5 `acheter`, `enterrer`, `exhumer`, `registre`, `plan`, `aide`, with KV `member:` index kept in sync; unit tests
- [ ] 3.6 Address registration through the Cloudflare API; `cloudflare_account_token.fossoyeur` and its `secret_text` binding
- [ ] 3.7 Notifications to Julen (`plain_text` binding for the address)
- [ ] 3.8 `fossoyeur@` added to the `ragots` rule set; `allowed_sender_addresses` changed per 1.3
- [ ] 3.9 Remove `MEMBERS`, `var.ragots_members`, `scripts/ragots.py`, the `.envrc` export and the ExternalSecret key; update `README.md` and `CLAUDE.md`
- [ ] 3.10 `terraform plan`, apply; delete `ragots-members` from Bitwarden

## 4. Acceptance

- [ ] 4.1 `acheter test-tombe` from `julen@loudnaround.org`, `enterrer test-tombe contact@loudnaround.org`
- [ ] 4.2 A post to `cimetiere+test-tombe@` reaches both, anonymised, from `Cimetière · test-tombe`; Reply goes back to the concession
- [ ] 4.3 A post from an outside address is refused; `registre`, `plan`, `exhumer` and a nonsense mail behave as specified
- [ ] 4.4 Julen's notifications arrive
- [ ] 4.5 `exhumer` both addresses (the concession disappears), then send the band the how-to on the main list
