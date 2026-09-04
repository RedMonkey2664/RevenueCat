#!/usr/bin/env bash
#
# Builds the Flutter web bundle on Vercel.
#
# Vercel has no Flutter runtime, and `build/` is gitignored (Flutter's default),
# so without this there is nothing in the repo for Vercel to serve — which is
# exactly the 404: NOT_FOUND you get from a default deploy.
#
# This is a PREVIEW build. The product ships on iOS and Android; the web bundle
# exists so the app can be demoed from a link.

set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-stable}"
FLUTTER_DIR="$PWD/.flutter-sdk"

echo "==> Fetching Flutter ($FLUTTER_VERSION)"
if [ ! -d "$FLUTTER_DIR" ]; then
  git clone --depth 1 -b "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"

# Vercel's build container runs as a non-root user in a fresh checkout; Flutter
# refuses to run from a directory it considers unsafe without this.
git config --global --add safe.directory "$FLUTTER_DIR" || true

flutter --version

# firebase_core_web 3.11.0 does not compile against this Dart SDK ("The method
# 'isA' isn't defined for the type 'Object'"), and no newer version resolves.
# Nothing in the app touches Firebase yet — the Daily Pivot is unbuilt — so the
# three Firebase packages are excluded from THIS BUILD ONLY. The committed
# pubspec is untouched; Android and iOS builds keep them.
#
# Remove this block once Daily Pivot lands and Firebase actually compiles for
# web, or the Pivot tab will silently lack its backend in the web preview.
echo "==> Excluding Firebase (web-incompatible on this SDK)"
sed -i.bak \
  -e 's/^  firebase_core:/  #vercel-disabled firebase_core:/' \
  -e 's/^  cloud_firestore:/  #vercel-disabled cloud_firestore:/' \
  -e 's/^  firebase_auth:/  #vercel-disabled firebase_auth:/' \
  pubspec.yaml

echo "==> flutter pub get"
flutter pub get

echo "==> flutter build web"
flutter build web --release --no-wasm-dry-run

# Restore so the working tree matches the repo, in case anything inspects it.
mv pubspec.yaml.bak pubspec.yaml

echo "==> Built build/web"
ls -la build/web/index.html
