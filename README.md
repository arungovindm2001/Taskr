# Taskr

A native macOS task manager that copies the structure of the Windows Task Manager (Processes, Performance, App history, Startup apps, Users, Details, Services, Settings) and looks like it belongs on a Mac. It is written in pure Swift and SwiftUI, with no web view, no Rust core and no third-party dependencies.

The Processes and Performance pages are complete. The other pages are placeholders. See [Status](#status).

## Contents

- [Features](#features)
- [Requirements](#requirements)
- [Build and run](#build-and-run)
- [Project layout](#project-layout)
- [Architecture](#architecture)
- [Data sources](#data-sources)
- [How the Processes page works](#how-the-processes-page-works)
- [Permissions and limitations](#permissions-and-limitations)
- [Conventions](#conventions)
- [Status](#status)

## Features

**Processes page**

- Live list refreshed every second, with processes grouped into **Apps**, **Background processes** and **macOS processes**. Helper processes roll up under their parent app (for example every Chrome helper appears under "Google Chrome").
- CPU, Memory, Disk, Network, GPU and Energy impact columns per app and per process.
- Heat-tinted cells in four steps, in light and dark appearance, like Windows Task Manager.
- Column headers show **machine-wide** totals (not sums of the rows) and are tinted by load. Clicking a header sorts by that column.
- Status column: **Efficiency** (the process is throttled) and **Not responding** (the app is hung).
- Toolbar and context-menu actions: Run new task, End task, Force Quit, Efficiency mode, Resource Values (memory as size or percent), Sample Process, Reveal in Finder, Search Online, Go to Details, Get Info.
- Search, Expand All and Collapse All.

**Look and feel**

- System Settings-style sidebar and surfaces, SF Symbols, native toolbar and sheets, automatic light and dark mode.

## Requirements

| | |
|---|---|
| macOS | 14 (Sonoma) or later |
| Xcode | 26 or later (the project uses default main-actor isolation) |
| Swift | Swift 5 language mode |
| Hardware | Apple silicon or Intel. GPU and Energy columns depend on what the GPU driver and kernel report. |

## Build and run

1. Open `Taskr.xcodeproj` in Xcode.
2. Select the **Taskr** scheme and **My Mac**.
3. Under **Signing & Capabilities** pick your own Team (a Personal Team is fine).
4. Press **Run** (⌘R).

The sampler lives in the local Swift package `Packages/TaskrCore`, which is part of this repository, so a fresh clone builds with no extra setup. You can also run it on its own: `cd Packages/TaskrCore && swift run taskr-sample`.

The app must run **without** the App Sandbox. `Taskr/Taskr.entitlements` already turns it off; a sandboxed process cannot read other processes' statistics.

## Project layout

```
Taskr/                       Repository root (Xcode project lives here)
├── Taskr.xcodeproj
├── Packages/
│   └── TaskrCore/               Swift package: libproc process sampler (see its README)
│       ├── Package.swift
│       └── Sources/
│           ├── TaskrCore/       ProcessSampler, ProcessSnapshot, Format
│           └── taskr-sample/    Terminal harness (swift run taskr-sample)
└── Taskr/                   App target (folder-based: new files are picked up automatically)
    ├── App/
    │   ├── TaskrApp.swift           @main entry point; one window
    │   ├── RootView.swift           Sidebar + detail navigation
    │   ├── Page.swift               The pages (title, SF Symbol)
    │   └── ShellPage.swift          Placeholder for pages not built yet
    ├── Model/
    │   ├── ProcessCategory.swift    Apps / Background / macOS sections
    │   ├── ProcessGroup.swift       A group of related processes (one row)
    │   ├── ProcessGrouping.swift    Snapshots -> groups (bundle detection, classification)
    │   └── ProcessPaths.swift       Cached executable path per pid (proc_pidpath)
    ├── Processes/
    │   ├── ProcessesPage.swift          Page shell: header, list, toolbar, sheets
    │   ├── ProcessTableHeader.swift     Column header with machine-wide totals and sorting
    │   ├── ProcessRowView.swift         One list row (name, status, metric cells)
    │   ├── ProcessRowView+ContextMenu.swift  Right-click menu
    │   ├── ProcessStore.swift           Observable state and the 1 Hz sampling loop
    │   ├── ProcessStore+Rows.swift      Groups -> sorted, filtered display rows; header totals
    │   ├── ProcessRow.swift             Display row model and header totals
    │   ├── ProcessColumn.swift          Shared column widths
    │   ├── ProcessFormat.swift          Number formatting, energy levels
    │   ├── ProcessTarget.swift          What an action operates on (a process or a group)
    │   ├── ProcessActions.swift         End task, Efficiency mode, Sample, Reveal, Run task
    │   ├── RunTaskSheet.swift           "Create new task" dialog
    │   └── ProcessInfoSheet.swift       "Get Info" dialog
    ├── Performance/
    │   ├── PerformancePage.swift        Device list (left) and selected detail (right)
    │   ├── DeviceCard.swift             One device card with a mini graph
    │   ├── PerformanceDetail.swift      Shared detail layout: title, graphs, stats, facts
    │   ├── CPUDetail.swift / MemoryDetail.swift / DiskDetail.swift / NetworkDetail.swift / GPUDetail.swift
    │   ├── LiveGraph.swift              Canvas area graph (60 s window)
    │   ├── GraphSection.swift           Titled graph with legend and maximum label
    │   ├── PerformanceStore.swift       Observable histories and the 1 Hz sampling loop
    │   ├── PerformanceStore+Summary.swift  Device card summaries and titles
    │   ├── MetricHistory.swift          Fixed-length ring of readings
    │   ├── PerformanceDevice.swift      Device list and graph palette
    │   └── PerformanceFormat.swift      Rates, sizes, uptime, thermal state
    ├── Sampling/
    │   ├── SystemStats.swift        Whole-machine CPU, memory breakdown, disk, network
    │   ├── Sysctl.swift             Typed sysctl reads
    │   ├── HardwareInfo.swift       Chip name, core layout, RAM, page size
    │   ├── StorageInfo.swift        Startup volume capacity, format, FileVault
    │   ├── NetworkInfo.swift        Primary adapter, addresses, Wi-Fi details
    │   ├── GPUDevice.swift          Whole-GPU utilization, memory, Metal info
    │   ├── ProcessCounts.swift      Process and thread totals
    │   ├── NetworkSampler.swift     Per-process network via nettop
    │   ├── GPUSampler.swift         Per-process GPU via IORegistry
    │   ├── EnergySampler.swift      Per-process power via rusage
    │   └── Responsiveness.swift     Hung-app ("Not responding") detection
    ├── Support/
    │   ├── Heat.swift               Heat tiers and thresholds
    │   ├── Color+Hex.swift          Color(hex:)
    │   └── IconCache.swift          Cached 16 pt Finder icons
    ├── Assets.xcassets              App icon (all macOS sizes) and accent color
    └── Taskr.entitlements           App Sandbox off
```

## Architecture

```
                 every 1 second
   ┌───────────────────────────────────────────────────────────┐
   │                      ProcessStore.run()                    │
   │                                                            │
   │  TaskrCore.ProcessSampler ─► [ProcessSnapshot]  (CPU, memory, disk per pid)
   │  NetworkSampler           ─► bytes/s per pid                │
   │  GPUSampler               ─► GPU % per pid, device GPU %    │
   │  EnergySampler            ─► watts per pid                  │
   │  Responsiveness           ─► set of hung pids               │
   │  SystemStats              ─► machine-wide totals            │
   │                                                            │
   │  ProcessGrouping.build ─► [ProcessGroup]  (published)       │
   └──────────────────────────────┬────────────────────────────┘
                                  │ @Observable
                                  ▼
   ProcessesPage ── store.rows(matching:) ─► [ProcessRow] ─► ProcessRowView × N
                 └─ store.headerTotals    ─► HeaderTotals ─► ProcessTableHeader
```

Key decisions:

- **`ProcessStore` is the single source of truth.** It owns every sampler and all published state. Views never sample anything themselves.
- **Views are thin.** `ProcessesPage` wires things together; the header, rows and menu are separate views that take the store and a row.
- **Row building is not in the view.** `ProcessStore+Rows` turns groups into a flat `[ProcessRow]` (filtering, sorting, expansion), so the logic can be tested without SwiftUI.
- **Custom grid, not `Table`.** The list is a `ScrollView` with a `LazyVStack` because the design needs full-cell heat fills, section header rows and per-group disclosure, which `Table` does not support.
- **One sampling task.** `.task { await store.run() }` on the page starts the loop and SwiftUI cancels it when the page goes away; `NetworkSampler`'s `nettop` child is stopped at the same time.
- **First sample is a baseline.** Rates (CPU, GPU, energy, disk, network) are differences between two readings, so those columns show "–" for the first second.

## Data sources

| Column / value | Source | Notes |
|---|---|---|
| Per-process CPU, memory, disk | `TaskrCore.ProcessSampler` using `proc_pid_rusage` (`RUSAGE_INFO_V4`) | CPU is a share of the whole machine. Memory is the physical footprint. Disk is the read + write rate. |
| Per-process network | `nettop -P -d -L 0 -s 1 -n -x -J bytes_in,bytes_out`, one long-lived child process | The first two blocks are discarded (empty block and cumulative baseline). |
| Per-process GPU | IORegistry: `IOAccelerator` children. `IOUserClientCreator` names the pid, `AppUsage.accumulatedGPUTime` is the counter | Percent of one GPU's time between two samples. |
| Whole-GPU total | `PerformanceStatistics["Device Utilization %"]` | Falls back to the per-process sum (capped at 100%) if the driver doesn't report it. |
| Per-process energy | `proc_pid_rusage` (`RUSAGE_INFO_V6`) `ri_energy_nj` | Converted to watts, then mapped to Very low / Low / Moderate / High / Very high (see `ProcessFormat.energyLevel`). |
| Header CPU | `host_statistics(HOST_CPU_LOAD_INFO)` tick deltas | Fraction of ticks that were not idle. |
| Header Memory | `host_statistics64(HOST_VM_INFO64)` | Same as Activity Monitor's "Memory Used": app memory + wired + compressed, over installed RAM. |
| Header Disk | IOKit `IOBlockStorageDriver` `Statistics` | Bytes read + written across all physical storage. |
| Header Network | `sysctl(NET_RT_IFLIST2)` | Bytes in + out on `en*` interfaces (Wi-Fi and Ethernet). |
| Not responding | WindowServer `CGSEventIsAppUnresponsive` (private) | See [limitations](#permissions-and-limitations). |
| Row icons | `NSWorkspace.icon(forFile:)`, cached | Taskr's own row uses the running app's icon. |

Why the header totals don't sum the rows: per-process memory footprints overlap (shared and compressed pages), so their sum can exceed 100% of RAM. The machine-wide counters above match Activity Monitor.

### Performance page sources

| Value | Source |
|---|---|
| CPU user / system / total | `host_statistics` tick deltas |
| Memory in use, wired, compressed, cached | `host_statistics64`; swap from `vm.swapusage`; pressure from `kern.memorystatus_vm_pressure_level` |
| Disk active time, throughput, response time | IOKit `IOBlockStorageDriver` statistics (bytes, operations, total time) |
| Capacity, available, format | `URLResourceValues` on `/`; FileVault from `fdesetup status` |
| Network throughput | `sysctl(NET_RT_IFLIST2)` on `en*` |
| Adapter, IP addresses, Wi-Fi standard and signal | `getifaddrs`, CoreWLAN |
| GPU utilization, renderer, tiler, memory | IORegistry `IOAccelerator` `PerformanceStatistics`; core count and name via Metal |
| Chip, cores, architecture | `machdep.cpu.brand_string`, `hw.perflevel*`, `hw.optional.arm64` |

`PerformanceStore` lives in `RootView` so graph history keeps accumulating while another page is open.

## How the Processes page works

**Grouping** (`ProcessGrouping`). Each process's executable path is read with `proc_pidpath`. The outermost `.app` bundle in the path becomes the group, so helpers fold into their parent app.

- A group whose bundle belongs to a running Dock app (`NSWorkspace` activation policy `.regular`) goes under **Apps**.
- Otherwise, executables under `/System`, `/usr`, `/sbin`, `/bin`, `/Library/Apple` or `/private/var` go under **macOS processes**.
- Everything else goes under **Background processes**.
- Processes whose path can't be read (protected ones such as `kernel_task`) are grouped by name under **macOS processes**.

**Heat tiers** (`Heat`). Each cell has a tier 0–4 based on four ascending thresholds per metric (for example CPU: 0.5, 3, 8, 12 percent of the machine). Header cells use separate whole-machine thresholds. All thresholds live in `Support/Heat.swift`.

**Actions** (`ProcessActions`).

- *End task / Force Quit*: Dock apps are asked to quit through `NSRunningApplication.terminate()` / `forceTerminate()`; other processes get `SIGTERM` / `SIGKILL`.
- *Efficiency mode*: `setpriority(PRIO_DARWIN_PROCESS, pid, PRIO_DARWIN_BG)` moves the process to the background class. It only works on processes you own.
- *Sample Process*: runs `/usr/bin/sample <pid> 3` and opens the report.
- *Run new task*: opens a path with its default app, or runs the text as a shell command (optionally with administrator privileges via AppleScript).

## Permissions and limitations

- **No App Sandbox.** Required to read other processes' statistics. Taskr is therefore not suitable for the Mac App Store as it stands.
- **Private API for "Not responding".** `CGSEventIsAppUnresponsive` is an undocumented WindowServer call (the same one Activity Monitor uses). `GetProcessForPID` is marked unavailable in Swift, so Taskr looks it up at runtime with `dlsym`. If either call disappears in a future macOS release, the Status column simply stops showing "Not responding".
- **Other users' processes.** macOS only lets you change priority of, signal or sample processes you own. Taskr shows a message when an action is refused. Some processes report no path or no statistics.
- **`nettop` per-process network** relies on a system tool whose output format could change. Totals in the header do not depend on it.
- **Performance page gaps.** Without root, macOS exposes no CPU clock speed or temperature on Apple silicon, so the CPU page shows the load average and the thermal state instead. GPU frequency, power state and media engine load are likewise unavailable. The renderer and tiler graphs appear only if the GPU driver reports them.
- **Wi-Fi network name** needs Location permission, so it shows "–" until that is granted.
- **App Nap** is not shown in the Status column.

## Conventions

- **Concurrency.** The target uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (Swift 5 language mode), so types are main-actor-isolated by default. Code that must run on a background thread is marked `nonisolated` (for example `NetworkSampler`, `GPUSampler`, `SystemStats`), and `NetworkSampler` is `@unchecked Sendable` with its own lock.
- **Files.** One main type per file, named after it. Extensions that add a distinct concern go in `Type+Concern.swift`. Every file starts with a short header saying what it is for.
- **Views stay presentational.** Formatting lives in `ProcessFormat`, thresholds in `Heat`, widths in `ProcessColumn`, state in `ProcessStore`.
- **No third-party dependencies.**

## Status

| Page | Status |
|---|---|
| Processes | Done |
| Performance (CPU, Memory, Disk, Network, GPU) | Done |
| App history, Startup apps, Users, Details, Services, Settings | Not built (placeholder) |

Planned next:

- App history, Startup apps, Users, Details, Services and Settings pages.
- Unit tests for grouping, row building and formatting.
- Show App Nap in the Status column.
