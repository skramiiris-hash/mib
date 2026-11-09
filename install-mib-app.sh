#!/bin/bash
# MIB_INSTALLER - installs the MIB launcher app into ~/Applications.
# Clicking MIB starts OBS (remote control + virtual camera on, Live scene) and opens the MIB web app.
# Usage:  curl -fsSL https://raw.githubusercontent.com/skramiiris-hash/mib/main/install-mib-app.sh -o /tmp/mib.sh && bash /tmp/mib.sh
set -e
APP="$HOME/Applications/MIB.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cat > "$APP/Contents/MacOS/MIB" <<'LAUNCHER'
#!/bin/bash
# MIB launcher: makes sure OBS is running (remote control on, virtual camera on, Live scene),
# opens MIB in its own Chrome window already logged in to OBS, and keeps itself up to date.
URL="https://skramiiris-hash.github.io/mib/"
INSTALLER_URL="https://raw.githubusercontent.com/skramiiris-hash/mib/main/install-mib-app.sh"
RES="$(cd "$(dirname "$0")/../Resources" && pwd)"
CONF="$HOME/Library/Application Support/obs-studio/plugin_config/obs-websocket/config.json"

if ! pgrep -xq "OBS"; then
  # Turn on OBS's remote control if it's off (only possible while OBS is closed)
  if [ -f "$CONF" ] && [ "$(plutil -extract server_enabled raw -o - "$CONF" 2>/dev/null)" != "true" ]; then
    plutil -replace server_enabled -bool YES "$CONF" 2>/dev/null
  fi
  open -g -a "OBS" --args --startvirtualcam --scene "Live" --disable-shutdown-check
  # wait (max ~15s) until OBS's remote-control port is up, so MIB connects straight away
  for i in $(seq 1 30); do
    nc -z 127.0.0.1 4455 >/dev/null 2>&1 && break
    sleep 0.5
  done
fi

# Hand OBS's password to MIB. It never leaves this Mac: the part after # isn't sent anywhere,
# and MIB saves it and removes it from the address immediately.
HASH=""
if [ -f "$CONF" ]; then
  PW="$(plutil -extract server_password raw -o - "$CONF" 2>/dev/null)"
  PORT="$(plutil -extract server_port raw -o - "$CONF" 2>/dev/null)"
  if [ -n "$PW" ]; then
    PW_ENC="$(osascript -l JavaScript -e 'function run(a){return encodeURIComponent(a[0])}' "$PW" 2>/dev/null)"
    [ -n "$PW_ENC" ] && HASH="#pw=${PW_ENC}&port=${PORT:-4455}"
  fi
fi

if [ -d "/Applications/Google Chrome.app" ] || [ -d "$HOME/Applications/Google Chrome.app" ]; then
  open -na "Google Chrome" --args --app="${URL}${HASH}" --window-size=420,1000
else
  open "${URL}${HASH}"
fi

# Self-update: fetch the latest installer from GitHub; if it changed, reinstall (applies from the next launch).
nohup bash -c '
  NEW="$(mktemp)"
  if curl -fsSL --max-time 15 "'"$INSTALLER_URL"'" -o "$NEW" \
     && head -1 "$NEW" | grep -q "^#!/bin/bash" \
     && grep -q "MIB_INSTALLER" "$NEW" \
     && ! cmp -s "$NEW" "'"$RES"'/installer.sh"; then
    sleep 3; bash "$NEW" >/dev/null 2>&1
  fi
  rm -f "$NEW"
' >/dev/null 2>&1 &
disown 2>/dev/null
exit 0
LAUNCHER
chmod +x "$APP/Contents/MacOS/MIB"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>MIB</string>
  <key>CFBundleDisplayName</key><string>MIB</string>
  <key>CFBundleIdentifier</key><string>io.github.skramiiris-hash.mib</string>
  <key>CFBundleVersion</key><string>2.0</string>
  <key>CFBundleShortVersionString</key><string>2.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>MIB</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

# Icon (sunglasses). Needs no extra software: Quick Look renders the SVG, iconutil builds the .icns.
if [ ! -f "$APP/Contents/Resources/AppIcon.icns" ]; then
  TMP="$(mktemp -d)"
  cat > "$TMP/icon.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><defs><linearGradient id="l" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3a3f47"/><stop offset="1" stop-color="#050506"/></linearGradient></defs><rect width="64" height="64" rx="14" fill="#111214"/><path d="M7 25.5h50" stroke="#c9cdd3" stroke-width="2.6" stroke-linecap="round"/><path d="M9.5 25.5h20.5c0 8.5-3.5 13.5-10.5 13.5S9.5 34 9.5 25.5z" fill="url(#l)" stroke="#c9cdd3" stroke-width="2"/><path d="M34 25.5h20.5c0 8.5-3.5 13.5-10 13.5S34 34 34 25.5z" fill="url(#l)" stroke="#c9cdd3" stroke-width="2"/><path d="M13.5 29l5-2.5M38 29l5-2.5" stroke="#fff" stroke-opacity=".55" stroke-width="1.8" stroke-linecap="round"/><text x="32" y="54" text-anchor="middle" font-family="Helvetica,Arial,sans-serif" font-size="9.5" font-weight="700" letter-spacing="2" fill="#c9cdd3">MIB</text></svg>
SVG
  if qlmanage -t -s 1024 -o "$TMP" "$TMP/icon.svg" >/dev/null 2>&1 && [ -f "$TMP/icon.svg.png" ]; then
    SET="$TMP/AppIcon.iconset"; mkdir -p "$SET"
    for s in 16 32 128 256 512; do
      sips -z $s $s "$TMP/icon.svg.png" --out "$SET/icon_${s}x${s}.png" >/dev/null
      d=$((s*2)); sips -z $d $d "$TMP/icon.svg.png" --out "$SET/icon_${s}x${s}@2x.png" >/dev/null
    done
    iconutil -c icns "$SET" -o "$APP/Contents/Resources/AppIcon.icns" && echo "Icon installed."
  else
    echo "Icon skipped (app still works)."
  fi
  rm -rf "$TMP"
fi

# Keep a copy of this installer so the app can tell when GitHub has a newer one.
[ -f "$0" ] && cp "$0" "$APP/Contents/Resources/installer.sh"
touch "$APP"
echo "MIB installed in $APP"
