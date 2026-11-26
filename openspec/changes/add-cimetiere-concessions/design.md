## Context

`cimetiere@mangococo.fr` (alias `ragots@`) is live: Email Routing sends both addresses to the `mangococo-ragots` Worker (`terraform/cloudflare/ragots.tf`, `worker/ragots.js`). A post from a member, checked on the envelope sender, is re-sent to every member through Cloudflare Email Sending as a new message from `Cimetière <cimetiere@mangococo.fr>`, with the headers that identify the sender removed. Members (10 today) live in the Bitwarden secret `ragots-members`, passed to the Worker as a `secret_text` binding, and only change through `scripts/ragots.py` plus a Terraform apply.

On the free plan, Email Sending only delivers to verified Email Routing destination addresses, so every member must click Cloudflare's verification email once.

`contact@mangococo.fr` is a separate forwarding Worker with its map in Bitwarden. It is out of scope, apart from one subaddressing side effect.

## Goals / Non-Goals

**Goals:**

- Members create and fill small anonymous lists (concessions) by email, without Julen.
- Replies to a concession post go back to that concession, and members can tell which concession a mail came from.
- One place for every member list, writable by the Worker: Workers KV.
- Julen hears about every new concession and every new person.
- Everything stays on the Cloudflare free tier and in `terraform/cloudflare`.

**Non-Goals:**

- Protection against forged senders. A forged address can post or bury people; that is accepted, usability first.
- Archives, digests, moderation, attachments policy.
- Changing `contact@mangococo.fr`.
- A web interface.

## Decisions

### Concessions are plus addresses on the cimetière rule

A concession `apero` is reached at `cimetiere+apero@mangococo.fr`. Turning on `support_subaddress` (`cloudflare_email_routing_settings`) makes that address match the existing literal `cimetiere@` rule, so concessions need no Terraform change and no catch-all. The `+` also says the concession lives inside the cimetière.

Rejected: plain `apero@mangococo.fr` through the catch-all. Shorter to type, but every typo and spam address on the zone would hit the Worker, and concession names would compete with real addresses like `contact@`.

### One Worker, routed by recipient

`mangococo-ragots` keeps serving `cimetiere@` and `ragots@`, and gains `cimetiere+<concession>@` and `fossoyeur@` (one more address in the `ragots` rule set). The router reads the recipient: the main list and concessions share the anonymising re-send and loop protection; `fossoyeur@` goes to the command handler.

### A concession answers as itself

Each copy of a concession post carries:

| Header | Value |
| --- | --- |
| `From` | `Cimetière · apero <cimetiere+apero@mangococo.fr>` |
| `Reply-To`, `To` | `cimetiere+apero@mangococo.fr` |
| `List-Id` | `apero.cimetiere.mangococo.fr` |
| `Subject` | the original subject prefixed with `[apero]`, once (not doubled on replies) |

So "Reply" in any mail client goes back to the concession, and the display name and subject prefix say where the mail came from. The main list keeps today's headers.

The `send_email` binding today allows a single sender, `cimetiere@`. Concessions are created at runtime, so they cannot be listed in `allowed_sender_addresses`. Preferred: drop that restriction (Email Sending still only signs for `mangococo.fr`). If Email Sending rejects a plus address as sender, fall back to `From: Cimetière · apero <cimetiere@mangococo.fr>` with `Reply-To: cimetiere+apero@mangococo.fr`: replies still reach the concession, which is what matters. Implementation checks which one works.

### Members live in Workers KV, the main list included

One KV namespace, `mangococo-cimetiere`, created empty by Terraform and written by the Worker:

| Key | Value |
| --- | --- |
| `concession:<name>` | `{"members": [...], "boughtBy": "a@x.org", "boughtAt": "2026-11-26"}` |
| `member:<address>` | the names of the concessions that address belongs to |

The main list is the reserved concession `cimetiere`. Addresses are lowercased. KV is outside git and outside the Terraform state, so the public repo never holds an address.

KV is eventually consistent (up to about 60 s) and has no transactions: a post sent right after an `enterrer` can miss the new member, and two commands on the same concession at the same second can lose one write. Both are acceptable at band scale.

Rejected: D1 or Durable Objects. They remove the race, at the cost of a schema or a class to maintain.

### The fossoyeur speaks cemetery

Commands go in the mail body, one per line. The subject is ignored. Matching ignores case and accents.

| Command | Meaning | Who |
| --- | --- | --- |
| `acheter <concession>` | Create a concession; the buyer is its first member | Anyone |
| `enterrer <concession> <adresse> [<adresse> ...]` | Add people | Members of that concession |
| `exhumer <concession>` | Leave it; the last one out frees the concession | Members of that concession |
| `registre <concession>` | List its members, marking those not verified yet | Members of that concession |
| `plan` | List the concessions you belong to | Anyone |
| `aide` | The help text | Anyone |

Any line that is not a command makes the whole answer the help text, quoting the line it did not understand. Reading stops at a signature (`-- `) or a quoted line (`>`), so replying to a fossoyeur mail works. At most 10 commands per mail. A concession name is 2 to 32 characters of `a-z`, `0-9` and `-`; `cimetiere`, `ragots`, `fossoyeur` and `contact` are reserved.

The fossoyeur answers with `message.reply()`, which can reach a sender who is not a verified address yet (a stranger buying a concession). Implementation confirms the conditions `reply()` puts on the incoming mail (DMARC).

### Mail bodies are parsed with postal-mime

Command mails arrive as multipart, quoted-printable or base64, in several charsets depending on the client (Gmail, Hotmail, Yahoo, free.fr, La Poste). `postal-mime` is a dependency-free MIME parser written for Workers. Its ES modules are vendored under `worker/vendor/postal-mime/` and uploaded beside `ragots.js` through the script's `files` attribute, so Terraform still uploads files as they are and Burrito needs no build step.

Rejected: an esbuild bundle (a committed build artefact and a CI check to keep it in sync); a hand-written parser (the first unusual client breaks it).

### Registration goes through the Cloudflare API, with a Terraform-made token

Free-plan Email Sending only reaches verified addresses, so `enterrer` (and `acheter` by an unknown sender) registers each new address with `POST /accounts/{id}/email/routing/addresses`, which makes Cloudflare send the verification email. An address already registered (the destination list is shared with `contact@`) is left alone.

The Worker's token is a `cloudflare_account_token` limited to Email Routing Addresses read and write, passed as a `secret_text` binding. Terraform creates it, so it never appears in git, Bitwarden or a plan; rotation is `terraform apply -replace`. The token Terraform itself uses needs "Account API Tokens Write" for this.

The new person cannot be welcomed before they verify, since nothing reaches them before. The answer to `enterrer` tells the member to warn them ("dis-lui de chercher le mail de Cloudflare, spams compris").

### Julen is notified through the same binding

One short mail to `julen@loudnaround.org` (verified) per `acheter` and per address buried: who, which concession, which address. The address comes from a `plain_text` binding, not from the code.

### Admin access stays outside the mail interface

`scripts/cimetiere.py` (uv script, same shape as `forwards.py`) reads and writes KV through the Cloudflare API: list concessions and members, remove anyone, delete a concession, and the one-off import of `ragots-members`. That covers what the fossoyeur does not allow (exhuming someone else) without an admin command.

## Risks / Trade-offs

- **Forged senders** can post to a concession or bury people in it → accepted; every burial notifies Julen, who can undo it with `scripts/cimetiere.py`.
- **Members posting from another address** (an alias, a Gmail dot variant) are refused → the refusal says how to fix it: be buried under that address too.
- **Email Sending rejects plus-address senders** → fallback headers above.
- **Spam to `fossoyeur@`** buys concessions → each needs a reply-able sender and notifies Julen; KV's 1,000 free writes a day caps the damage.
- **Email Sending free allowance** is not known yet → check before rollout; a post costs one send per member.
- **Subaddressing reaches `contact@`**: `contact+x@` would be rejected as unknown → the forwarding Worker strips the `+` part in the same change.
- **KV races** → accepted at band scale (see above).

## Migration Plan

1. Julen adds "Account API Tokens Write" and "Workers KV Storage Write" to the token in `cloudflare-api-token`.
2. PR 1: KV namespace, Worker token, subaddressing, `contact@` fix, Worker reading the main list from KV with a fallback to the `MEMBERS` binding when the KV key is missing. Apply.
3. `scripts/cimetiere.py import` copies `ragots-members` into `concession:cimetiere`. A post to `cimetiere@` behaves as before.
4. PR 2: the fossoyeur and concessions; remove the `MEMBERS` binding, `var.ragots_members`, `scripts/ragots.py`, the `.envrc` export and the ExternalSecret key. Apply, then delete `ragots-members` from Bitwarden.
5. Test with a throwaway concession made of Julen's addresses, then send the band the how-to.

Rollback: before step 4, reverting PR 1 restores the Bitwarden path untouched. After it, `scripts/cimetiere.py export` gives the member list back.

## Open Questions

- Can members of the main cimetière `enterrer` new people in it, or does the main list stay admin-only (Julen, through the script)?
- Must someone already be in the main cimetière to `acheter` a concession, or can anyone, as decided so far?
- Keep the `[apero]` subject prefix, or rely on the display name alone?
- Commands in French only, or also English synonyms?
- A daily cron that welcomes people once they verify (and tells Julen): worth the extra code?
