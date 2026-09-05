// CORS proxy for Yahoo Finance — used ONLY by the web preview build.
//
// WHY THIS EXISTS
// Yahoo's chart endpoint sends no `Access-Control-Allow-Origin` header, so a
// browser refuses to hand the response to JavaScript and every equity row in
// Live Markets reads "unavailable". Binance does send one, which is why crypto
// works and equity does not. There is no CORS on iOS or Android, so this file
// is dead weight there: `YahooMarketProvider` calls Yahoo directly unless
// `kIsWeb`.
//
// SCOPE NOTE (ARCHITECTURE.md)
// The architecture doc says no backend of ours outside the Daily Pivot. This
// is a deliberate, narrow exception for the browser preview, and it is worth
// being honest about what changes: until now the user's own browser fetched
// Yahoo directly. Now our deployment fetches it and serves it on, which is
// closer to redistribution than a client-side query. That matters because the
// Yahoo licensing question is still open. If it resolves the wrong way, delete
// this file and the web preview loses equity again — nothing else breaks.
//
// NOT AN OPEN PROXY
// The host is hard-coded and the path must match one of two exact patterns.
// Without that this would forward arbitrary requests from anyone who found the
// URL, on Somi's Vercel account.

const UPSTREAM = 'query1.finance.yahoo.com';

// Exactly the two endpoints YahooMarketProvider calls. A symbol may contain
// letters, digits, '^', '.', '-' and '=' (e.g. ^NSEI, RELIANCE.NS, BRK-B).
const ALLOWED_PATHS = [
  /^\/v8\/finance\/chart\/[A-Za-z0-9^.\-=]{1,20}$/,
  /^\/v1\/finance\/search$/,
];

// Yahoo 404s without a browser User-Agent. Same string the Dart client sends.
const USER_AGENT =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/131.0 Safari/537.36';

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }
  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Only GET is supported.' });
    return;
  }

  const { path, ...forwarded } = req.query || {};

  if (typeof path !== 'string' || !ALLOWED_PATHS.some((p) => p.test(path))) {
    res.status(400).json({
      error:
        'Unsupported path. This proxy serves the Yahoo chart and search ' +
        'endpoints only.',
    });
    return;
  }

  const upstream = new URL(`https://${UPSTREAM}${path}`);
  for (const [key, value] of Object.entries(forwarded)) {
    // Vercel gives repeated params as arrays; Yahoo takes none of those, so
    // the first value is the honest reading.
    upstream.searchParams.set(key, Array.isArray(value) ? value[0] : value);
  }

  try {
    const upstreamResponse = await fetch(upstream, {
      headers: { 'User-Agent': USER_AGENT, Accept: 'application/json' },
    });

    const body = await upstreamResponse.text();

    if (!upstreamResponse.ok) {
      // Pass the status through rather than flattening it. The Dart client
      // renders 429 differently from a generic failure, and swallowing that
      // would turn "we are rate-limited, wait" into "something broke".
      res.setHeader('Content-Type', 'application/json; charset=utf-8');
      res.status(upstreamResponse.status).send(
        JSON.stringify({
          error: `Yahoo Finance returned ${upstreamResponse.status}.`,
        }),
      );
      return;
    }

    // Cache at Vercel's edge. Every visitor otherwise costs an upstream call
    // from a single IP, which is how you earn a 429 — one was already seen
    // from this machine during testing. 30s keeps quotes live enough for a
    // 15s poll to feel current while collapsing concurrent viewers into one
    // request.
    res.setHeader('Cache-Control', 's-maxage=30, stale-while-revalidate=120');
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    res.status(200).send(body);
  } catch (error) {
    res.status(502).json({
      error: 'Could not reach Yahoo Finance.',
      detail: String(error),
    });
  }
};
