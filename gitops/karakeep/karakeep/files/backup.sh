#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Consistent nightly backup of karakeep: sqlite3 .backup for the DB
# (safe with the app running), plain tar for the write-once assets.

DATA_DIR="${DATA_DIR:-/data}"
BACKUP_DIR="${BACKUP_DIR:-/backup}"
RETENTION_DAYS="${RETENTION_DAYS:?required}"

stamp="$(date +%Y-%m-%d-%H%M)"
work="${BACKUP_DIR}/work"
trap 'rm -rf "${work}"' EXIT
rm -rf "${work}" && mkdir -p "${work}"

sqlite3 "${DATA_DIR}/db.db" ".backup '${work}/db.db'"
sqlite3 "${work}/db.db" "PRAGMA integrity_check;" | grep -qx ok

tar czf "${BACKUP_DIR}/karakeep-${stamp}.tar.gz" \
  -C "${work}" db.db \
  -C "${DATA_DIR}" assets

find "${BACKUP_DIR}" -maxdepth 1 -name 'karakeep-*.tar.gz' \
  -mtime "+${RETENTION_DAYS}" -delete

echo "backup done:"
ls -lh "${BACKUP_DIR}"
