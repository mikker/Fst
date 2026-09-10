#!/usr/bin/env python3
"""Measure process spawn to first editor view display (warm filesystem cache)."""
import os
import pathlib
import statistics
import subprocess
import sys
import tempfile
import time

repo_root = pathlib.Path(__file__).resolve().parent.parent
binary = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else repo_root / "build/dd/Build/Products/Release/Fst.app/Contents/MacOS/Fst"
if not binary.is_file():
    sys.exit(f"App binary not found: {binary}. Run `just build-release` first.")
samples = []
with tempfile.TemporaryDirectory(prefix="Fst-launch-") as directory:
    for index in range(5):
        report = pathlib.Path(directory) / str(index)
        start = time.monotonic()
        process = subprocess.Popen([str(binary), "-ApplePersistenceIgnoreState", "YES"], env={**os.environ, "FST_LAUNCH_REPORT": str(report)}, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            while not report.exists():
                if process.poll() is not None:
                    raise RuntimeError("Fst exited before displaying an editor")
                if time.monotonic() - start > 10:
                    raise RuntimeError("No editor displayed within 10 seconds")
                time.sleep(0.002)
            elapsed = time.monotonic() - start
            samples.append(elapsed)
            print(f"Launch {index + 1}: {elapsed * 1000:.0f} ms (main → display: {float(report.read_text()) * 1000:.0f} ms)")
        finally:
            process.terminate()
            process.wait(timeout=5)
print(f"Median: {statistics.median(samples) * 1000:.0f} ms; max: {max(samples) * 1000:.0f} ms")
sys.exit(0 if max(samples) < 1 else 1)
