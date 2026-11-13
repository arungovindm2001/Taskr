# TaskrCore

The sampling library behind Taskr. It reads every running process through libproc and returns plain value types, with no UI and no dependencies beyond the system.

## Contents

| File | Purpose |
|---|---|
| `Sources/TaskrCore/ProcessSampler.swift` | `ProcessSampler` actor: lists pids and reads each one with `proc_pid_rusage` (`RUSAGE_INFO_V4`) |
| `Sources/TaskrCore/ProcessSnapshot.swift` | `ProcessSnapshot`: pid, name, CPU %, memory footprint, disk read/write rates |
| `Sources/TaskrCore/Format.swift` | `Format.bytes` and `Format.rate` for display |
| `Sources/taskr-sample/main.swift` | `taskr-sample`, a terminal harness that prints the top 15 processes once a second |

## Usage

```swift
import TaskrCore

let sampler = ProcessSampler()
_ = await sampler.sample()                 // first call primes the deltas; rates are zero
try? await Task.sleep(for: .seconds(1))
let processes = await sampler.sample()     // CPU and disk rates are now meaningful
```

- **CPU** is a share of the whole machine (100% means every core is busy), like Windows Task Manager.
- **Memory** is the physical footprint, which is what Activity Monitor calls "Memory".
- **Disk** rates are bytes per second of reads and writes since the previous sample.
- Processes that exit mid-sample, or that macOS doesn't let you inspect, are skipped.

## Try it

```
cd Packages/TaskrCore
swift run taskr-sample
```

Requires macOS 14 or later.
