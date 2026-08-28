# calibre-web

[Calibre-Web](https://github.com/janeczku/calibre-web) serving the shared ebook library at
`https://books.dixneuf19.fr`, with **Kobo sync** enabled so that Kobo e-readers pull books over
Wi-Fi without ever being plugged into a computer. The Kobo shop keeps working: requests the
server does not handle are proxied to the real Kobo store.

## How it works

The Kobo firmware talks to `storeapi.kobo.com` through a single configurable URL
(`api_endpoint` in `.kobo/Kobo/Kobo eReader.conf`). Calibre-Web implements enough of that API to
serve a library: point the device at `https://books.dixneuf19.fr/kobo/<token>` and every tap on
"Sync" fetches the books visible to the user who owns `<token>`, converted to KEPUB on the fly by
the bundled `kepubify`. Anything else (store browsing, purchases, account) is forwarded to Kobo.

Layout:

- `lscr.io/linuxserver/calibre-web` `0.6.27`, needed because it is the first release that
  rewrites the `library_sync` URL in the Kobo init response (without it, recent firmware syncs
  against the real store and receives nothing, [#3588](https://github.com/janeczku/calibre-web/pull/3588)).
  0.6.27 also shipped two bugs that break Kobo sync on this image: leftover debug lines that
  500 every sync ([#3691](https://github.com/janeczku/calibre-web/issues/3691)) and a kepubify
  lookup that only accepts a binary named `kepubify-linux-64bit`
  ([#3679](https://github.com/janeczku/calibre-web/issues/3679), so saving the Feature
  Configuration fails with "Kepubify binary not found"). `files/10-kobo-fixes.sh`, mounted in
  `/custom-cont-init.d`, patches both at container start; each step is a no-op once upstream
  fixes it, then `customInit.enabled` can be dropped.
- `/config` (app.db) and `/books` (Calibre library) on `local-path`, pinned to `k8s-worker-1`.
  An init container seeds an empty Calibre `metadata.db` on first boot.
- Traefik middleware `books-calibre-web-headers` adds `X-Scheme: https`. Calibre-Web only trusts
  `X-Scheme` / `X-Forwarded-Host` to build the absolute URLs it hands to Kobos; without it the
  device receives `http://` download links and sync silently fails.
- **No basic-auth on the ingress.** Kobo devices cannot answer an auth challenge; the token in the
  URL is the credential. Treat the token like a password.
- Nightly backup (sqlite `.backup` of `app.db` and `metadata.db`, tar of the book files) to the
  `calibre-web-backups` PVC on `nfs-jonbonas`, 14 days retention.

## First-time server setup

1. Log in with `admin` / `admin123` at <https://books.dixneuf19.fr>, change the password.
2. Initial setup screen: library location `/books` (already seeded).
3. Admin > Basic Configuration > Feature Configuration:
   - Enable Uploads, allowed formats include `epub`
   - Enable Kobo sync
   - Proxy unknown requests to Kobo Store: **on** (keeps the shop working)
   - Server External Port: `443`
   - Path to Kepubify E-Book Converter: leave the preset value (Calibre-Web stores it as `/usr/bin`)
4. Admin > Edit Users > `admin`: create the Kobo sync token (see below) or do it from your profile.

## Kobo setup without a USB cable

Everything happens over Wi-Fi through Kobo's hidden developer mode, which starts a telnet server
on the device (root, no password). Do this on the home network only and switch it off afterwards.

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

### 2. Enable developer mode on the Kobo

1. Home screen > search box > type `devmodeon` > search. The result page says "0 results" but a
   new **Settings > Device information > Developer options** menu appears.
2. In Developer options, enable **Force Wi-Fi on** so the connection stays up while you work.
3. Find the Kobo's IP address: your router's DHCP lease list, or `arp -a` after pinging the
   broadcast address from the Mac. The hostname is usually the device serial.

### 3. Edit the config over telnet

macOS ships `nc`; `brew install telnet` gives a nicer client.

```bash
telnet <kobo-ip>          # or: nc <kobo-ip> 23
# login: root, empty password
cd "/mnt/onboard/.kobo/Kobo"
cp "Kobo eReader.conf" "Kobo eReader.conf.bak"
grep -n api_endpoint "Kobo eReader.conf"
sed -i 's#^api_endpoint=.*#api_endpoint=https://books.dixneuf19.fr/kobo/<token>#' "Kobo eReader.conf"
grep -n api_endpoint "Kobo eReader.conf"
sync
reboot
```

If the line is missing, add it under the `[OneStoreServices]` section (create the section if
needed). The file uses LF line endings; do not copy it through an editor that converts them.

Nickel (the Kobo UI) keeps its settings in memory and writes them back when they change. If the
edit is reverted after the reboot, redo it with Nickel frozen so it cannot overwrite the file:

```bash
killall -STOP nickel
sed -i 's#^api_endpoint=.*#api_endpoint=https://books.dixneuf19.fr/kobo/<token>#' "/mnt/onboard/.kobo/Kobo/Kobo eReader.conf"
sync
reboot -f
```

### 4. Verify and clean up

1. On the Kobo, open the beta web browser (More > Beta Features > Web browser) and load
   `https://books.dixneuf19.fr/kobo/<token>/v1/initialization`. A JSON blob means TLS, proxy
   headers and the token all work. An error page means the Kobo never reached the server.
2. Home > Sync. Books visible to your user (or on your synced shelves) appear in "My Books".
3. Search `devmodeoff` to turn developer mode (and telnet) back off.

### When it reverts

`api_endpoint` survives normal syncs and, in most reports, firmware updates. It is reset by a
sign-out, a "Repair your account" or a factory reset. Redo steps 2 to 4 in that case (the device
must sync once with the real store again first).

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
have them log in once and Create/View their Kobo token, then walk them through the "Kobo setup
without a USB cable" section on their own Wi-Fi.

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

```bash
kubectl -n books scale deploy calibre-web --replicas=0
# in a pod mounting the three PVCs, or from the NAS:
tar xzf calibre-web-<stamp>.tar.gz -C /tmp/restore
cp /tmp/restore/app.db /config/app.db
rsync -a --delete /tmp/restore/ /books/   # includes metadata.db
kubectl -n books scale deploy calibre-web --replicas=1
```
