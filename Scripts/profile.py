#!/usr/bin/env python3
"""Record repeatable, separate-process measurements and compare previous runs."""
import argparse
import datetime
import json
import math
import hashlib
import platform
import statistics
import sys
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument("--runs", type=int, default=3)
parser.add_argument("--timeout", type=float, default=30, help="Per-process timeout in seconds")
parser.add_argument("--compare", type=Path, help="Earlier results.json")
parser.add_argument("--fixture", action="append", help="Fixture name (repeatable); default: all")
args = parser.parse_args()
if args.runs < 1 or args.timeout <= 0:
    parser.error("--runs and --timeout must be positive")
manifest = json.loads((root / "build/fixtures/manifest.json").read_text())
fixtures = [f for f in manifest["fixtures"] if not args.fixture or f["name"] in args.fixture]
if args.fixture and len(fixtures) != len(set(args.fixture)):
    parser.error("Unknown fixture name")
folder = root / "build/profiles" / datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
folder.mkdir(parents=True)
old = json.loads(args.compare.read_text()) if args.compare else None
source_digest = hashlib.sha256((root / "build/tools/profile-source.sha256").read_bytes())
results = []
for fixture in fixtures:
    samples = []
    failure = None
    for index in range(args.runs):
        output = folder / f"{fixture['name']}.{index}.json"
        try:
            subprocess.run([str(root / "build/tools/fst-profile"), str(root / "build/fixtures" / fixture["name"]), str(output)], check=True, timeout=args.timeout, stdout=subprocess.DEVNULL)
            samples.append(json.loads(output.read_text()))
        except (subprocess.TimeoutExpired, subprocess.CalledProcessError) as error:
            failure = f"Timed out after {args.timeout:g}s" if isinstance(error, subprocess.TimeoutExpired) else f"Exited with status {error.returncode}"
            break
    row = {**fixture, "samples": samples}
    if failure:
        row["error"] = failure
        results.append(row)
        print(f"{fixture['name']}: {failure}", flush=True)
        continue
    for key in ["open_ms", "first_display_ms", "first_highlight_ms", "peak_rss_bytes"]:
        row[key] = statistics.median(s[key] for s in samples)
    row["edit_p95_ms"] = sorted(t for s in samples for t in s["edit_ms"])[math.ceil(sum(len(s["edit_ms"]) for s in samples) * .95) - 1]
    row["scroll_max_ms"] = max(t for s in samples for t in s["scroll_ms"])
    results.append(row)
    comparison = ""
    if old:
        before = next((f for f in old["fixtures"] if f["name"] == row["name"] and f["sha256"] == row["sha256"]), None)
        if before and "open_ms" in before:
            comparison = f"; open {((row['open_ms'] / before['open_ms']) - 1) * 100:+.1f}% vs baseline"
    print(f"{row['name']}: open {row['open_ms']:.1f} ms; edit p95 {row['edit_p95_ms']:.1f} ms; scroll max {row['scroll_max_ms']:.1f} ms; peak RSS {row['peak_rss_bytes'] / 1024**2:.1f} MiB{comparison}", flush=True)
report = {"schema": 1, "source_sha256": source_digest.hexdigest(), "date": folder.name, "os": platform.platform(), "machine": platform.machine(),
          "cpu": subprocess.check_output(["sysctl", "-n", "machdep.cpu.brand_string"], text=True).strip(),
          "memory_bytes": int(subprocess.check_output(["sysctl", "-n", "hw.memsize"], text=True)), "optimization": "-O",
          "commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
          "dirty": bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=root, text=True)),
          "xcode": subprocess.check_output(["xcodebuild", "-version"], text=True).strip(),
          "runs": args.runs, "timeout_seconds": args.timeout, "fixtures": results}
(folder / "results.json").write_text(json.dumps(report, indent=2) + "\n")
print(f"Results: {folder / 'results.json'}")

if any("error" in fixture for fixture in results):
    sys.exit(1)
