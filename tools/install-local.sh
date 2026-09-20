#!/usr/bin/env bash
#
# Build Splash in Release with the premium features unlocked and install it on a connected device.
#
# Why this exists: the DEBUG bypass (`SPLASH_UNLOCK_PREMIUM=1`) only works when *Xcode* launches the app,
# because that is what injects the environment variable. Opening the app from the home screen gives it no
# such variable, so the bypass silently does nothing. This script instead passes the compile-time flag
# SPLASH_LOCAL_UNLOCK, which needs nothing at runtime.
#
# The resulting build has premium open unconditionally. It is for a personal device only — never TestFlight,
# never App Store Connect. `tools/release.sh` refuses to archive a binary carrying the marker this flag
# compiles in, so it cannot be shipped by accident.
#
# Usage:
#   SPLASH_TEAM_ID=XXXXXXXXXX tools/install-local.sh                 # first available device
#   SPLASH_TEAM_ID=XXXXXXXXXX tools/install-local.sh <device-udid>   # a specific one
#
# List devices with: xcrun devicectl list devices

set -euo pipefail

readonly SWIFT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../swift" && pwd)"
readonly DD="$SWIFT_DIR/build/DerivedData-local"
readonly UNLOCK_FLAG="SPLASH_LOCAL_UNLOCK"

: "${SPLASH_TEAM_ID:?falta SPLASH_TEAM_ID (el Apple Team ID, 10 caracteres)}"

log() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

device="${1:-}"
if [ -z "$device" ]; then
  device="$(xcrun devicectl list devices 2>/dev/null \
    | awk '/available \(paired\)/ { print $(NF-3); exit }')"
  [ -n "$device" ] || { echo "No hay dispositivos emparejados. Usa: xcrun devicectl list devices" >&2; exit 1; }
  log "Dispositivo: $device (primero disponible)"
fi

log "Compilando Release con $UNLOCK_FLAG"
# `$(inherited)` is not optional: replacing the whole setting drops SWIFT_PACKAGE and SPM's generated
# resource accessors stop compiling ("invalid redeclaration of 'module'").
xcodebuild \
  -project "$SWIFT_DIR/Splash.xcodeproj" \
  -scheme Splash \
  -configuration Release \
  -destination "id=$device" \
  -derivedDataPath "$DD" \
  DEVELOPMENT_TEAM="$SPLASH_TEAM_ID" \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS="\$(inherited) $UNLOCK_FLAG" \
  -allowProvisioningUpdates \
  build

app="$(find "$DD/Build/Products/Release-iphoneos" -maxdepth 1 -name 'Splash.app' | head -1)"
[ -n "$app" ] || { echo "No se encontró Splash.app" >&2; exit 1; }

# Fail loudly if the flag silently did not apply — otherwise you install a locked build and spend an hour
# wondering why the premium features are still gated.
# `grep -c`, not `grep -q`: under `set -o pipefail` a quiet grep exits on the first match, `strings` dies of
# SIGPIPE, and the pipeline reports failure exactly when the marker *is* present.
if [ "$(strings "$app/Splash" | grep -cF 'SPLASH_LOCAL_UNLOCK_BUILD' || true)" = "0" ]; then
  echo "ERROR: el binario no contiene el marcador; $UNLOCK_FLAG no se aplicó." >&2
  exit 1
fi

log "Instalando en $device"
xcrun devicectl device install app --device "$device" "$app"

log "Listo. Premium desbloqueado en esta build — solo para tu dispositivo."
