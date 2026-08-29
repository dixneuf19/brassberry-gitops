#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Nightly: sqlite3 .backup of the two databases (safe with the app running) into a small
# db tarball. On FULL_BACKUP_WEEKDAY: additionally a tarball of the whole book library.
# Archives are written to a temp name and moved into place, so a killed job never leaves
# a truncated file under the canonical name. Pruning runs first so the volume is never
# filled by a new archive before old ones are reclaimed.

CONFIG_DIR="${CONFIG_DIR:-/config}"
BOOKS_DIR="${BOOKS_DIR:-/books}"
BACKUP_DIR="${BACKUP_DIR:-/backup}"
DB_RETENTION_DAYS="${DB_RETENTION_DAYS:?required}"
FULL_RETENTION_DAYS="${FULL_RETENTION_DAYS:?required}"
FULL_BACKUP_WEEKDAY="${FULL_BACKUP_WEEKDAY:?required}" # 1 = Monday ... 7 = Sunday

stamp="$(date +%Y-%m-%d-%H%M)"
work="${BACKUP_DIR}/work"
trap 'rm -rf "${work}" "${BACKUP_DIR}"/.calibre-web-*.tmp' EXIT
rm -rf "${work}" && mkdir -p "${work}/db"

find "${BACKUP_DIR}" -maxdepth 1 -name 'calibre-web-db-*.tar.gz' \
  -mtime "+${DB_RETENTION_DAYS}" -delete
find "${BACKUP_DIR}" -maxdepth 1 -name 'calibre-web-full-*.tar.gz' \
  -mtime "+${FULL_RETENTION_DAYS}" -delete

sqlite3 "${CONFIG_DIR}/app.db" ".backup '${work}/db/app.db'"
sqlite3 "${work}/db/app.db" "PRAGMA integrity_check;" | grep -qx ok
sqlite3 "${BOOKS_DIR}/metadata.db" ".backup '${work}/db/metadata.db'"
sqlite3 "${work}/db/metadata.db" "PRAGMA integrity_check;" | grep -qx ok

archive() { # name, tar args...
  local name="$1"; shift
  local tmp="${BACKUP_DIR}/.${name}.tmp"
  tar czf "${tmp}" "$@"
  mv "${tmp}" "${BACKUP_DIR}/${name}"
  echo "wrote ${name}"
}

archive "calibre-web-db-${stamp}.tar.gz" -C "${work}" db

if [ "$(date +%u)" = "${FULL_BACKUP_WEEKDAY}" ]; then
  # Archive layout: db/app.db, db/metadata.db, books/<library files>
  archive "calibre-web-full-${stamp}.tar.gz" \
    -C "${work}" db \
    -C "$(dirname "${BOOKS_DIR}")" \
    --exclude="$(basename "${BOOKS_DIR}")/metadata.db" \
    --exclude="$(basename "${BOOKS_DIR}")/metadata.db-*" \
    "$(basename "${BOOKS_DIR}")"
fi

echo "backup done:"
ls -lh "${BACKUP_DIR}"
