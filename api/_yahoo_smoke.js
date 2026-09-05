// Local smoke test for api/yahoo.js.
//
//   node api/_yahoo_smoke.js
//
// Vercel adds `status`/`json`/`send` helpers to the response object; this
// stubs the same shape so the handler can be exercised without deploying.
// Not part of the deployed bundle — Vercel only builds files that export a
// handler, and this one runs itself.

const handler = require('./yahoo.js');

function mockRes() {
  const headers = {};
  const out = { code: 0, body: '', headers };
  const res = {
    setHeader: (k, v) => {
      headers[k] = v;
      return res;
    },
    status: (c) => {
      out.code = c;
      return res;
    },
    send: (b) => {
      out.body = typeof b === 'string' ? b : JSON.stringify(b);
      return res;
    },
    json: (b) => {
      out.body = JSON.stringify(b);
      return res;
    },
    end: () => res,
  };
  return { res, out };
}

async function run(name, query, method = 'GET') {
  const { res, out } = mockRes();
  await handler({ method, query }, res);

  const cors = out.headers['Access-Control-Allow-Origin'];
  const preview = out.body.slice(0, 90).replace(/\s+/g, ' ');
  console.log(
    `${name.padEnd(34)} status=${String(out.code).padEnd(4)} ` +
      `cors=${cors ?? 'MISSING'}  ${preview}`,
  );
  return out;
}

(async () => {
  const nifty = await run('chart ^NSEI (the failing case)', {
    path: '/v8/finance/chart/^NSEI',
    interval: '1d',
    range: '5d',
  });

  await run('chart RELIANCE.NS', {
    path: '/v8/finance/chart/RELIANCE.NS',
    interval: '1d',
    range: '5d',
  });

  await run('search', { path: '/v1/finance/search', q: 'tata' });

  // Anything outside the whitelist must be refused, or this becomes an open
  // proxy running on Somi's Vercel account.
  await run('REJECT other yahoo path', { path: '/v7/finance/quote' });
  await run('REJECT absolute url', { path: 'https://example.com/' });
  await run('REJECT traversal', { path: '/v8/finance/chart/../../etc' });
  await run('REJECT missing path', {});
  await run('preflight', { path: '/v1/finance/search' }, 'OPTIONS');

  // The whole point: real quote data must survive the round trip.
  let ok = false;
  try {
    const price =
      JSON.parse(nifty.body).chart.result[0].meta.regularMarketPrice;
    ok = typeof price === 'number' && price > 0;
    console.log(`\nNIFTY regularMarketPrice via proxy: ${price}`);
  } catch (e) {
    console.log(`\nCould not read a price from the proxy response: ${e}`);
  }
  console.log(ok ? 'SMOKE TEST PASSED' : 'SMOKE TEST FAILED');
  process.exit(ok ? 0 : 1);
})();
