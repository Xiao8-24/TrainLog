"""Loopback-only development server. The shipped preview also opens offline."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

root = Path(__file__).resolve().parents[1]
server = ThreadingHTTPServer(("127.0.0.1", 0), partial(SimpleHTTPRequestHandler, directory=str(root / "WindowsPreview")))
out = root / "artifacts/windows-preview"
out.mkdir(parents=True, exist_ok=True)
(out / "preview-url.txt").write_text(f"http://127.0.0.1:{server.server_port}/", encoding="utf-8")
print(f"TrainLog Windows preview: http://127.0.0.1:{server.server_port}/", flush=True)
server.serve_forever()
