#!/usr/bin/env python3
"""Hotline Village local server.

Serves the repo root on http://localhost:8060 (mic needs localhost or https) and proxies
POST /api/exa {query} -> Exa /answer with EXA_API_KEY from .env. The Exa key never reaches
the browser. Also writes the Vapi PUBLIC key (VAPI_API_KEY) into gitignored local-config.js
files next to hotline.js so pages pick it up without a URL param.
"""
import http.server
import json
import os
import re
import shutil
import socketserver
import sys
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PORT = int(os.environ.get("PORT", "8060"))


def load_env():
    env = {}
    path = os.path.join(ROOT, ".env")
    if os.path.exists(path):
        for line in open(path, encoding="utf-8"):
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            env[k.strip()] = v.strip().strip('"').strip("'")
    for k in ("VAPI_API_KEY", "EXA_API_KEY"):
        if os.environ.get(k):
            env[k] = os.environ[k]
    return env


ENV = load_env()


def write_local_config():
    key = ENV.get("VAPI_API_KEY", "")
    if not key:
        print("No VAPI_API_KEY in .env: pages will ask for the key.")
        return
    body = "window.HOTLINE_LOCAL = { vapiKey: %s };\n" % json.dumps(key)
    for d in ("web", os.path.join("build", "web")):
        full = os.path.join(ROOT, d)
        if os.path.isdir(full):
            p = os.path.join(full, "local-config.js")
            fd = os.open(p, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            with os.fdopen(fd, "w") as f:
                f.write(body)
    # Keep the exported game's copy of the bridge current.
    if os.path.isdir(os.path.join(ROOT, "build", "web")):
        shutil.copy(os.path.join(ROOT, "web", "hotline.js"), os.path.join(ROOT, "build", "web", "hotline.js"))
    print("Vapi key from .env -> local-config.js (gitignored)")


def short(text, sentences=2, limit=320):
    text = re.sub(r"\s+", " ", re.sub(r"\[\d+\]|\*\*|__|#+ ", "", text or "")).strip()
    text = re.sub(r"\s+([.,!?;:])", r"\1", text)
    parts = re.split(r"(?<=[.!?])\s+", text)
    out = " ".join(parts[:sentences]).strip()
    if len(out) > limit:
        out = out[: limit - 1].rsplit(" ", 1)[0] + "…"
    return out


def exa_answer(query):
    key = ENV.get("EXA_API_KEY", "")
    if not key:
        return 500, {"error": "EXA_API_KEY missing in .env"}
    req = urllib.request.Request(
        "https://api.exa.ai/answer",
        data=json.dumps({"query": query, "text": False}).encode(),
        headers={"x-api-key": key, "Content-Type": "application/json", "User-Agent": "hotline-village/1"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            data = json.loads(r.read())
    except urllib.error.HTTPError as e:
        return 502, {"error": "exa %d: %s" % (e.code, e.read().decode("utf-8", "replace")[:300])}
    except Exception as e:  # noqa: BLE001
        return 502, {"error": "exa: %s" % e}
    answer = data.get("answer")
    if not isinstance(answer, str):
        answer = json.dumps(answer) if answer is not None else ""
    sources = [{"title": c.get("title") or c.get("url", ""), "url": c.get("url", "")} for c in (data.get("citations") or [])[:3]]
    return 200, {"answer": short(answer), "sources": sources}


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=ROOT, **kw)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def _json(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        if self.path.split("?")[0] != "/api/exa":
            return self._json(404, {"error": "not found"})
        try:
            n = int(self.headers.get("Content-Length") or 0)
            query = str(json.loads(self.rfile.read(n) or b"{}").get("query", "")).strip()[:300]
        except Exception:  # noqa: BLE001
            return self._json(400, {"error": "bad json"})
        if not query:
            return self._json(400, {"error": "query required"})
        code, obj = exa_answer(query)
        self._json(code, obj)

    def log_message(self, fmt, *args):
        if "/api/" in (args[0] if args else ""):
            sys.stderr.write("[serve] " + (fmt % args) + "\n")


class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


if __name__ == "__main__":
    write_local_config()
    print("Serving %s" % ROOT)
    print("  http://localhost:%d/web/test.html" % PORT)
    print("  http://localhost:%d/build/web/index.html" % PORT)
    print("  POST /api/exa {query}  (Exa key: %s)" % ("set" if ENV.get("EXA_API_KEY") else "MISSING"))
    Server(("127.0.0.1", PORT), Handler).serve_forever()
