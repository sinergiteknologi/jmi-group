const http = require('http');

const ALLOWED_HOST = /(^|\.)sinergiteknologi\.co\.id$/i;
const ALLOWED_PATH = /^\/(VenusERPJMIGroupClientMServices|NewAPIVenusERPJMGroup)\//;
const TIMEOUT_MS = 60000;

module.exports = async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  const host = url.searchParams.get('host') || '';
  const path = url.searchParams.get('path') || '';

  if (!ALLOWED_HOST.test(host) || !ALLOWED_PATH.test(path)) {
    res.statusCode = 400;
    res.end('Bad proxy target');
    return;
  }

  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  const body = Buffer.concat(chunks);

  const headers = {};
  if (req.headers['content-type']) headers['Content-Type'] = req.headers['content-type'];
  if (req.headers['soapaction']) headers['SOAPAction'] = req.headers['soapaction'];
  if (body.length) headers['Content-Length'] = body.length;

  const upstream = http.request(
    { host, port: 80, path, method: req.method, headers, timeout: TIMEOUT_MS },
    (up) => {
      res.statusCode = up.statusCode || 502;
      let contentType = up.headers['content-type'];
      if (!contentType) {
        if (/\.bmp$/i.test(path)) contentType = 'image/bmp';
        else if (/\.jpe?g$/i.test(path)) contentType = 'image/jpeg';
        else if (/\.png$/i.test(path)) contentType = 'image/png';
        else if (/\.gif$/i.test(path)) contentType = 'image/gif';
        else if (/\.webp$/i.test(path)) contentType = 'image/webp';
      }
      if (contentType) res.setHeader('Content-Type', contentType);
      res.setHeader('Cache-Control', 'public, max-age=86400');
      res.setHeader('Access-Control-Allow-Origin', '*');
      up.pipe(res);
    },
  );
  upstream.on('timeout', () => upstream.destroy(new Error('Upstream timeout')));
  upstream.on('error', () => {
    if (!res.headersSent) res.statusCode = 502;
    res.end('Upstream error');
  });
  if (body.length) upstream.write(body);
  upstream.end();
};
