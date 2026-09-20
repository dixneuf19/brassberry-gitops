# ADR: Calibre-Web (upstream master snapshot) for wireless Kobo delivery

- Status: accepted, 2026-08-28. Explicitly provisional, see "When to revisit".
- Deciders: dixneuf19
- Implementation: this chart (PR #1721)

## Context

Goal: get EPUBs onto a Kobo Clara HD (2018, firmware `4.38.23697`) over Wi-Fi rather than
plugging it into a computer for every book, while the Kobo shop keeps working, and let a few
friends who also own Kobos receive books the same way. A one-time USB edit of the device config
is acceptable; a cable for every delivery is what this avoids. Books are managed with Calibre.

Constraints from the cluster: k0s on Raspberry Pi 4 (arm64) plus one amd64 VM, ArgoCD GitOps,
Traefik with Let's Encrypt via cert-manager, `local-path` and NFS storage, secrets in Bitwarden.
Public entry is a wildcard `*.dixneuf19.fr` through an Oracle VM doing TCP passthrough to Traefik,
so any new host name gets a valid certificate with no edge change.

Only one mechanism delivers new books to a stock Kobo without a cable: impersonating Kobo's private
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
- Both are **fixed in master** (`a9782640` and `3a1df7b1`, labelled `Fixed in Nightly`) and in
  no release. Releases are roughly six months apart (0.6.25 Aug 2025, 0.6.26 Feb 2026,
  0.6.27 Aug 2026), so "wait for the fix" means waiting for 0.6.28, not for a patch to be
  written.
- With both fixes present: every endpoint check passes, `library_sync` and `image_host` point
  at `https://books.dixneuf19.fr`.
- 258 MB image, amd64 + arm64, ~50 MB RAM, kepubify bundled, two releases a year, maintainer
  merges small community PRs within days.

### Calibre-Web Automated (CWA, `crocodilestick/calibre-web-automated`)

- Fork of upstream (2024) with a much better ingest/UX layer: ingest folder, auto-convert with a
  bundled Calibre (also on arm64), metadata enforcement, Magic Shelves, KOReader/Hardcover sync.
- Kobo code drifted from upstream and missed both firmware-driven fixes. Tested on v4.0.6:
  `library_sync` -> `https://storeapi.kobo.com/v1/library/sync`, `POST /v1/auth/refresh` -> CWA's
  own 404 (not proxied). No issue in their tracker mentions either.
- Re-checked 2026-09-13 against `main` and the newest `dev` build, not just the release: still
  no `library_sync` rewrite (the hardcoded store URL is the only occurrence in `cps/kobo.py`)
  and still only `/v1/auth/device`. The gap is not a stale release, it is the current code.
- Own regression since 4.0.4, undiagnosed: shelves sync but books never appear or fail to
  download, Clara 2E on 4.38 among reporters, only workaround is rolling back to 4.0.2
  ([#1470](https://github.com/crocodilestick/Calibre-Web-Automated/issues/1470)).
- Kobo-token IDOR open since April, unpatched on `main`
  ([#1303](https://github.com/crocodilestick/Calibre-Web-Automated/issues/1303)).
- No release since 2026-02-04 (all seven v4.0.x tags landed in one week), then 79 commits on
  `main` in two days (Aug 5-6) and nothing since; 77 open PRs (oldest April 2025). 626 MB image.
  Running an unreleased upstream snapshot forfeits any "released software is safer" argument
  against CWA, so this decision does not use one: it rests on the three gaps above.

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

Run upstream Calibre-Web from the linuxserver image, pinned to the master snapshot
`nightly-a9782640-ls375` (upstream commit `a9782640`, the commit that fixes #3691), which
contains both Kobo sync fixes. The tag names the commit and the build, so it is immutable and
does not follow the moving `nightly` tag; Renovate still opens PRs for this image but never
merges them itself (`automerge: false` on every update type, digests included), so moving off
this snapshot is always a deliberate act.

Three ways to get those two fixes were considered:

1. **Patch the release at runtime** (a script in `/custom-cont-init.d` that hard-links
   `kepubify` and seds `kobo.py`). Implemented and verified first, then dropped: it works, but
   every failure mode is silent (the hook ignores exit codes), and the sed has to be kept in
   step with what upstream actually deleted.
2. **Build a custom image in `images/`** (the `burrito-runner` pattern), which makes the patch
   immutable and fails the build loudly once upstream fixes it, at the cost of a build
   pipeline, a GHCR package and a rebuild per weekly linuxserver rebase.
3. **Run the commit that has the fixes.** Chosen: no patch to maintain, no pipeline, and the
   thing that ships is the code upstream will release.

The cost of (3) is that the snapshot is 53 commits past 0.6.27 and carries changes nobody
released yet, chiefly a large caliblur theme migration (`flask-themes2`) and a rework of how
binary paths are configured. That is a UI-surface risk, not a data risk: the Calibre data format
is unchanged, so a later move to CWA (documented volume remap) or an export to Grimmory stays
cheap, and rolling back means pinning 0.6.27 again.

## Consequences

Positive:

- Works now, with the smallest footprint on the cluster and no new database.
- Per-user tokens and tag/shelf restrictions cover the friends use case without extra software.
- Exit paths are open in every direction: CWA reads the same `app.db` + `metadata.db`; the
  books are plain EPUB files for anything else.

Negative and accepted:

- We run unreleased code. No CVE feed, no release notes, and any bug in those 53 commits is
  ours to find; the mitigation is that the image never moves on its own (immutable tag, no
  Renovate automerge of any update type) and that 0.6.27 is one value away.
- Kobo sync in every project is a moving target driven by undocumented firmware changes;
  expect roughly yearly attention, with the symptom "Sync failed" or "syncs but nothing arrives".
  When the next firmware change lands, the fix will reach master long before it reaches a
  release, which is the same bet we are making here.
- Ingest is web upload or Calibre desktop, no drop folder.
- The web UI sits behind the cluster-wide basic-auth (the image ships `admin`/`admin123` and
  the Kobo API needs an unauthenticated path), so friends carry two sets of credentials until
  that is revisited. This is the repo's pattern for admin tools, not for apps with their own
  login (karakeep, immich, navidrome and jellyfin carry none).
- Friends on a 2024-or-newer Kobo (Clara BW / Colour, Libra Colour, firmware 4.45+) cannot be
  served at all: those devices expect an OIDC discovery endpoint that upstream implements
  nowhere, in no release and not on master. CWA does implement
  `/oauth/.well-known/openid-configuration` (`aa97e0ec`), and it is still not enough:
  [CWA#1418](https://github.com/crocodilestick/Calibre-Web-Automated/issues/1418) is open and
  [CWA#1476](https://github.com/crocodilestick/Calibre-Web-Automated/issues/1476) reports
  4.45 pairing still failing on a build that contains it. The sharing use case covers
  pre-2024 devices only; Komga is the project that handles them.
- A factory-reset or never-paired device calls `POST /v1/user/add-device` during pairing, which
  neither project implements (upstream
  [#2477](https://github.com/janeczku/calibre-web/issues/2477), open since 2022), and aborts
  with "Sync failed" before it ever reaches `library/sync`. Devices that have already paired
  with the real Kobo store never call it, which is why the README makes that a prerequisite.
- Their devices talk to this cluster: with the store proxy on, Kobo session headers, purchases
  and reading analytics pass through it.
- Device set-up still needs one edit of the device config over USB, once per device, done with
  the Kobo in hand. Every book after that arrives over Wi-Fi.

## When to revisit

- Upstream ships `0.6.28` (it will contain #3691 and #3679): move the image pin from the master
  snapshot back to the release tag, re-run the endpoint harness, and this whole trade-off ends.
- A friend turns up with a 2024-or-newer Kobo: Calibre-Web cannot serve it at any version, so
  that is a Komga question, not a version bump.
- CWA ships a release with #1470 closed, the IDOR fixed and the `library_sync` rewrite present:
  re-run the endpoint harness and migrate if the ingest features are wanted.
- Grimmory closes #2457 and a MariaDB is acceptable on the cluster: strongest long-term option
  if Calibre-format portability stops mattering.
- The Clara HD does not sync after set-up despite passing server-side checks: fall back to Komga.
