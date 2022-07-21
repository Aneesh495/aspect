# Aspect Developer Guide & Operational Walkthrough

Welcome to Aspect, an open-source high-assurance Railway Vital Computer-Based Interlocking (CBI) and ETCS Level 2 train control supervisory kernel written in ISO standard Ada 2022 with C99 POSIX platform bindings.

This guide provides step-by-step instructions for building the project, running the formal verification suite, launching the interactive terminal user interface, controlling the web dispatcher cockpit, and authoring declarative track scenarios.

---

## 1. Prerequisites and Toolchain Setup

Aspect has zero external third-party library dependencies. It compiles directly using standard GNAT FSF Ada compilers and native POSIX C toolchains.

### macOS (Apple Silicon / Intel)
Install the GNAT toolchain via Homebrew:
```bash
brew install gcc
# Ensure gnat and gprbuild are on PATH
which gprbuild
```

### Linux (Debian / Ubuntu / Fedora)
```bash
# Debian / Ubuntu:
sudo apt-get update && sudo apt-get install -y gnat gprbuild make python3

# Fedora / Red Hat:
sudo dnf install -y gcc-gnat gprbuild make python3
```

Verify your compiler supports Ada 2022:
```bash
gnat --version
gprbuild --version
```

---

## 2. Building the Project

The build system is managed via standard `make` and GNAT project files (`aspect.gpr`).

### Build Targets:
```bash
# Compile both the main CLI executable and the test runner
make build

# Compile with optimized release profile
make release

# Run the complete test suite (657 assertions, 10 suites)
make test

# Full verification: run test runner and code quality invariant checks
make verify

# Clean all build artifacts
make clean
```

The compiled binaries will be placed in the `bin/` directory:
* `bin/aspect_main`: Main interactive CLI, simulation engine, and telemetry server.
* `bin/test_runner`: Automated test runner executing the 10 verification suites.

---

## 3. Running the Formal Verification Suite

To run all 10 unit, integration, and formal property test suites:
```bash
make test
```

Expected output:
```
============================================================
  ASPECT RAILWAY SAFETY VERIFICATION SUITE
  Standards: EN 50128 SIL 4 / ERA ETCS Subset-026
============================================================

[SUITE] Aspect.Core (Types, Math, CRC)
  [PASS] Aspect.Core (Types, Math, CRC) ( 13/ 13 assertions)
[SUITE] Aspect.Topology (Tracks, Switches, Signals, Balises, Network)
  [PASS] Aspect.Topology (Tracks, Switches, Signals, Balises, Network) ( 37/ 37 assertions)
[SUITE] Aspect.Interlocking (CBI Engine, Locking Table, Flank, Sectional
  [PASS] Aspect.Interlocking (CBI Engine, Locking Table, Flank, Sectional ( 19/ 19 assertions)
[SUITE] Aspect.ETCS (Packets, Braking Curves, MA, Euroradio, DMI)
  [PASS] Aspect.ETCS (Packets, Braking Curves, MA, Euroradio, DMI) ( 32/ 32 assertions)
[SUITE] Aspect.Vital (2oo3 TMR, Voting, Safety Barrier Invariants, FDIR)
  [PASS] Aspect.Vital (2oo3 TMR, Voting, Safety Barrier Invariants, FDIR) ( 28/ 28 assertions)
[SUITE] Aspect.Sim (Vehicle Dynamics, Odometry, Closed-Loop World)
  [PASS] Aspect.Sim (Vehicle Dynamics, Odometry, Closed-Loop World) ( 29/ 29 assertions)
[SUITE] Aspect.Telemetry (Snapshot Capture and JSON Protocol)
  [PASS] Aspect.Telemetry (Snapshot Capture and JSON Protocol) ( 30/ 30 assertions)
[SUITE] Aspect.POSIX (Monotonic Clock, Sleep, and Non-Blocking Sockets)
  [PASS] Aspect.POSIX (Monotonic Clock, Sleep, and Non-Blocking Sockets) ( 15/ 15 assertions)
[SUITE] Aspect.Sim (Declarative JSON Scenario Loader)
  [PASS] Aspect.Sim (Declarative JSON Scenario Loader) ( 13/ 13 assertions)
[SUITE] Aspect.Formal (SIL 4 Invariants, Collision, Flank, Curves, 2oo3 
  [PASS] Aspect.Formal (SIL 4 Invariants, Collision, Flank, Curves, 2oo3  ( 657/ 657 assertions)

============================================================
  ALL VERIFICATION SUITES PASSED SUCCESSFULLY.
============================================================
```

---

## 4. Interactive ANSI Terminal User Interface (TUI)

Aspect includes a VT100/ANSI terminal user interface rendering a live schematic of the interlocking tracks, switch blades, multi-aspect lamps, and circular DMI speedometer dial.

To launch the TUI:
```bash
make sim
# or directly:
./bin/aspect_main --scenario junction --tui
```

### Keyboard Controls:
* `1` through `9`: Request Route 1 through 9.
* `C`: Cancel currently selected route (initiates 120s approach locking if train approaching).
* `S`: Throw selected switch point machine.
* `E`: Emergency Stop (instantly trips all signals to danger and halts all trains).
* `A`: Acknowledge emergency alarm and reset latch.
* `Q`: Exit simulation safely.

---

## 5. Web Dispatcher Cockpit & Python WebSocket Bridge

For a visual control room experience, Aspect includes a web-based dispatcher workstation featuring an interactive SVG track schematic and real-time ETCS speedometer gauge.

### Launching the Web Cockpit:
1. **Start the Aspect Telemetry Server** in one terminal:
   ```bash
   make server
   # Launches simulation listening on TCP port 8088
   ```

2. **Launch the WebSocket Gateway** in a second terminal:
   ```bash
   make web
   # Starts HTTP static server and RFC 6455 WebSocket bridge on port 8080
   ```

3. **Open Your Browser**:
   Navigate to `http://localhost:8080`.

### Web Cockpit Features:
* **Interactive SVG Track Layout**: Tracks glow blue when reserved, yellow when occupied, and cyan when idle. Switches animate between normal and diverging alignment.
* **Live Signal Heads**: Color-coded LED lamps rendering Red (`Stop`), Yellow (`Caution`), and Green (`Clear`).
* **ETCS Circular Speedometer Gauge**: Real-time needle displaying current velocity against dynamic arcs for $V_{Permitted}$ (Green), $V_{Warning}$ (Yellow), $V_{SBI}$ (Orange), and $V_{EBI}$ (Red).
* **2oo3 Health Panel**: Real-time divergence metrics and isolation status for Channels A, B, and C.
* **Control Buttons**: Clickable buttons to set routes, cancel routes, throw switches, and trigger emergency stop.

---

## 6. Headless Batch Simulation and Benchmarks

To run headless performance simulations for testing and benchmarking:
```bash
./bin/aspect_main --scenario high_speed --headless --ticks 2000
```

Command-Line Arguments:
* `--scenario <name>`: Select scenario (`junction`, `high_speed`, `safety_stress`, or path to `.json` file).
* `--tui`: Enable interactive VT100 terminal interface.
* `--headless`: Run non-interactively at maximum CPU speed.
* `--ticks <count>`: Number of minor cycles to execute before terminating (0 = infinite).
* `--port <number>`: Start non-blocking TCP telemetry server on specified port (e.g. 8088).

---

## 7. Declarative JSON Scenario Authoring

Scenarios can be authored declaratively in JSON without modifying code. Example structure (`scenarios/my_junction.json`):

```json
{
  "name": "Custom Junction Scenario",
  "sections": [
    {"id": 1, "length_m": 500.0, "speed_limit_kph": 160.0},
    {"id": 2, "length_m": 800.0, "speed_limit_kph": 160.0}
  ],
  "switches": [
    {"id": 1, "point_section": 1, "diverging_section": 2}
  ],
  "signals": [
    {"id": 1, "section": 1, "aspect_count": 4}
  ],
  "balises": [
    {"id": 1, "section": 1, "chainage_m": 250.0}
  ],
  "routes": [
    {
      "id": 1,
      "origin_signal": 1,
      "destination_signal": 2,
      "sections": [1, 2],
      "switches": [{"id": 1, "position": "Normal"}]
    }
  ],
  "trains": [
    {
      "id": 1,
      "initial_section": 1,
      "initial_chainage_m": 50.0,
      "initial_speed_kph": 0.0,
      "max_speed_kph": 160.0,
      "length_m": 200.0,
      "mass_tonnes": 400.0
    }
  ]
}
```

Load your custom scenario with:
```bash
./bin/aspect_main --scenario scenarios/my_junction.json --tui
```
