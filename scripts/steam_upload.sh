#!/usr/bin/env bash
# Uploads build/windows and build/linux to Steam with steamcmd (manual alternative to CI).
#   STEAM_USERNAME=... STEAM_APP_ID=... STEAM_DEPOT_WINDOWS=... STEAM_DEPOT_LINUX=... \
#   [STEAM_BRANCH=beta] [BUILD_DESC="..."] scripts/steam_upload.sh
# The first login asks for the Steam Guard code; steamcmd caches it afterwards.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${STEAM_USERNAME:?}" "${STEAM_APP_ID:?}" "${STEAM_DEPOT_WINDOWS:?}" "${STEAM_DEPOT_LINUX:?}"
BRANCH="${STEAM_BRANCH:-}"
DESC="${BUILD_DESC:-Last Industry $(git describe --tags --always)}"
WORK=build/steam
rm -rf "$WORK" && mkdir -p "$WORK/output"
ROOT="$(pwd)/build"
render() {
	sed -e "s|@APP_ID@|$STEAM_APP_ID|g" -e "s|@DEPOT_WINDOWS@|$STEAM_DEPOT_WINDOWS|g" \
		-e "s|@DEPOT_LINUX@|$STEAM_DEPOT_LINUX|g" -e "s|@BRANCH@|$BRANCH|g" -e "s|@DESC@|$DESC|g" \
		-e "s|@ROOT@|$ROOT|g" -e "s|@OUTPUT@|$(pwd)/$WORK/output|g" "$1" > "$2"
}
render steam/app_build.vdf "$WORK/app_build.vdf"
render steam/depot_windows.vdf "$WORK/depot_windows.vdf"
render steam/depot_linux.vdf "$WORK/depot_linux.vdf"
steamcmd +login "$STEAM_USERNAME" +run_app_build "$(pwd)/$WORK/app_build.vdf" +quit
