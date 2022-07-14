# Aspect Architecture: Triplicated 2oo3 Vital Executive, Memory Model, and Timing Guarantees

This document details the systems engineering, fault-tolerant computing architecture, and real-time execution model of the Aspect Railway Vital Computer-Based Interlocking (CBI) and ETCS Level 2 train control kernel.

---

## 1. System Architecture Overview

Aspect is architected around a layered, decoupled design separating vital safety-critical logic, real-time executive scheduling, physics simulation, and non-vital telemetry communications:

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

## 2. Triple Modular Redundancy (2oo3 TMR) Architecture

In compliance with CENELEC EN 50129 Section B.3 (Fault Tolerance Architectures), Aspect implements a hardware-abstracted **2-out-of-3 (2oo3)** voter. Three distinct processing channels (`Channel_A`, `Channel_B`, `Channel_C`) independently execute the identical interlocking logic on every cycle.

### 2.1 Channel Independence and State Isolation
Each channel maintains its own isolated record of the interlocking core:
* Channel memory blocks are distinct structures within `Triplicated_Channels`.
* Interlocking commands are duplicated and dispatched to all usable channels concurrently.
* No channel can read or mutate the internal memory of another channel directly.

### 2.2 Voting Logic and Majority Consensus
At the boundary of each minor cycle, output signals (lamp aspects, point machine relay drives, and emergency stop triggers) are presented to the 2oo3 Voter:

| Channel A | Channel B | Channel C | Voted Result | Voting Verdict | Operational Action |
|:---:|:---:|:---:|:---:|:---|:---|
| X | X | X | **X** | `Verdict_Unanimous_3oo3` | Full consensus; nominal operation |
| **Y** (Fault) | X | X | **X** | `Verdict_Majority_2oo3` | Fault masked; divergence logged on A |
| X | **Y** (Fault) | X | **X** | `Verdict_Majority_2oo3` | Fault masked; divergence logged on B |
| X | X | **Y** (Fault) | **X** | `Verdict_Majority_2oo3` | Fault masked; divergence logged on C |
| X | Y | Z | **Fail-Safe** | `Verdict_Tripped_Fail_Safe` | Total disagreement; clamp to Safe State |

### 2.3 Degradation State Machine (FDIR Lifecycle)
Fault Detection, Isolation, and Recovery (FDIR) continuously audits channel divergence:

```
  +-------------------------+
  |  Mode_Triplicated_3oo3  |  (3 Healthy Channels)
  +-------------------------+
               |
               | 3 Consecutive Divergences on Single Channel
               v
  +-------------------------+
  |    Mode_Degraded_2oo2   |  (Faulty Channel Permanently Isolated)
  +-------------------------+
               |
               | Any Disagreement Between 2 Remaining Channels
               v
  +-------------------------+
  | Mode_Tripped_Fail_Safe  |  (All Relays De-energized; Emergency Stop)
  +-------------------------+
```

1. **3oo3 Triplicated Mode**: Nominal baseline. All three channels vote. Single transient divergences increment `Consecutive_Divergences`.
2. **Transient vs Permanent Fault**: If an isolated channel returns to consensus on subsequent cycles, its consecutive divergence counter is reset to 0.
3. **Channel Isolation**: If any channel registers **3 consecutive divergences**, FDIR flags the channel as `Is_Isolated := True` and drops system mode to `Mode_Degraded_2oo2`.
4. **2oo2 Degraded Mode**: Both remaining healthy channels must achieve 100% unanimous agreement.
5. **Fail-Safe Trip**: If the two remaining channels in 2oo2 mode disagree on any vital boolean or signal aspect, consensus is impossible. The voter triggers `Mode_Tripped_Fail_Safe`, de-energizing all vital outputs and applying emergency brakes across the entire network.

---

## 3. Real-Time Execution Model and Timing Guarantees

Aspect utilizes a **synchronous cyclic executive** architecture, eliminating the non-determinism, priority inversions, and context-switch overhead of preemptive multi-threaded operating systems.

### 3.1 Minor Cycle Slicing (Hard 50 ms / 20 Hz)
The core operates on a strict **50 ms minor cycle**:
* $\Delta t = 50\text{ ms} \pm 2\text{ ms}$ jitter.
* Monotonic clock synchronization via high-precision POSIX C bindings:
  ```c
  clock_gettime(CLOCK_MONOTONIC, &ts);
  ```

### 3.2 Minor Cycle Execution Sequence
Within every 50 ms cycle, the executive executes four sequential phases:

```
 0 ms                                                                50 ms
 +-----------+--------------+------------+------------------+------------+
 | Phase 1   | Phase 2      | Phase 3    | Phase 4          | Phase 5    |
 | Field In  | Interlocking | 2oo3 Voter | Safety Barrier   | Field Out  |
 | Sampling  | Execution    | Consensus  | Invariant Filter | Actuation  |
 +-----------+--------------+------------+------------------+------------+
 < 0.8 ms >   < 1.5 ms >     < 0.6 ms >   < 0.5 ms >         < 0.8 ms >
 <------------------- Total Active WCET: ~4.2 ms ------------------------>
                                          <--- Idle Sleep: ~45.8 ms ----->
```

1. **Phase 1: Field Input Sampling (0 - 1 ms)**: Reads track circuit voltages, axle counter quadrature pulse registers, switch detection microswitch contacts, and Euroradio telemetry buffers.
2. **Phase 2: Triplicated Interlocking Execution (1 - 3 ms)**: Concurrently steps all active channels. Updates switch transit timers, evaluates route requests, advances approach locking timers, and computes dynamic RBC Movement Authorities.
3. **Phase 3: 2oo3 Voting & Fault Isolation (3 - 4 ms)**: Compares outputs across channels. Detects Byzantine single-event upsets, updates divergence metrics, and selects consensus values.
4. **Phase 4: Independent Safety Barrier Invariant Filter (4 - 4.5 ms)**: Independent formal checker verifies the 5 fundamental safety invariants against the voted state.
5. **Phase 5: Field Output Actuation & Sleep (4.5 - 50 ms)**: Latches relay states, formats zero-heap JSON telemetry snapshot, and sleeps via POSIX `nanosleep` until the next 50 ms epoch.

---

## 4. Static Memory Layout and Zero-Heap Allocation

Under EN 50128 SIL 4 guidelines, memory fragmentation, garbage collection, and dynamic pointer allocations are strictly prohibited in safety-critical code.

### 4.1 Compile-Time Bounded Geometry
All data structures in Aspect are statically bounded at compile time:

| Parameter | Identifier | Bound | Description |
|:---|:---|:---:|:---|
| Max Tracks | `Max_Sections` | 64 | Maximum track blocks monitored per interlocking sector |
| Max Switches | `Max_Switches` | 16 | Maximum turnout machines per sector |
| Max Signals | `Max_Signals` | 32 | Maximum multi-aspect colour light signals |
| Max Routes | `Max_Routes` | 32 | Maximum geographic routes configured in locking table |
| Max Balises | `Max_Balises` | 32 | Maximum Eurobalise transponder groups |
| Max Trains | `Max_Trains` | 8 | Maximum simultaneous active trains supervised |
| Max Flank Protections | `Max_Flank_Protections` | 8 | Maximum defensive flank points per route |
| Max Switches Per Route| `Max_Switches_Per_Route`| 8 | Maximum turnouts traversed by single route |

### 4.2 Zero-Heap Verification
* **No `Ada.Unchecked_Deallocation`**: The entire codebase contains zero deallocation statements.
* **No `new` Allocators**: All records, arrays, and buffers reside in the static Data/BSS segment.
* **Static BSS Footprint**: Total memory usage of the core kernel is under **16 MB**, guaranteeing that Aspect can run deterministically on embedded safety microcontrollers (e.g. ARM Cortex-R52, PowerPC e200) without an MMU or swap file.

---

## 5. POSIX C99 Platform Bindings

Low-level OS facilities are encapsulated in strict ANSI C99 bindings (`bindings/c/`):

1. **`posix_clock.c / posix_clock.h`**:
   * Nanosecond monotonic time acquisition using `CLOCK_MONOTONIC`.
   * High-resolution delta sleep using `nanosleep`.
   * Provides jitter-free 50ms pacing for the cyclic executive.

2. **`posix_socket.c / posix_socket.h`**:
   * Non-blocking BSD stream socket server.
   * `O_NONBLOCK` socket mode guarantees that client read/write stalls cannot block the vital 50ms minor cycle.
   * Direct integration with the zero-heap JSON protocol engine.
