#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Runs as root before the app starts (linuxserver custom-cont-init.d hook).

# 0.6.27 left two debug lines in kobo.py that 500 every Kobo sync (janeczku/calibre-web#3691)
kobo_py=/app/calibre-web/cps/kobo.py
before=$(wc -l < "${kobo_py}")
sed -i '/limiter\.current_limit\./d' "${kobo_py}"
/lsiopy/bin/python3 -m py_compile "${kobo_py}"
echo "[kobo-fixes] kobo.py: removed $(( before - $(wc -l < "${kobo_py}") )) line(s)"

# 0.6.27 resolves kepubify by real file name and only accepts kepubify-linux-64bit (janeczku/calibre-web#3679);
# the image ships /usr/bin/kepubify, so hard-link it (a symlink fails the realpath check)
ln -f /usr/bin/kepubify /usr/bin/kepubify-linux-64bit
sqlite3 /config/app.db "update settings set config_kepubifypath='/usr/bin/kepubify-linux-64bit' where config_kepubifypath='/usr/bin/kepubify';"
echo "[kobo-fixes] kepubify path: $(sqlite3 /config/app.db 'select config_kepubifypath from settings;')"
