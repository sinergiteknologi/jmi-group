"""Local CORS proxy for Flutter web development.

The legacy ASMX backend sends no Access-Control-Allow-Origin header, so
browsers block SOAP calls from the web build. Run this proxy and build/serve
the web app with:

    python cors_proxy.py
    flutter run -d chrome --dart-define=CORS_PROXY=http://localhost:8898/
    # or: flutter build web --dart-define=CORS_PROXY=http://localhost:8898/

Requests arrive as http://localhost:8898/<full target URL> and are forwarded
verbatim (headers + body); CORS headers are added to every response and
OPTIONS preflight is answered locally. Development only — for production,
enable CORS on IIS or host the web build on the same origin as the service.
"""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.request import Request, urlopen
from urllib.error import HTTPError

PORT = 8898
FORWARD_HEADERS = ("Content-Type", "SOAPAction")


class Handler(BaseHTTPRequestHandler):
    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, SOAPAction")

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_POST(self):
        self._forward()

    def do_GET(self):
        self._forward()

    def _forward(self):
        target = self.path.lstrip("/")
        if not target.startswith(("http://", "https://")):
            self.send_error(400, "Target URL must follow the leading slash")
            return
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else None
        headers = {h: self.headers[h] for h in FORWARD_HEADERS if h in self.headers}
        request = Request(target, data=body, headers=headers, method=self.command)
        try:
            with urlopen(request, timeout=60) as response:
                payload, status, ctype = response.read(), response.status, response.headers.get("Content-Type")
        except HTTPError as e:
            payload, status, ctype = e.read(), e.code, e.headers.get("Content-Type")
        except Exception as e:  # upstream unreachable, DNS, timeout, ...
            self.send_response(502)
            self._cors()
            self.end_headers()
            self.wfile.write(f"Proxy error: {e}".encode())
            return
        self.send_response(status)
        if ctype:
            self.send_header("Content-Type", ctype)
        self._cors()
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
