#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$ROOT_DIR/ios/CreativeHub"
ARTIFACT_DIR="$PROJECT_DIR/BuildArtifacts"
APP_PATH="${1:-}"
IPA_PATH="$ARTIFACT_DIR/CreativeHub-PersonalTeam.ipa"

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

find_latest_app() {
  local products_dir="$PROJECT_DIR/DerivedData/Build/Products"
  [[ -d "$products_dir" ]] || return 1
  find "$products_dir" -path '*-iphoneos/CreativeHub.app' -type d -prune -print0 \
    | xargs -0 ls -td 2>/dev/null \
    | head -n 1
}

if [[ -z "$APP_PATH" ]]; then
  APP_PATH="$(find_latest_app || true)"
fi

[[ -n "$APP_PATH" ]] || fail "CreativeHub.app was not provided and no iPhoneOS build was found under ios/CreativeHub/DerivedData."
[[ -d "$APP_PATH" ]] || fail "CreativeHub.app does not exist: $APP_PATH"
[[ -f "$APP_PATH/Info.plist" ]] || fail "Invalid app bundle: missing Info.plist in $APP_PATH"

case "$APP_PATH" in
  *iphonesimulator*) fail "Simulator app bundles cannot be packaged for SideStore: $APP_PATH" ;;
esac

case "$APP_PATH" in
  *-iphoneos/CreativeHub.app|*/CreativeHub.app) ;;
  *) fail "Expected a CreativeHub.app bundle, got: $APP_PATH" ;;
esac

mkdir -p "$ARTIFACT_DIR"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/Payload"
/usr/bin/ditto "$APP_PATH" "$TMP_DIR/Payload/CreativeHub.app"
rm -f "$IPA_PATH"

(
  cd "$TMP_DIR"
  /usr/bin/zip -qry "$IPA_PATH" Payload
)

printf 'Created %s\n' "$IPA_PATH"
