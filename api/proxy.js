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
      const chunks = [];
      up.on('data', (c) => chunks.push(c));
      up.on('end', () => {
        const buf = Buffer.concat(chunks);
        const upstreamType = (up.headers['content-type'] || '').toLowerCase();
        const head = buf.slice(0, 64).toString('utf8').trimStart().toLowerCase();
        const isHtml =
          upstreamType.includes('text/html') ||
          head.startsWith('<!doctype') ||
          head.startsWith('<html');
        if (isHtml || (up.statusCode || 500) >= 400) {
          res.statusCode = up.statusCode && up.statusCode >= 400 ? up.statusCode : 404;
          res.setHeader('Content-Type', 'text/plain; charset=utf-8');
          res.setHeader('Access-Control-Allow-Origin', '*');
          res.end('Image not found');
          return;
        }

        let contentType = up.headers['content-type'];
        if (!contentType || contentType.toLowerCase().includes('octet-stream')) {
          if (buf[0] === 0xff && buf[1] === 0xd8) contentType = 'image/jpeg';
          else if (buf[0] === 0x89 && buf[1] === 0x50) contentType = 'image/png';
          else if (buf[0] === 0x42 && buf[1] === 0x4d) contentType = 'image/bmp';
          else if (/\.bmp$/i.test(path)) contentType = 'image/bmp';
          else if (/\.jpe?g$/i.test(path)) contentType = 'image/jpeg';
          else if (/\.png$/i.test(path)) contentType = 'image/png';
          else if (/\.gif$/i.test(path)) contentType = 'image/gif';
          else if (/\.webp$/i.test(path)) contentType = 'image/webp';
        }

        res.statusCode = up.statusCode || 200;
        if (contentType) res.setHeader('Content-Type', contentType);
        res.setHeader('Cache-Control', 'public, max-age=86400');
        res.setHeader('Access-Control-Allow-Origin', '*');
        res.end(buf);
      });
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
