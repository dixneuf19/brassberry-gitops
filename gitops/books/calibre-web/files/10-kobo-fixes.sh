#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Runs as root before the app starts (linuxserver custom-cont-init.d hook). The hook ignores
# the exit code, so every step below guards itself and none can prevent the others.

# 0.6.27 resolves kepubify by real file name and only accepts kepubify-linux-64bit
# (janeczku/calibre-web#3679); the image ships /usr/bin/kepubify. A symlink fails the realpath
# check, a hard link passes it.
if [ -x /usr/bin/kepubify ]; then
  ln -f /usr/bin/kepubify /usr/bin/kepubify-linux-64bit
  echo "[kobo-fixes] kepubify: hard-linked to /usr/bin/kepubify-linux-64bit"
else
  echo "[kobo-fixes] kepubify: /usr/bin/kepubify missing or not executable, skipped"
fi

# The image presets config_kepubifypath=/usr/bin/kepubify on first boot; point it at the
# hard link. Only matches on first boot: once saved from the UI the app stores the directory.
if [ -f /config/app.db ]; then
  sqlite3 /config/app.db "update settings set config_kepubifypath='/usr/bin/kepubify-linux-64bit' where config_kepubifypath='/usr/bin/kepubify';"
  echo "[kobo-fixes] kepubify path in app.db: $(sqlite3 /config/app.db 'select config_kepubifypath from settings;')"
fi

# 0.6.27 left two debug lines in kobo.py that 500 every Kobo sync (janeczku/calibre-web#3691)
kobo_py=/app/calibre-web/cps/kobo.py
if [ -f "${kobo_py}" ]; then
  matches=$(grep -c 'limiter\.current_limit\.' "${kobo_py}" || true)
  if [ "${matches}" -gt 0 ]; then
    sed -i '/limiter\.current_limit\./d' "${kobo_py}"
    /lsiopy/bin/python3 -m py_compile "${kobo_py}"
    echo "[kobo-fixes] kobo.py: removed ${matches} line(s)"
  else
    echo "[kobo-fixes] kobo.py: nothing to patch, upstream fixed #3691, customInit can go"
  fi
else
  echo "[kobo-fixes] kobo.py: ${kobo_py} not found, image layout changed, patch skipped"
fi
