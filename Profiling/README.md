# Performance workflow

```sh
just fixtures
just profile                              # 3 processes per fixture; 30 edits per process
just profile --fixture ten-mib.swift      # Focus on one fixture
just profile --compare Profiling/baseline.json
just profile --runs 1 --timeout 15        # Faster diagnostic pass
just profile-trace ten-mib.swift          # Open the resulting .trace in Instruments
just benchmark                           # Separate Release app startup measurement
```

Fixtures are reproducible synthetic data generated under `build/fixtures`: 64 KiB, 1 MiB, 10 MiB, and 50 MiB Swift; 10 MiB single-line JSON; 1 MiB Unicode Python; and 1 MiB UTF-16/CRLF Swift. Sizes are rounded to complete records/code points. A manifest records exact byte counts and SHA-256 digests. No huge files or downloaded source are stored in git.

`just profile` compiles the same native editor/document sources with `-O`, then uses a new process for each sample. It measures file reading, decoding, creating and displaying the editor, the first highlighting batch, insertion plus display at the start/middle/end, scrolling to those positions, and peak process RSS. Each position gets ten insert/undo cycles. It never saves or changes the fixture files.

The report stores every sample, medians for open/display/highlight/RSS, nearest-rank edit p95, and maximum scroll latency. It also records the source fingerprint, commit and dirty state, fixture hashes, Xcode/macOS/CPU/RAM, font/line height, and viewport dimensions. Timestamped raw samples and `results.json` live under `build/profiles`. Baseline comparisons require matching fixture hashes. Compare on the same hardware, display configuration, and settings with unrelated heavy workloads stopped.

File-open measurements begin **after AppKit initialization**, so use `just benchmark` for process startup. These are repeated runs with warm filesystem caches, not cold-boot or Finder/Gatekeeper timings. Highlighting is progressive: the report measures its first batch, not completion of the entire file. Edits occur while the rest of the file is not yet fully highlighted. RSS includes AppKit and the profiler's file data, not only editor text storage.

Timeouts and crashes are saved as failures and do not discard completed measurements. The runner continues to other fixtures, writes its report, and exits nonzero if any fixture failed. The 10 MiB single-line JSON fixture currently times out in TextKit layout. Keep it as a regression/optimization target; it is not an excluded or passing case.

`Profiling/baseline.json` is the initial measured baseline. It intentionally includes the long-line timeout. Keep later reports under `build/profiles`, or copy a reviewed report into this directory when adopting a new baseline.

## Instruments

`just profile-trace` generates a uniquely named Time Profiler trace and its metrics. The editor emits Points of Interest intervals for line indexing and highlighting batches. The profiler also marks file reading, decoding, first display, scrolling, and edits. Inspect call stacks and add the Points of Interest instrument when needed. The trace includes instrumentation overhead and is for diagnosis; use uninstrumented profile reports for comparisons.

To investigate the real app instead of the harness, build Release and use Instruments' App Launch, Time Profiler, or Allocations templates with `build/dd/Build/Products/Release/Fst.app`. The application performs no profiling file I/O unless the launch benchmark's environment variable is set.
