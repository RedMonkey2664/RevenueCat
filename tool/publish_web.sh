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
# Firebase used to be stripped here before every build because it would not
# compile for web. It is no longer a dependency at all, so the build is now
# just a build.
#
# This is a PREVIEW. The product ships on iOS and Android. What does NOT work
# in a browser, and why:
#
#   - Equity quotes and charts (US + India). Yahoo sends no CORS header, so
#     the browser blocks the request and those rows read "unavailable". Crypto
#     works, because Binance sends "Access-Control-Allow-Origin: *". There is
#     no CORS on iOS or Android, where every market resolves.
#   - share_plus file sharing.
#
# Fully functional in a browser: the Simulator (campaign and Endless run on
# bundled data), Time Machine, and the crypto half of Live Markets and the
# Custom Simulation.

set -euo pipefail

FLUTTER="${FLUTTER:-flutter}"

echo "==> Building"
"$FLUTTER" pub get

# The legal pages the paywall links to are generated from PRIVACY.md and
# TERMS.md, so the app's links and the repo's documents cannot drift.
"${PYTHON:-python}" tool/build_legal_pages.py

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
