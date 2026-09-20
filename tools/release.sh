#!/usr/bin/env bash
#
# Archive, export and (optionally) upload Splash to App Store Connect.
#
# The Apple team id is deliberately NOT stored in project.pbxproj or in a committed plist — it is injected
# here at build time from the environment, and the export options are rendered from a template into a
# temporary file that never lands in the working tree.
#
# Usage:
#   SPLASH_TEAM_ID=XXXXXXXXXX tools/release.sh archive    # archive only
#   SPLASH_TEAM_ID=XXXXXXXXXX tools/release.sh export     # archive + export .ipa
#   SPLASH_TEAM_ID=XXXXXXXXXX tools/release.sh upload     # archive + export + upload to ASC
#
# Upload additionally needs an App Store Connect API key:
#   ASC_KEY_ID, ASC_ISSUER_ID and a .p8 at ~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8

set -euo pipefail

readonly ACTION="${1:-export}"
readonly SWIFT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../swift" && pwd)"
readonly BUILD_DIR="$SWIFT_DIR/build"
readonly ARCHIVE="$BUILD_DIR/Splash.xcarchive"
readonly EXPORT_DIR="$BUILD_DIR/export"

: "${SPLASH_TEAM_ID:?falta SPLASH_TEAM_ID (el Apple Team ID, 10 caracteres)}"

log() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

do_archive() {
  log "Archivando (Release, generic/platform=iOS)"
  rm -rf "$ARCHIVE"
  xcodebuild \
    -project "$SWIFT_DIR/Splash.xcodeproj" \
    -scheme Splash \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE" \
    DEVELOPMENT_TEAM="$SPLASH_TEAM_ID" \
    archive

  assert_not_locally_unlocked
}

# A build made by tools/install-local.sh has premium open unconditionally. Shipping one would give the
# feature away to everyone and make the paywall dead code, so refuse rather than trust the operator to
# remember which build is which.
assert_not_locally_unlocked() {
  local binary="$ARCHIVE/Products/Applications/Splash.app/Splash"
  # `grep -c` rather than `grep -q`: with `set -o pipefail`, a quiet grep that exits on first match makes
  # the pipeline fail, which here would mean the guard silently *not* firing on the builds it exists to stop.
  local found=0
  [ -f "$binary" ] && found="$(strings "$binary" | grep -cF 'SPLASH_LOCAL_UNLOCK_BUILD' || true)"
  if [ "$found" != "0" ]; then
    echo >&2
    echo "ABORTADO: este archive se compiló con SPLASH_LOCAL_UNLOCK (premium abierto sin compra)." >&2
    echo "Esa build es solo para dispositivo personal. Recompila sin ese flag." >&2
    exit 1
  fi
}

do_export() {
  log "Exportando .ipa"
  # Render the template with the real team id into a temp file, so the id is never written to the repo.
  local options
  options="$(mktemp -t splash-export-options).plist"
  trap 'rm -f "$options"' RETURN
  sed "s/__DEVELOPMENT_TEAM__/$SPLASH_TEAM_ID/" \
    "$SWIFT_DIR/ExportOptions.template.plist" > "$options"

  rm -rf "$EXPORT_DIR"
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportOptionsPlist "$options" \
    -exportPath "$EXPORT_DIR"
  log "Listo: $(find "$EXPORT_DIR" -name '*.ipa')"
}

do_upload() {
  : "${ASC_KEY_ID:?falta ASC_KEY_ID}"
  : "${ASC_ISSUER_ID:?falta ASC_ISSUER_ID}"
  local ipa
  ipa="$(find "$EXPORT_DIR" -name '*.ipa' | head -1)"
  [ -n "$ipa" ] || { echo "No hay .ipa en $EXPORT_DIR" >&2; exit 1; }

  log "Validando antes de subir"
  xcrun altool --validate-app -f "$ipa" -t ios \
    --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

  log "Subiendo a App Store Connect"
  xcrun altool --upload-app -f "$ipa" -t ios \
    --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
}

case "$ACTION" in
  archive) do_archive ;;
  export)  do_archive && do_export ;;
  upload)  do_archive && do_export && do_upload ;;
  *) echo "Uso: $0 [archive|export|upload]" >&2; exit 2 ;;
esac
