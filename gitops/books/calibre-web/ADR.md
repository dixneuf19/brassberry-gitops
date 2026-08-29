# ADR: Calibre-Web (upstream, patched) for wireless Kobo delivery

- Status: accepted, 2026-08-28. Explicitly provisional, see "When to revisit".
- Deciders: dixneuf19
- Implementation: this chart (PR #1721)

## Context

Goal: get EPUBs onto a Kobo Clara HD (2018, firmware `4.38.23697`) over Wi-Fi instead of
plugging it into a computer (a cable or dongle is not always at hand), while the Kobo shop keeps
working, and let a few friends who also own Kobos receive books the same way. Books are managed
with Calibre.

Constraints from the cluster: k0s on Raspberry Pi 4 (arm64) plus one amd64 VM, ArgoCD GitOps,
Traefik with Let's Encrypt via cert-manager, `local-path` and NFS storage, secrets in Bitwarden.
Public entry is a wildcard `*.dixneuf19.fr` through an Oracle VM doing TCP passthrough to Traefik,
so any new host name gets a valid certificate with no edge change.

Only one delivery mechanism gives a stock Kobo cable-free delivery: impersonating Kobo's private
store API. The device reads a single `api_endpoint` from `.kobo/Kobo/Kobo eReader.conf`; a server that
answers like `storeapi.kobo.com` can push its own library and forward everything else to the real
store. Alternatives were ruled out early:

- Native Dropbox / Google Drive: server-side disabled on the Clara HD, the NickelMenu unlock
  failed for Clara HD owners.
- KOReader + OPDS/Syncthing: works, but loses Kobo store DRM books, KEPUB rendering and the stock
  UI for a need that does not require it.
- Kobo beta browser downloading from a file listing, send2ereader, Kobo-UNCaGED: one-shot or
  clunky; kept as fallbacks, not a pipeline.

The API is undocumented and firmware updates change what the device asks for. Two changes in the
last year matter for this firmware: since `4.38.23552` (Nov 2025) the device calls
`POST /v1/auth/refresh`, and it follows the `library_sync` URL advertised in the `/v1/initialization`
response instead of a hardcoded path (a server that leaves it at `storeapi.kobo.com` "works" but
delivers nothing, [janeczku/calibre-web#3588](https://github.com/janeczku/calibre-web/pull/3588)).

## Decision drivers

1. Kobo sync actually works on firmware `4.38.23697` today, with no silent failure mode.
2. One user and token per Kobo, per-user visibility, so friends can be served from one instance.
3. Small patch surface and a clear exit when upstream catches up.
4. Maintenance burden on a Pi-class cluster (image size, RAM, extra databases).
5. Keeps the Calibre library format (`metadata.db`), so the data stays portable.

## Options considered

All servers implementing the Kobo sync API were tested with the same harness where practical:
start the image locally, complete first-run configuration over HTTP, create a token, then call
`/kobo/<token>/v1/initialization`, `/v1/library/sync`, `/v1/user/profile`, `/v1/auth/refresh` with
reverse-proxy headers and inspect the responses.

### Calibre-Web, upstream (`lscr.io/linuxserver/calibre-web`)

- 0.6.26: `library_sync` not rewritten (device would sync against the real store).
- 0.6.27 (2026-08-08): rewrites `library_sync` and has `/v1/auth/refresh`, fixes the Kobo-token
  IDOR, but ships two bugs that break Kobo sync on the linuxserver image: leftover debug lines that
  raise on every `/v1/user/*` call ([#3691](https://github.com/janeczku/calibre-web/issues/3691))
  and a kepubify lookup that only accepts a binary named `kepubify-linux-64bit`
  ([#3679](https://github.com/janeczku/calibre-web/issues/3679)).
- With both patched at container start: every endpoint check passes, `library_sync` and
  `image_host` point at `https://books.dixneuf19.fr`.
- 258 MB image, amd64 + arm64, ~50 MB RAM, kepubify bundled, two releases a year, maintainer
  merges small community PRs within days.

### Calibre-Web Automated (CWA, `crocodilestick/calibre-web-automated`)

- Fork of upstream (2024) with a much better ingest/UX layer: ingest folder, auto-convert with a
  bundled Calibre (also on arm64), metadata enforcement, Magic Shelves, KOReader/Hardcover sync.
- Kobo code drifted from upstream and missed both firmware-driven fixes. Tested on v4.0.6:
  `library_sync` -> `https://storeapi.kobo.com/v1/library/sync`, `POST /v1/auth/refresh` -> CWA's
  own 404 (not proxied). No issue in their tracker mentions either.
- Own regression since 4.0.4, undiagnosed: shelves sync but books never appear or fail to
  download, Clara 2E on 4.38 among reporters, only workaround is rolling back to 4.0.2
  ([#1470](https://github.com/crocodilestick/Calibre-Web-Automated/issues/1470)).
- Kobo-token IDOR open since April, unpatched on `main`
  ([#1303](https://github.com/crocodilestick/Calibre-Web-Automated/issues/1303)).
- No release since 2026-02-04, then 79 commits on `main` in two days (Aug 5-6), 77 open PRs
  (oldest April 2025). 626 MB image.

Forking CWA to fix it was considered: the first two gaps are ~35 lines to port, the IDOR two
lines, but #1470 cannot be patched without a diagnosis nobody has, and a fork means owning a
Calibre-bundled image build and rebasing onto a bursty `main`.

### Calibre-Web-NextGen (`new-usemame/Calibre-Web-NextGen`)

- Community copy of CWA started 2026-05-02, one maintainer, fixes and issue replies "largely
  produced by an AI assistant", a release every one to three days, `kobo.py` twice upstream's size.
- Has the modern routes and the IDOR fix, but its own tracker shows Kobo sync loops being
  introduced and fixed weekly. Too much churn for a "reliability first" pick.

### Grimmory (`grimmory-tools/grimmory`, BookLore successor)

- Healthiest project of the set: real team, release every one to two weeks, 233 MB image,
  in-repo Helm chart, Kobo sync as a first-class module (resources rewritten, everything unknown
  proxied to Kobo, per-user tokens, Kobo shelf, KEPUB, bidirectional progress). Reacts to
  firmware changes within weeks.
- Costs: Java (~1 GB RAM) plus MariaDB (not run on this cluster today), its own library layout
  instead of a Calibre `metadata.db`, degraded NFS support.
- Also has a live Kobo regression at decision time (`No Internet on Device` since ~v3.2.4,
  [#2457](https://github.com/grimmory-tools/grimmory/issues/2457), maintainer responsive).
- Not endpoint-tested (needs MariaDB); assessed from source and tracker.

### Komga

Mature, bidirectional Kobo sync with bundled kepubify and per-user API keys. Not a Calibre
library, manga-first UI, ~1 GB Java. Kept as the fallback with the most proven Kobo code.

### Kavita, Stump, Audiobookshelf, Ubooquity, Calibre content server

Kobo sync planned (Kavita 0.9.2), beta (Stump), or absent. Not viable today.

## Decision

Run upstream Calibre-Web `0.6.27` from the linuxserver image, with `files/10-kobo-fixes.sh`
executed by the image's `/custom-cont-init.d` hook at container start to (a) delete the two
offending debug lines from `kobo.py` and (b) hard-link `kepubify` to `kepubify-linux-64bit` and
update the stored path. Both steps are no-ops once upstream fixes them.

It is the only option whose released image passes the whole endpoint test on this firmware
after a patch that is fully understood and verifiable, it is the lightest, and it keeps the
Calibre data format so a later move to CWA (documented volume remap) or an export to Grimmory
stays cheap.

## Consequences

Positive:

- Works now, with the smallest footprint on the cluster and no new database.
- Per-user tokens and tag/shelf restrictions cover the friends use case without extra software.
- Exit paths are open in every direction: CWA reads the same `app.db` + `metadata.db`; the
  books are plain EPUB files for anything else.

Negative and accepted:

- We carry a runtime patch. It is version-specific, so app version bumps should not be
  auto-merged blindly (a Renovate rule for `lscr.io/linuxserver/calibre-web` is the intended
  guard).
- Kobo sync in every project is a moving target driven by undocumented firmware changes;
  expect roughly yearly attention, with the symptom "Sync failed" or "syncs but nothing arrives".
- Ingest is web upload or Calibre desktop, no drop folder.
- Device set-up still needs one edit of the device config: over USB when a cable is at hand, or
  through Kobo developer mode (telnet over Wi-Fi) when not. The cable-free path is documented
  but not yet exercised on the real device at decision time.

## When to revisit

- Upstream ships a release fixing #3691 and #3679: drop `customInit`.
- CWA ships a release with #1470 closed, the IDOR fixed and the `library_sync` rewrite present:
  re-run the endpoint harness and migrate if the ingest features are wanted.
- Grimmory closes #2457 and a MariaDB is acceptable on the cluster: strongest long-term option
  if Calibre-format portability stops mattering.
- The Clara HD does not sync after set-up despite passing server-side checks: fall back to Komga.
