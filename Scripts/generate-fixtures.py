#!/usr/bin/env python3
"""Deterministic fixtures kept out of git. No downloaded or private source files."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parent.parent / "build/fixtures"
root.mkdir(parents=True, exist_ok=True)
line = b'let value = 123 // representative source line\nprint("hello, editor")\n'
fixtures = [
    ("small.swift", 64 * 1024, line, b""),
    ("one-mib.swift", 1024**2, line, b""),
    ("ten-mib.swift", 10 * 1024**2, line, b""),
    ("fifty-mib.swift", 50 * 1024**2, line, b""),
    ("minified.json", 10 * 1024**2, b'{"value":123,"label":"hello"},', b""),
    ("unicode.py", 1024**2, '# café 🐢 日本語\nmessage = "hello 🌍"\n'.encode(), b""),
    ("utf16.swift", 1024**2, 'let message = "héllo 🐢"\r\n'.encode("utf-16-le"), b"\xff\xfe"),
]
manifest = []
for name, target, unit, prefix in fixtures:
    path = root / name
    # Complete records/code points; actual sizes are recorded rather than padded.
    count = max(1, (target - len(prefix)) // len(unit))
    with path.open("wb") as file:
        file.write(prefix)
        if name == "minified.json":
            file.write(b"[")
            file.write(unit * (count - 1))
            file.write(unit[:-1] + b"]")
        else:
            block = unit * 1024
            for _ in range(count // 1024):
                file.write(block)
            file.write(unit * (count % 1024))
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    manifest.append({"name": name, "bytes": path.stat().st_size, "sha256": digest})
(root / "manifest.json").write_text(json.dumps({"version": 1, "fixtures": manifest}, indent=2) + "\n")
print(f"Generated {len(manifest)} fixtures in {root} ({sum(f['bytes'] for f in manifest) / 1024**2:.1f} MiB)")
