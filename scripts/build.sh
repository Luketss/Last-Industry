#!/usr/bin/env bash
# Exports release builds for Windows and Linux and packages them into build/release.
#   GODOT=/path/to/godot scripts/build.sh [version]
# Requires the Godot 4.3 export templates (Editor > Manage Export Templates).
set -euo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
VERSION="${1:-$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)}"
OUT=build/release
rm -rf build/windows build/linux "$OUT"
mkdir -p build/windows build/linux "$OUT"

"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Linux" build/linux/LastIndustry.x86_64
"$GODOT" --headless --path . --export-release "Windows Desktop" build/windows/LastIndustry.exe
test -s build/linux/LastIndustry.x86_64
test -s build/windows/LastIndustry.exe

# Exported build must run the whole game loop.
timeout 300 ./build/linux/LastIndustry.x86_64 --headless -- --smoke | tee /tmp/li_smoke.txt
grep -q "SMOKE OK" /tmp/li_smoke.txt

(cd build/windows && zip -q -r "../../$OUT/LastIndustry-$VERSION-windows-x86_64.zip" .)
tar -C build/linux -czf "$OUT/LastIndustry-$VERSION-linux-x86_64.tar.gz" .
(cd "$OUT" && sha256sum * > SHA256SUMS.txt)
echo "Pacotes em $OUT:"
ls -la "$OUT"
