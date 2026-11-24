#!/bin/sh
# Repack the microsoft-edge-stable RPM as an AppImage in ./dist. Runs as root in a Fedora container.
# Usage: build-appimage.sh <version>     (for example 142.0.3595.80; see latest-version.sh)
#
# The AppImage is "thin": it holds /opt/microsoft/msedge from the RPM and uses the host's system
# libraries (nss, gtk3, alsa-lib, mesa, ...), which every desktop distribution has.
set -eu

VERSION=${1:?usage: build-appimage.sh <version>}
ARCH=x86_64
REPO=${GITHUB_REPOSITORY:-projectlarch/microsoft-edge-stable}
NAME=Microsoft-Edge-Stable
OUTNAME="$NAME-$VERSION-$ARCH.AppImage"
APPIMAGETOOL_URL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-$ARCH.AppImage"

SCRIPTS=$(cd "$(dirname "$0")" && pwd)
OUT=$(pwd)/dist
WORK=${WORK:-/tmp/edge-build}

sh "$SCRIPTS/add-edge-repo.sh"
dnf install -y cpio file wget desktop-file-utils >&2

rm -rf "$WORK" "$OUT"
mkdir -p "$WORK/rpm" "$WORK/AppDir" "$OUT"

# 1. Download the RPM and check Microsoft's signature on it.
dnf download --refresh --arch "$ARCH" --destdir "$WORK/rpm" "microsoft-edge-stable-$VERSION"
RPM=$(ls "$WORK"/rpm/microsoft-edge-stable-"$VERSION"-*."$ARCH".rpm)
rpm -K "$RPM" | tee /dev/stderr | grep -q 'signatures OK' || { echo "bad RPM signature: $RPM" >&2; exit 1; }

# 2. Unpack it.
APPDIR="$WORK/AppDir"
(cd "$APPDIR" && rpm2cpio "$RPM" | cpio -idm --quiet)
EDGE=opt/microsoft/msedge
test -x "$APPDIR/$EDGE/microsoft-edge"

# The cron script adds Microsoft's repository to the system; it has no place in an AppImage.
rm -rf "$APPDIR/$EDGE/cron" "$APPDIR/etc"
# The setuid sandbox helper cannot work from an AppImage (mounted nosuid); without it Edge uses its
# user-namespace sandbox, as Chromium does when no helper is installed.
rm -f "$APPDIR/$EDGE/msedge-sandbox" "$APPDIR/$EDGE/chrome-sandbox"

# 3. Entry point: Microsoft's own wrapper script, which finds msedge next to itself.
cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/sh
HERE=$(dirname "$(readlink -f "$0")")
exec "$HERE/opt/microsoft/msedge/microsoft-edge" "$@"
EOF
chmod +x "$APPDIR/AppRun"

# 4. Desktop file and icon at the AppDir root.
sed -E \
  -e 's#^Exec=[^ ]*microsoft-edge[^ ]*#Exec=microsoft-edge#' \
  -e 's#^Icon=.*#Icon=microsoft-edge#' \
  "$APPDIR/usr/share/applications/microsoft-edge.desktop" > "$APPDIR/microsoft-edge.desktop"
grep -n '^Exec=\|^Icon=' "$APPDIR/microsoft-edge.desktop" >&2
desktop-file-validate "$APPDIR/microsoft-edge.desktop" >&2 || true
cp "$APPDIR/$EDGE/product_logo_256.png" "$APPDIR/microsoft-edge.png"
cp "$APPDIR/$EDGE/product_logo_256.png" "$APPDIR/.DirIcon"

# 5. Pack. appimagetool only publishes a "continuous" build, so log its checksum.
wget -q "$APPIMAGETOOL_URL" -O "$WORK/appimagetool.AppImage"
sha256sum "$WORK/appimagetool.AppImage" >&2
chmod +x "$WORK/appimagetool.AppImage"
(cd "$WORK" && ./appimagetool.AppImage --appimage-extract >/dev/null)   # no FUSE in containers

(cd "$OUT" && ARCH=$ARCH "$WORK/squashfs-root/AppRun" --no-appstream \
  -u "gh-releases-zsync|${REPO%/*}|${REPO#*/}|latest|$NAME-*-$ARCH.AppImage.zsync" \
  "$APPDIR" "$OUTNAME")

test -f "$OUT/$OUTNAME"
(cd "$OUT" && sha256sum ./*.AppImage ./*.zsync 2>/dev/null | sed 's# \./# #' > SHA256SUMS)
ls -la "$OUT"
