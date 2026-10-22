#!/usr/bin/env python3
"""Send requests shaped like the public PHP2Shell PoC — same structure,
no exploit payload — and report whether each one reached PHP.

Shape copied from the PoC's request builder: standard
"multipart/form-data; boundary=..." with Content-Length, ~1000 filler
fields of 3000 bytes, then PHP_SESSION_UPLOAD_PROGRESS, then a file
part, then a large field. Values here are harmless filler.

Usage: python3 -I poc_shape.py http://localhost:18102 [more base URLs]
Append "#nobody" to a URL for a layer that can't inspect bodies (e.g.
Apache mod_rewrite): its body-only cases are reported, not enforced.
Exit code 1 if any "must block" case reached PHP.
"""
import http.client
import sys
import urllib.parse

PROGRESS = "PHP_SESSION_UPLOAD_PROGRESS"


def multipart(parts, boundary=b"S" * 17):
    out = b""
    for p in parts:
        out += b"--" + boundary + b"\r\n"
        out += b'Content-Disposition: form-data; name=' + p.get("rawname", b'"' + p["name"].encode() + b'"')
        if "filename" in p:
            out += b'; filename="' + p["filename"].encode() + b'"'
            out += b"\r\nContent-Type: application/octet-stream"
        out += b"\r\n\r\n" + p["data"] + b"\r\n"
    out += b"--" + boundary + b"--\r\n"
    return out, boundary


def filler(n, size=3000):
    return [{"name": f"f{i:04d}"[:5], "data": b"V" * size} for i in range(n)]


FILE = {"name": "file", "filename": "a.txt", "data": b"hello"}
PROG = {"name": PROGRESS, "data": b"abc"}

# (label, path, parts, extra headers, expectation)
#   expectation: "block" = must not reach PHP, "pass" = must reach PHP
CASES = [
    ("legit upload (2 fields + file)", "/upload/test.php",
     [{"name": "note", "data": b"hi"}, {"name": "x", "data": b"y"}, FILE], {}, "pass"),
    ("PoC shape -> non-upload path", "/index.php",
     filler(1001) + [PROG, FILE, {"name": "big", "data": b"Z" * 200_000}],
     {"Cookie": "PHPSESSID=" + "a" * 32}, "block"),
    ("PoC shape -> upload path", "/upload/test.php",
     filler(1001) + [PROG, FILE, {"name": "big", "data": b"Z" * 200_000}],
     {"Cookie": "PHPSESSID=" + "a" * 32}, "block"),
    ("progress field first (small body)", "/upload/test.php",
     [PROG, FILE], {}, "block"),
    ("progress after 40 KB filler (< NoFilesLimit)", "/upload/test.php",
     filler(13) + [PROG, FILE], {}, "block"),
    ("progress after 150 KB filler (> NoFilesLimit)", "/upload/test.php",
     filler(50) + [PROG, FILE], {}, "block"),
    ("progress name unquoted", "/upload/test.php",
     [{"name": PROGRESS, "rawname": PROGRESS.encode(), "data": b"abc"}, FILE], {}, "block"),
    ("1001 fields, no progress field", "/upload/test.php",
     filler(1001) + [FILE], {}, "info"),
]


def send(base, path, body, boundary, headers):
    u = urllib.parse.urlsplit(base)
    conn = http.client.HTTPConnection(u.hostname, u.port, timeout=30)
    h = {"Content-Type": "multipart/form-data; boundary=" + boundary.decode(),
         "Content-Length": str(len(body)), **headers}
    try:
        conn.request("POST", path, body=body, headers=h)
        r = conn.getresponse()
        data = r.read(1 << 16)
        # PHP may print startup warnings (e.g. max_input_vars) before the JSON.
        reached = r.status == 200 and b'{"post"' in data
        return r.status, reached
    except (ConnectionError, http.client.HTTPException, OSError) as e:
        return f"conn:{type(e).__name__}", False
    finally:
        conn.close()


def main():
    bases = sys.argv[1:] or ["http://localhost:18102"]
    bad = False
    for base in bases:
        base, _, flag = base.partition("#")
        print(f"\n=== {base}" + ("  (body-blind layer)" if flag == "nobody" else ""))
        for label, path, parts, headers, want in CASES:
            if flag == "nobody" and want == "block" and path.startswith("/upload"):
                want = "info"
            body, boundary = multipart(parts)
            status, reached = send(base, path, body, boundary, headers)
            if want == "block":
                ok = not reached
            elif want == "pass":
                ok = reached
            else:
                ok = True
            bad |= not ok
            verdict = "ok  " if ok else "FAIL"
            where = "reached PHP" if reached else "blocked"
            print(f"  {verdict} want {want:5} {label:46} {len(body)/1024:8.0f} KB -> {status} ({where})")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
