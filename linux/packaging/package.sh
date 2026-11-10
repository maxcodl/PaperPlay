#!/usr/bin/env bash
# Packs a finished `flutter build linux --release` into a tar.gz, a .deb and an .rpm.
# Usage: package.sh <version> <x64|arm64> <output dir>
set -euo pipefail

version="$1"
arch="$2"
out="$3"
root="$(cd "$(dirname "$0")/../.." && pwd)"
bundle="$root/build/linux/$arch/release/bundle"
[ -x "$bundle/paperplay" ] || { echo "No release build in $bundle" >&2; exit 1; }
mkdir -p "$out"

# Portable: unpack anywhere and run ./paperplay.
tar -C "$root/build/linux/$arch/release" -czf "$out/PaperPlay-$version-linux-$arch.tar.gz" --transform 's/^bundle/PaperPlay/' bundle

# Installed under /opt with a command, a menu entry and an icon.
stage="$(mktemp -d)"
mkdir -p "$stage/opt/paperplay" "$stage/usr/bin" "$stage/usr/share/applications" "$stage/usr/share/icons/hicolor/512x512/apps"
cp -a "$bundle/." "$stage/opt/paperplay/"
ln -s /opt/paperplay/paperplay "$stage/usr/bin/paperplay"
cp "$root/linux/packaging/paperplay.desktop" "$stage/usr/share/applications/paperplay.desktop"
cp "$root/assets/icon/store_512.png" "$stage/usr/share/icons/hicolor/512x512/apps/paperplay.png"

if [ "$arch" = x64 ]; then deb_arch=amd64; rpm_arch=x86_64; else deb_arch=arm64; rpm_arch=aarch64; fi
common=(-s dir -C "$stage" -n paperplay -v "$version" --license MIT
  --url https://github.com/maxcodl/PaperPlay --maintainer "Paper Play"
  --description "Music player that uses your Telegram channels as storage")

fpm "${common[@]}" -t deb -a "$deb_arch" \
  --depends "libgtk-3-0" --depends "libmpv2 | libmpv1" --depends "libsecret-1-0" \
  --depends "libayatana-appindicator3-1 | libappindicator3-1" \
  -p "$out/PaperPlay-$version-linux-$deb_arch.deb" .

fpm "${common[@]}" -t rpm -a "$rpm_arch" \
  --depends "gtk3" --depends "mpv-libs" --depends "libsecret" \
  -p "$out/PaperPlay-$version-linux-$rpm_arch.rpm" .

rm -rf "$stage"
ls -la "$out"
