#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Consistent nightly backup of calibre-web: sqlite3 .backup for the two
# databases (safe with the app running), plain tar for the book files.

CONFIG_DIR="${CONFIG_DIR:-/config}"
BOOKS_DIR="${BOOKS_DIR:-/books}"
BACKUP_DIR="${BACKUP_DIR:-/backup}"
RETENTION_DAYS="${RETENTION_DAYS:?required}"

stamp="$(date +%Y-%m-%d-%H%M)"
work="${BACKUP_DIR}/work"
trap 'rm -rf "${work}"' EXIT
rm -rf "${work}" && mkdir -p "${work}"

sqlite3 "${CONFIG_DIR}/app.db" ".backup '${work}/app.db'"
sqlite3 "${work}/app.db" "PRAGMA integrity_check;" | grep -qx ok

sqlite3 "${BOOKS_DIR}/metadata.db" ".backup '${work}/metadata.db'"
sqlite3 "${work}/metadata.db" "PRAGMA integrity_check;" | grep -qx ok

tar czf "${BACKUP_DIR}/calibre-web-${stamp}.tar.gz" \
  -C "${work}" app.db metadata.db \
  -C "${BOOKS_DIR}" --exclude='./metadata.db' --exclude='./metadata.db-*' .

find "${BACKUP_DIR}" -maxdepth 1 -name 'calibre-web-*.tar.gz' \
  -mtime "+${RETENTION_DAYS}" -delete

echo "backup done:"
ls -lh "${BACKUP_DIR}"
