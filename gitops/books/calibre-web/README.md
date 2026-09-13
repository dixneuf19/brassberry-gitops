# calibre-web

[Calibre-Web](https://github.com/janeczku/calibre-web) serving the shared ebook library at
`https://books.dixneuf19.fr`, with **Kobo sync** enabled so that Kobo e-readers pull books over
Wi-Fi. One USB edit per device sets it up; every book after that arrives without a cable. The
Kobo shop keeps working: requests the server does not handle are proxied to the real Kobo store.

Why this project and not CWA, NextGen, Grimmory or Komga: see
[ADR.md](ADR.md).

## How it works

The Kobo firmware talks to `storeapi.kobo.com` through a single configurable URL
(`api_endpoint` in `.kobo/Kobo/Kobo eReader.conf`). Calibre-Web implements enough of that API to
serve a library: point the device at `https://books.dixneuf19.fr/kobo/<token>` and every tap on
"Sync" fetches the books visible to the user who owns `<token>`, converted to KEPUB on the fly by
the bundled `kepubify`. Anything else (store browsing, purchases, account) is forwarded to Kobo.

Layout:

- `lscr.io/linuxserver/calibre-web`, pinned to the **master snapshot**
  `nightly-a9782640-ls375`, not to a release. Kobo sync needs three upstream changes and only
  two of them are in a release:
  - the `library_sync` URL rewrite in the Kobo init response, shipped in 0.6.27
    ([#3588](https://github.com/janeczku/calibre-web/pull/3588)); without it recent firmware
    syncs against the real store and receives nothing;
  - the removal of leftover debug lines that 500 every sync
    ([#3691](https://github.com/janeczku/calibre-web/issues/3691), fixed in master by
    `a9782640`) and a kepubify lookup that only accepted `kepubify-linux-64bit`
    ([#3679](https://github.com/janeczku/calibre-web/issues/3679), fixed in master by
    `3a1df7b1`). Both are labelled `Fixed in Nightly` upstream and neither is in 0.6.27.

  Releases come roughly every six months (0.6.25 Aug 2025, 0.6.26 Feb 2026, 0.6.27 Aug 2026),
  so the choice was between patching the release at runtime and running the commit that
  contains the fixes. The tag names the exact upstream commit and linuxserver build, so it is
  immutable: it does not follow `nightly`, and Renovate is told not to move it
  (`renovate.json`). The snapshot is 53 commits past 0.6.27 and includes a large caliblur
  theme migration, so the web UI differs from 0.6.27 screenshots. Move to `0.6.28` when it
  ships, see [ADR.md](ADR.md).
- `/config` (app.db) and `/books` (Calibre library) on `local-path`, pinned to `k8s-worker-1`.
  An init container seeds an empty Calibre `metadata.db` on first boot.
- Traefik middleware `books-calibre-web-headers` adds `X-Scheme: https`. Calibre-Web only trusts
  `X-Scheme` / `X-Forwarded-Host` to build the absolute URLs it hands to Kobos; without it the
  device receives `http://` download links and sync silently fails.
- Two ingresses on the same host: the web UI (`/`) sits behind the cluster `traefik-basic-auth`;
  the Kobo API (`/kobo/`) has no auth challenge because a Kobo cannot answer one, the token in
  the URL is the credential. Treat the token like a password. Note this is *not* what the other
  multi-user apps here do (karakeep, immich, navidrome and jellyfin expose their own login);
  basic-auth is the repo's pattern for admin tools with no real login. It is here as a guard
  against the image's `admin`/`admin123` default, at the cost of friends carrying two sets of
  credentials, and can go once the password is changed.
- Nightly `db` tarball (sqlite `.backup` of `app.db` and `metadata.db`, 14 days), a nightly
  `rsync` mirror of the book files in `books-current/`, and a weekly `full` tarball (35 days)
  on the `calibre-web-backups` PVC on `nfs-jonbonas`. Archives are written to a temp name and
  moved into place. The mirror is what keeps book files at a 1-day RPO; it follows deletions,
  so undeleting a book needs the weekly tarball.
- First boot downloads the empty `metadata.db` from GitHub (checksummed); without outbound
  access the pod stays in `Init:Error` until it can.

## First-time server setup

1. Log in with `admin` / `admin123` at <https://books.dixneuf19.fr>, change the password.
2. Initial setup screen: library location `/books` (already seeded).
3. Admin > Basic Configuration > Feature Configuration:
   - Enable Uploads, allowed formats include `epub`
   - Enable Kobo sync
   - Proxy unknown requests to Kobo Store: **on** (keeps the shop working)
   - Server External Port: `443` (only used if the proxy headers were missing; harmless)
   - Path to Kepubify E-Book Converter: leave the preset value (Calibre-Web stores it as
     `/usr/bin`). The image ships the binary as plain `kepubify`, which this snapshot accepts
     since [#3679](https://github.com/janeczku/calibre-web/issues/3679); on 0.6.27 the same
     field fails with "Kepubify binary not found"
4. Admin > Edit Users > `admin`: create the Kobo sync token (see below) or do it from your profile.

## Kobo setup

The device needs one edit of `.kobo/Kobo/Kobo eReader.conf` over USB to point `api_endpoint` at
this server. After that everything is over Wi-Fi.

### 0. Prerequisites

- The Kobo is signed in to a Kobo account and has synced with the real store at least once.
  A device that has never paired with Kobo calls `/v1/user/add-device`, which Calibre-Web does
  not implement, and shows "Sync failed" until it has ([CWA#1476](https://github.com/crocodilestick/Calibre-Web-Automated/issues/1476)).
- Your Calibre-Web user exists, "Allow Downloads" is on.

### 1. Get the token

Calibre-Web: top-right menu > `<user>` > **Kobo Sync Token** > **Create/View**. It shows the
exact line to put in the device configuration:

```
api_endpoint=https://books.dixneuf19.fr/kobo/<token>
```

### 2. Edit the config over USB

1. Plug the Kobo into the computer, tap **Connect** on the device. It mounts as `KOBOeReader`.
2. Open `KOBOeReader/.kobo/Kobo/Kobo eReader.conf` (hidden folder) in a plain-text editor that
   keeps LF line endings. Copy it aside first as a backup.
3. Under `[OneStoreServices]`, replace the `api_endpoint=` line with the one from step 1. If the
   line is missing, add it (create the section if needed).

   ```bash
   # macOS, once the device is mounted
   cd "/Volumes/KOBOeReader/.kobo/Kobo"
   cp "Kobo eReader.conf" "Kobo eReader.conf.bak"
   grep -n api_endpoint "Kobo eReader.conf"
   sed -i '' 's#^api_endpoint=.*#api_endpoint=https://books.dixneuf19.fr/kobo/<token>#' "Kobo eReader.conf"
   grep -n api_endpoint "Kobo eReader.conf"
   ```
4. Eject safely, then let the device finish its "processing content" pass.

Nickel (the Kobo UI) holds its settings in memory and writes them back when they change, so make
the edit while the device is mounted, not over a live session. If the value is reverted later,
redo the edit the same way.

### 3. Verify

1. On the Kobo, open the beta web browser (More > Beta Features > Web browser) and load
   `https://books.dixneuf19.fr/kobo/<token>/v1/initialization`. A JSON blob means TLS, proxy
   headers and the token all work. An error page means the Kobo never reached the server.
2. Home > Sync. Books visible to your user (or on your synced shelves) appear in "My Books".

### When it reverts

`api_endpoint` survives normal syncs and, in most reports, firmware updates. It is reset by a
sign-out, a "Repair your account" or a factory reset. Redo the edit in that case (the device must
sync once with the real store again first).

## Sharing books with friends

One Calibre-Web user **per Kobo**; sharing one token across two devices only syncs the first.
Public shelves are never pushed to another user's device, so sharing works in one of two ways:

**Push by tag (you drive it).** Admin > Edit Users > friend: "Allowed Tags" = `alice`, leave
"Sync only books in selected shelves" off. Every book tagged `alice` in the library lands on
Alice's Kobo at her next sync, nothing else is visible to her.

**Self-service by shelf.** Give the friend "Allow Uploads" and tick "Sync only books in selected
shelves with Kobo" on their user. They upload their own EPUBs in the web UI, create a shelf, tick
"Sync this shelf with Kobo device", and add books to it.

Friend onboarding: create their user (Allow Downloads, optionally Allow Uploads, tags as above),
have them log in once and Create/View their Kobo token, then walk them through the "Kobo setup"
section. The USB edit is a one-off they can do themselves with the device in hand.

What to tell them before they point a device here:

- **Their Kobo talks to this server instead of Kobo.** With the store proxy on, everything the
  server does not implement is forwarded to the real store with the device's headers intact, so
  their Kobo session token, purchases and reading analytics transit this cluster.
- **A 2024 or newer Kobo will not work at all** (see Known limits). Check the model first.
- When something breaks, fixing it means editing a hidden file on their e-reader, remotely.

## Day-to-day

- Add a book: web UI > Upload (EPUB). Metadata is editable in place. Kobo devices pick it up on
  their next sync.
- Prefer **Archive** over Delete for books you want off a device; deleting in Calibre-Web does
  not remove the file from the Kobo, and deleting on the Kobo archives the book server-side.
- Uploading a book already in KEPUB format skips conversion. Plain EPUBs are converted at first
  download and the KEPUB stored as an extra format.
- Only EPUB/KEPUB sync to Kobo. PDFs never do.

## Known limits

- The Kobo aborts any request after ~30 s. A few hundred books is fine; with thousands, turn on
  "Sync only books in selected shelves" for every user.
- Store purchases go through the proxy. If a purchased (DRM) book downloads but will not open,
  or covers of store books are missing, that is the proxy
  ([calibre-web#2607](https://github.com/janeczku/calibre-web/issues/2607)); temporarily restore
  `api_endpoint=https://storeapi.kobo.com`, sync, then switch back.
- 2024 Kobos (Clara BW / Colour, Libra Colour, firmware 4.45+) need an OIDC discovery endpoint
  no Calibre-Web release implements ([CWA#1418](https://github.com/crocodilestick/Calibre-Web-Automated/issues/1418)).
  Legacy devices on the 4.38 branch (Clara HD, Clara 2E, Libra 2, ...) are not affected.

## Restore

Archive layout: `db/app.db`, `db/metadata.db`, and in `full` archives `books/<library files>`.
`books-current/` on the backup volume is last night's copy of the book files.

Suspend ArgoCD first, otherwise `selfHeal` scales the deployment back up while you are copying
files underneath it.

```bash
argocd app set calibre-web --sync-policy none
kubectl -n books scale deploy calibre-web --replicas=0
# in a pod mounting the three PVCs, or from the NAS:
tar xzf calibre-web-full-<stamp>.tar.gz -C /tmp/restore
cp /tmp/restore/db/app.db /config/app.db
rsync -a --delete /tmp/restore/books/ /books/
cp /tmp/restore/db/metadata.db /books/metadata.db   # or from a newer calibre-web-db-<stamp> archive
chown -R 1000:1000 /config /books
kubectl -n books scale deploy calibre-web --replicas=1
argocd app set calibre-web --sync-policy automated --self-heal --auto-prune
```

For book files alone, `rsync -a /backup/books-current/ /books/` restores last night instead of
last week. If the `books` PVC is lost entirely, the init container seeds a fresh empty
`metadata.db` and the pod comes up **healthy with an empty library**: the symptom of a lost
volume is missing books, not a failing pod.
