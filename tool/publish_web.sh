#!/usr/bin/env bash
#
# Rebuilds the deployable web bundle in web_dist/.
#
#   bash tool/publish_web.sh
#   git add web_dist && git commit -m "Update web preview" && git push
#
# WHY THE OUTPUT IS COMMITTED — Vercel has no Flutter runtime, and building
# Flutter inside its container proved fragile. Committing a prebuilt bundle
# makes the deploy a static file copy with no build step, which cannot fail
# for environment reasons. `build/` stays gitignored (Flutter's default);
# web_dist/ is the explicit, reviewable artefact.
#
# This is a PREVIEW. The product ships on iOS and Android. What does NOT work
# in a browser, and why:
#
#   - Equity quotes and charts (US + India). Yahoo sends no CORS header, so
#     the browser blocks the request and those rows read "unavailable". Crypto
#     works, because Binance sends "Access-Control-Allow-Origin: *". There is
#     no CORS on iOS or Android, where every market resolves.
#   - share_plus file sharing, and local notifications.
#
# Fully functional in a browser: the Simulator (campaign and Endless run on
# bundled data), Time Machine, and the crypto half of Live Markets and the
# Custom Simulation.

set -euo pipefail

FLUTTER="${FLUTTER:-flutter}"

echo "==> Excluding Firebase for the web build"
# firebase_core_web 3.11.0 does not compile against this Dart SDK ("The method
# 'isA' isn't defined for the type 'Object'"), and no newer version resolves.
# Nothing in the app touches Firebase yet — the Daily Pivot is unbuilt — so it
# is excluded here and restored immediately afterwards. Android and iOS keep it.
cp pubspec.yaml pubspec.yaml.orig
trap 'mv -f pubspec.yaml.orig pubspec.yaml 2>/dev/null || true' EXIT

sed -i.tmp \
  -e 's/^  firebase_core:/  #web-build-disabled firebase_core:/' \
  -e 's/^  cloud_firestore:/  #web-build-disabled cloud_firestore:/' \
  -e 's/^  firebase_auth:/  #web-build-disabled firebase_auth:/' \
  pubspec.yaml
rm -f pubspec.yaml.tmp

echo "==> Building"
"$FLUTTER" pub get
"$FLUTTER" build web --release --no-wasm-dry-run

echo "==> Assembling web_dist/"
rm -rf web_dist
cp -r build/web web_dist

# Debug symbol maps: ~7MB, never loaded at runtime.
find web_dist -name '*.symbols' -delete

# The bootstrap is configured with renderer "canvaskit"; the skwasm and wimp
# binaries are only fetched when the renderer is "skwasm", which needs a
# --wasm build. Another ~12MB that would never be requested.
rm -f web_dist/canvaskit/skwasm* web_dist/canvaskit/wimp*

# A stale service worker serves a mismatched bundle after a redeploy, which
# looks exactly like "the app is broken" with no error in the console.
rm -f web_dist/flutter_service_worker.js

echo "==> Done: $(du -sh web_dist | cut -f1)"
echo "    git add web_dist && git commit -m 'Update web preview' && git push"
