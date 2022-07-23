# Aspect

<p align="center">
  <strong>Vital Computer-Based Interlocking (CBI) & European Train Control System (ETCS) Level 2 Kernel</strong><br>
  <em>Engineered in ISO Standard Ada 2022 with C99 POSIX Bindings</em><br>
  <em>Compliant with CENELEC EN 50128 SIL 4, EN 50129, and ERA ETCS Subset-026 v3.6.0</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Safety_Integrity-SIL_4_(EN_50128)-success.svg?style=flat-square" alt="SIL 4">
  <img src="https://img.shields.io/badge/Standards-ERA_ETCS_Subset--026-blue.svg?style=flat-square" alt="ETCS Subset-026">
  <img src="https://img.shields.io/badge/Language-Ada_2022_%2B_C99-orange.svg?style=flat-square" alt="Ada 2022">
  <img src="https://img.shields.io/badge/Architecture-2oo3_TMR-purple.svg?style=flat-square" alt="2oo3 TMR">
  <img src="https://img.shields.io/badge/Memory-Zero_Dynamic_Heap-brightgreen.svg?style=flat-square" alt="Zero Heap">
  <img src="https://img.shields.io/badge/Formal_Verification-657%2F657_Passed-darkgreen.svg?style=flat-square" alt="Verification 100%">
  <img src="https://img.shields.io/badge/License-MIT-lightgrey.svg?style=flat-square" alt="MIT License">
</p>

---

## Overview

**Aspect** is a full-scale, production-grade Railway Vital Computer-Based Interlocking (CBI) and ETCS Level 2 train control supervisory kernel. It combines the rigorous safety assurance of **CENELEC EN 50128 SIL 4** with real-time multi-train physics simulation, high-resolution odometry sensor fusion, a triplicated 2oo3 voting executive, an interactive VT100 terminal user interface, and an HTML5 web dispatcher cockpit.

Railway signalling is one of the most unforgiving domains in computer science: heavy passenger and freight trains cannot steer around obstacles or halt within the driver's line of sight. Safety depends entirely upon deterministic software invariants that guarantee zero route collisions, zero turnout derailments, zero flank incursions, and zero speed ceiling violations under all single-point hardware faults, Byzantine channel divergence, and communication dropouts.

Aspect is built from the ground up to demonstrate how mathematical formal methods, static memory guarantees, and multi-channel redundancy combine to achieve fail-safe computing.

---

## Key Technical Highlights

* **CENELEC EN 50128 SIL 4 Compliance**:
  * **Zero Dynamic Heap Allocation**: Zero invocations of `Ada.Unchecked_Deallocation`, `malloc`, or dynamic access types. All data structures, route matrices, and packet queues are statically sized in compile-time BSS.
  * **Deterministic 50ms Minor Cycle (20 Hz)**: Hard real-time execution paced by POSIX monotonic clock bindings (`clock_gettime(CLOCK_MONOTONIC)`) with timing jitter $< 2$ ms.
  * **Strong Ada 2022 Typing**: Dimensional scalar ranges preventing numeric overflow and incompatible unit assignments at compile time.

* **Triple Modular Redundancy (2oo3 TMR) Voter**:
  * Triplicated independent interlocking execution channels (`Channel_A`, `Channel_B`, `Channel_C`).
  * Majority voting algorithm masking single-event bit-flips and Byzantine CPU failures without service interruption.
  * Fault Detection, Isolation, and Recovery (FDIR) state machine: isolates faulted channels after 3 consecutive divergences (`3oo3` -> `2oo2`), and triggers fail-safe emergency stop if consensus is lost in degraded mode.

* **Independent 5-Barrier Safety Invariant Monitor**:
  * Primary defense-in-depth barrier auditing all voted outputs before field actuation:
    1. *Mutual Route Exclusion*: Guarantees intersecting or opposing routes never clear simultaneously.
    2. *Detector Locking*: Prevents point machine movement when track circuits are shunted or disturbed.
    3. *Flank Integrity*: Proves defensive points are clamped in diverting alignment and opposing shunt signals are held at danger.
    4. *Signal Lamp Proving*: Clamps signals to `Aspect_Stop` if filament current falls below safe thresholds.
    5. *Overrun Overlap Protection*: Enforces a 200m reservation buffer and 30-second thermal standstill release timer.

* **ERA ETCS Level 2 Radio Block Centre (RBC) & European Vital Computer (EVC)**:
  * Dynamic Movement Authority (MA) synthesis using Euroradio Packet 12, Packet 21 (Gradients), and Packet 27 (Speed Profiles).
  * Exact mathematical implementation of **ERA ETCS Subset-026 Chapter 3.13** deceleration curves:
    $$\boxed{0 \le V_{Indication} \le V_{Permitted} \le V_{Warning} \le V_{SBI} \le V_{EBI}}$$
  * Closed-loop train model: Davis aerodynamic drag polynomial ($R_{Davis} = A + Bv + Cv^2$), multi-sensor odometry fusion (dual wheel impulse sensors + Doppler radar with slip/slide correction), and Eurobalise chainage recalibration.

* **Non-Vital Telemetry, TUI, and Web Cockpit**:
  * Zero-heap allocation-free JSON serializer streaming real-time operational snapshots over non-blocking POSIX TCP sockets.
  * VT100 / ANSI terminal interface rendering live ASCII track layouts, point blade alignments, 4-aspect signal lamps, and a circular DMI speedometer dial.
  * Web-based dispatcher workstation with reactive SVG graphics, real-time DMI gauge, and zero-dependency RFC 6455 WebSocket gateway (`scripts/visualizer_server.py`).

---

## Architectural Block Diagram

```
+-------------------------------------------------------------------------------+
|                       NON-VITAL SUITE / OPERATOR TIER                         |
|  - HTML5 WebSocket Dispatcher Cockpit (Browser / SVG Canvas / DMI Gauge)      |
|  - Interactive VT100 / ANSI Terminal User Interface (Canvas Double-Buffer)    |
|  - Zero-Heap JSON Telemetry Dispatcher & Snapshot Protocol Engine             |
|  - C POSIX Non-Blocking Stream Socket Server (TCP Port 8088 / Unix Domain)    |
+-------------------------------------------------------------------------------+
                                      |
                      Asynchronous Dispatcher Commands
                      & Cyclic Status Snapshot Streams
                                      v
+-------------------------------------------------------------------------------+
|                       VITAL RAILWAY SUPERVISION KERNEL                        |
|                                                                               |
|  +-------------------------------------------------------------------------+  |
|  |                 TRIPLE MODULAR REDUNDANCY (2oo3) VOTER                  |  |
|  |  Channel A (Interlocking) | Channel B (Interlocking) | Channel C (Interlocking)
|  +-------------------------------------------------------------------------+  |
|                                      |                                        |
|                          Voted Interlocking Outputs                           |
|                                      v                                        |
|  +-------------------------------------------------------------------------+  |
|  |                INDEPENDENT SAFETY BARRIER INVARIANTS                    |  |
|  |  - Mutual Route Exclusion          - Point Zone Detector Locking        |  |
|  |  - Defensive Flank Protection      - Signal Aspect Proving              |  |
|  |  - Overrun Overlap Verification    - Speed Supervision Containment      |  |
|  +-------------------------------------------------------------------------+  |
|                                      |                                        |
|                           Approved Vital Actuations                           |
|                                      v                                        |
|  +-------------------------------------------------------------------------+  |
|  |             EUROPEAN TRAIN CONTROL SYSTEM (ETCS LEVEL 2)                |  |
|  |  - Radio Block Centre (RBC) Dynamic Movement Authority (MA) Synthesis   |  |
|  |  - Euroradio Packet 12, Packet 21 (Gradient), Packet 27 (Speed Profiles)|  |
|  |  - European Vital Computer (EVC) Subset-026 Chapter 3.13 Braking Model  |  |
|  +-------------------------------------------------------------------------+  |
+-------------------------------------------------------------------------------+
                                      |
                           Field Actuation Signals
                           & Sensor Impulse Sampling
                                      v
+-------------------------------------------------------------------------------+
|                     PHYSICAL RAILWAY TOPOLOGY & SENSORS                       |
|  - Dual Axle Counter Impulses & Audio Frequency Track Circuit Resonators      |
|  - Electro-Hydraulic Point Machines with Blade Detection Microswitches        |
|  - Multi-Aspect LED Signals with Filament Current Monitoring Sensors         |
|  - Fixed & Controlled Eurobalises with 1023-Bit Telegram Shift Registers      |
|  - Closed-Loop Multi-Train Physics (Davis Drag, Tractive Torque, Odometry)    |
+-------------------------------------------------------------------------------+
```

---

## Mathematical Formulations

### 1. Train Deceleration and Torricelli Kinematics
Maximum safe speed $v(d)$ at distance $d$ from a target restriction point:

$$v(d) = \sqrt{v_{target}^2 + 2 \cdot a_{effective} \cdot d}$$

Where effective deceleration $a_{effective}$ incorporates nominal braking, track gradient, and running resistance:

$$a_{effective}(v) = a_{nominal} + g \cdot \frac{g_i}{1000} + \frac{A + B \cdot v + C \cdot v^2}{M}$$

### 2. ETCS Subset-026 Speed Supervision Envelopes
The five supervision envelopes are calculated with specific pneumatic and human response delays:
* **Emergency Brake Intervention (EBI)**:
  $$V_{EBI}(d_{SvL}) = \max\left(v_{target}, \; \sqrt{v_{target}^2 + 2 \cdot a_{emerg} \cdot d_{SvL}} - a_{emerg} \cdot t_{ebi\_lag}\right)$$
* **Service Brake Intervention (SBI)**:
  $$V_{SBI}(d_{EoA}) = \max\left(v_{target}, \; \sqrt{v_{target}^2 + 2 \cdot a_{serv} \cdot d_{EoA}} - a_{serv} \cdot t_{sbi\_lag}\right)$$
* **Warning Curve (W)**:
  $$V_{Warning}(d) = \max\left(v_{target}, \; V_{SBI}(d) - a_{serv} \cdot t_{warning}\right)$$
* **Permitted Speed (P)**:
  $$V_{Permitted}(d) = \min\left(V_{ceiling}, \; \max\left(V_{release}, \; V_{Warning}(d) - 1.0\text{ m/s}\right)\right)$$
* **Indication Curve (I)**:
  $$V_{Indication}(d) = \max\left(v_{target}, \; V_{Permitted}(d) - a_{serv} \cdot t_{driver}\right)$$

---

## Directory Structure

```
aspect/
├── Makefile                                # Unified build, test, and verification automation
├── aspect.gpr                              # GNAT Project definition (Ada 2022 + C99)
├── bindings/
│   └── c/                                  # Zero-overhead ANSI C99 POSIX platform layer
│       ├── posix_clock.h / .c              # Nanosecond CLOCK_MONOTONIC and nanosleep
│       └── posix_socket.h / .c             # Non-blocking BSD stream socket server
├── src/
│   ├── core/                               # Fundamental types, kinematics, and CRC algorithms
│   │   ├── aspect.ads                      # Root library specification
│   │   ├── aspect-types.ads                # SIL 4 bounded scalar range types
│   │   ├── aspect-math.ads / .adb          # Fixed-point math and Davis resistance equations
│   │   ├── aspect-crc.ads / .adb           # CRC-10 (Subset-036), CRC-16, Castagnoli CRC-32C
│   │   └── aspect-posix.ads / .adb         # Ada thin/thick bindings to C POSIX layer
│   ├── topology/                           # Permanent way infrastructure and sensor components
│   │   ├── aspect-topology.ads / .adb      # Coordinate geometry and spatial vectors
│   │   ├── aspect-topology-tracks.ads / .adb    # Track circuits, axle counters, ballast leakage
│   │   ├── aspect-topology-switches.ads / .adb  # Point machines, stroke timers, blade gap proving
│   │   ├── aspect-topology-signals.ads / .adb   # 4-aspect LED heads and filament current sensing
│   │   ├── aspect-topology-balises.ads / .adb   # Eurobalise 1023-bit FSK telegram encoding
│   │   └── aspect-topology-network.ads / .adb   # Geographic railway network graph routing
│   ├── interlocking/                       # Vital Computer-Based Interlocking (CBI) logic
│   │   ├── aspect-interlocking.ads         # Interlocking root specification
│   │   ├── aspect-interlocking-routes.ads / .adb # Route definitions and lifecycle state machine
│   │   ├── aspect-interlocking-locking_table.ads / .adb # Geographic route exclusion matrix
│   │   ├── aspect-interlocking-flank.ads / .adb   # Defensive point setting and shunt signal locks
│   │   ├── aspect-interlocking-overlap.ads / .adb # Overrun safety overlap and 30s timer
│   │   ├── aspect-interlocking-approach.ads / .adb# 120s run-approach locking timer
│   │   ├── aspect-interlocking-detector.ads / .adb# Point zone detector locking under occupancy
│   │   └── aspect-interlocking-engine.ads / .adb  # Central CBI executive engine
│   ├── etcs/                               # ETCS Level 2 train control subsystem
│   │   ├── aspect-etcs.ads / .adb          # Subset-026 constants and unit conversions
│   │   ├── aspect-etcs-packets.ads / .adb  # Packet 3, 5, 12, 21, 27 telegram builders
│   │   ├── aspect-etcs-braking_curves.ads / .adb# Subset-026 Chapter 3.13 braking equations
│   │   ├── aspect-etcs-movement_authority.ads / .adb# Dynamic MA synthesis
│   │   ├── aspect-etcs-rbc.ads / .adb      # Radio Block Centre trackside session manager
│   │   ├── aspect-etcs-euroradio.ads / .adb# Euroradio frame validation and sequence watchdog
│   │   └── aspect-etcs-dmi_model.ads / .adb# Driver Machine Interface gauge model
│   ├── vital/                              # Triplicated 2oo3 executive and safety invariants
│   │   ├── aspect-vital.ads                # Vital voting outcome records
│   │   ├── aspect-vital-channels.ads / .adb# Triplicated channel state isolation
│   │   ├── aspect-vital-voter.ads / .adb   # 2oo3 majority consensus voting algorithms
│   │   ├── aspect-vital-safety_invariants.ads / .adb# Independent 5-barrier invariant monitor
│   │   ├── aspect-vital-cyclic_executive.ads / .adb# Hard 50ms minor cycle supervisor
│   │   └── aspect-vital-fdir.ads / .adb    # Fault Detection, Isolation, and Recovery manager
│   ├── sim/                                # Closed-loop physics simulation and scenarios
│   │   ├── aspect-sim.ads                  # Simulation environment root
│   │   ├── aspect-sim-vehicle_dynamics.ads / .adb # Davis drag, traction curve, pneumatic brakes
│   │   ├── aspect-sim-odometry.ads / .adb  # Dual APG + Doppler radar fusion with slip/slide
│   │   ├── aspect-sim-track_simulation.ads / .adb # Continuous chainage and train shunt physics
│   │   ├── aspect-sim-scenarios.ads / .adb # Built-in scenarios (Junction, LGV, Stress)
│   │   ├── aspect-sim-scenario_loader.ads / .adb# Declarative JSON scenario parser
│   │   └── aspect-sim-world.ads / .adb     # Master closed-loop simulation coordinator
│   ├── telemetry/                          # Non-vital zero-heap JSON telemetry streaming
│   │   ├── aspect-telemetry.ads / .adb     # Snapshot capture and structured state records
│   │   ├── aspect-telemetry-protocol.ads / .adb# Zero-heap string serializer & command parser
│   │   └── aspect-telemetry-server.ads / .adb# POSIX socket listener and dispatch server
│   ├── tui/                                # VT100 / ANSI terminal user interface
│   │   ├── aspect-tui.ads                  # Palette definitions and ANSI escape codes
│   │   ├── aspect-tui-canvas.ads / .adb    # 120x36 double-buffered character canvas
│   │   ├── aspect-tui-track.ads / .adb     # ASCII track schematic & switch blade renderer
│   │   ├── aspect-tui-signals.ads / .adb   # Multi-aspect color lamp visualizer
│   │   ├── aspect-tui-dmi.ads / .adb       # Circular DMI speedometer gauge renderer
│   │   └── aspect-tui-diagnostics.ads / .adb# 2oo3 channel health and FDIR metrics panel
│   └── cli/
│       ├── aspect-cli.ads / .adb           # Command-line argument parser
│       └── aspect_main.adb                 # Main system entrypoint
├── scenarios/                              # Declarative JSON track and train topologies
│   ├── junction.json                       # Grand Central Junction multi-route network
│   ├── high_speed.json                     # 300 km/h LGV high-speed corridor
│   └── safety_stress.json                  # Multi-train conflicting junction stress test
├── web/                                    # HTML5 dispatcher cockpit workstation
│   ├── index.html                          # Dispatcher console with SVG layout & DMI dial
│   ├── style.css                           # Railway dark-mode visual design system
│   └── app.js                              # Live WebSocket client and interactive controller
├── scripts/
│   └── visualizer_server.py                # Zero-dependency RFC 6455 WebSocket gateway
├── tests/
│   ├── runner/test_runner.adb              # Master test suite executable
│   ├── framework/aspect-tests-framework.ads / .adb # Micro test framework with color logging
│   ├── suites/                             # 10 comprehensive verification test suites
│   │   ├── aspect-tests-core.ads / .adb
│   │   ├── aspect-tests-topology.ads / .adb
│   │   ├── aspect-tests-interlocking.ads / .adb
│   │   ├── aspect-tests-etcs.ads / .adb
│   │   ├── aspect-tests-vital.ads / .adb
│   │   ├── aspect-tests-sim.ads / .adb
│   │   ├── aspect-tests-telemetry.ads / .adb
│   │   ├── aspect-tests-posix.ads / .adb
│   │   ├── aspect-tests-scenario_loader.ads / .adb
│   │   └── aspect-tests-formal.ads / .adb
│   └── formal/                             # Mathematical property verification tests
│       ├── aspect-formal-oracles.ads / .adb# Safety oracles (Collision, Flank, Locking, Curves)
│       ├── aspect-formal-collision.ads / .adb # 10,000 cycle collision-freedom property test
│       ├── aspect-formal-switch_locking.ads / .adb # Detector locking property test
│       ├── aspect-formal-flank_integrity.ads / .adb# Defensive flank integrity property test
│       ├── aspect-formal-curve_containment.ads / .adb# Speed supervision monotonicity proof
│       └── aspect-formal-tmr_byzantine.ads / .adb # 2oo3 Byzantine fault masking test
└── docs/                                   # In-depth technical engineering documentation
    ├── safety_case/SIL4_SAFETY_CASE.md     # EN 50128 SIL 4 Safety Case, HAZOP, & FMECA
    ├── etcs_braking/SUBSET_026_DERIVATION.md # Mathematical derivation of braking parabolas
    ├── interlocking_rules/INTERLOCKING_PRINCIPLES.md # Geographic locking & flank rules
    ├── architecture/ARCHITECTURE.md        # 2oo3 TMR vital executive & memory guarantees
    ├── architecture/DIAGRAMS.md            # Comprehensive Mermaid architecture diagrams
    ├── telemetry/TELEMETRY_PROTOCOL.md     # Zero-heap JSON schema & RFC 6455 protocol
    └── DEVELOPER_GUIDE.md                  # Developer manual & interactive keyboard controls
```

---

## Quickstart Guide

### 1. Build and Run Verification
```bash
# Clone the repository
git clone https://github.com/Aneesh495/aspect.git
cd aspect

# Build all binaries (zero dependencies)
make build

# Execute full verification pass (657 assertions, 10 suites)
make test
```

### 2. Interactive ANSI Terminal UI
Launch the real-time simulation in your terminal:
```bash
make sim
```
Use keys `1` through `9` to set routes, `C` to cancel a route, `S` to throw switches, `E` for emergency stop, and `Q` to quit.

### 3. Launch Web Dispatcher Cockpit
Open two terminal windows:
```bash
# Terminal 1: Launch Aspect Telemetry Server on TCP port 8088
make server

# Terminal 2: Launch WebSocket Gateway on port 8080
make web
```
Open your browser to `http://localhost:8080` to interact with the live SVG track map and DMI speedometer dial.

---

## Standards Compliance Matrix

| Standard | Clause / Section | Requirement | Aspect Implementation |
|:---|:---|:---|:---|
| **CENELEC EN 50128** | Clause 7.3.2.2 | Prohibition of Dynamic Memory Allocation | 100% static BSS memory; zero heap allocators or deallocations. |
| **CENELEC EN 50128** | Clause 7.3.2.4 | Defensive Programming & Range Checking | Ada 2022 scalar range types with dynamic checks (`-gnato`, `-gnata`). |
| **CENELEC EN 50128** | Clause 7.4.2.3 | Deterministic Timing & WCET | Synchronous 50ms cyclic executive with WCET measured $< 4.5$ ms. |
| **CENELEC EN 50129** | Section B.3 | Fault-Tolerant Computer Architectures | 2oo3 Triple Modular Redundancy with Byzantine fault masking. |
| **CENELEC EN 50129** | Section 5.3 | Independent Safety Invariants | 5-barrier invariant monitor guarding all field relay drives. |
| **ERA ETCS Subset-026**| Chapter 3.13 | Braking Curves & Supervision Envelopes | Exact closed-form implementation of $V_{Ind} \le V_{Perm} \le V_{Warn} \le V_{SBI} \le V_{EBI}$. |
| **ERA ETCS Subset-026**| Chapter 3.6 | Movement Authority (MA) Synthesis | Dynamically synthesized Packet 12, Packet 21, and Packet 27 telegrams. |
| **ERA ETCS Subset-036**| Section 5.3 | Eurobalise Telegram Encoding | CRC-10 parity polynomial and 1023-bit bitshift registers. |

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
