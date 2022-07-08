# Aspect SIL 4 Safety Assurance Case

This document presents the formal Safety Case for the Aspect Railway Computer-Based Interlocking (CBI) and European Train Control System (ETCS) Level 2 supervisory kernel. The safety arguments, structural guarantees, and hazard analyses adhere to the European standards for railway safety-critical electronics and software:

* **CENELEC EN 50126**: Specification and Demonstration of Reliability, Availability, Maintainability and Safety (RAMS).
* **CENELEC EN 50128**: Railway applications: Communication, signalling and processing systems: Software for railway control and protection systems (Safety Integrity Level 4).
* **CENELEC EN 50129**: Railway applications: Communication, signalling and processing systems: Safety-related electronic systems for signalling.
* **ERA ETCS Subset-026**: System Requirements Specification (SRS) for European Vital Computer and Radio Block Centre.

---

## 1. Safety Goal and Integrity Classification

The primary safety objective of the Aspect kernel is the absolute prevention of hazardous train control states:
1. **Zero Route Collisions**: Two trains shall never occupy conflicting or overlapping track reservations simultaneously.
2. **Zero Derailments Due to Turnout Contention**: Switch point blades shall never move while a train axle shunts the point zone or while an active route reserves the turnout.
3. **Zero Flank Incursions**: Movement over diverging or converging junctions shall be defensively guarded by points clamped in diverting alignments and opposing signals clamped at danger.
4. **Zero Speed Envelope Violations**: Train speed shall never exceed the Emergency Brake Intervention (EBI) supervision ceiling calculated from the current Supervised Location (SvL).

Under EN 50128 and EN 50129, these objectives mandate **Safety Integrity Level 4 (SIL 4)**:
* Target Tolerable Hazard Rate (THR): $< 10^{-9}$ dangerous failures per operating hour.
* Software systematic failure avoidance: 100% formal and deterministic verification of code paths.

---

## 2. Claim-Argument-Evidence (CAE) Architecture

The safety justification is organized hierarchically according to the Goal Structuring Notation (GSN) / Claim-Argument-Evidence (CAE) framework:

```
[Claim C1]: Aspect guarantees SIL 4 safety properties under all single hardware faults,
             transient communication corruptions, and malicious dispatcher inputs.
     |
     +--> [Argument A1]: Deterministic execution and memory isolation prevent systematic software faults.
     |         |
     |         +--> [Evidence E1.1]: Static BSS memory allocation; zero heap usage (no dynamic pointers).
     |         +--> [Evidence E1.2]: Hard 50ms cyclic executive; deterministic execution jitter < 2ms.
     |         +--> [Evidence E1.3]: Strict Ada 2022 strong typing with bounded range types and overflow checks.
     |
     +--> [Argument A2]: 2oo3 Triple Modular Redundancy masks Byzantine and random hardware faults.
     |         |
     |         +--> [Evidence E2.1]: Triplicated independent interlocking execution channels.
     |         +--> [Evidence E2.2]: Majority voter with automatic degraded mode transition (2oo3 -> 2oo2 -> Fail-Safe).
     |         +--> [Evidence E2.3]: Independent 5-barrier vital safety invariant filter rejecting unvoted writes.
     |
     +--> [Argument A3]: Interlocking logic strictly enforces classical railway route safety principles.
     |         |
     |         +--> [Evidence E3.1]: Geographic locking table with automated route exclusion matrix.
     |         +--> [Evidence E3.2]: Point detector locking proving switch blade gap < 3.5mm before clear aspect.
     |         +--> [Evidence E3.3]: Defensive flank protection and 30-second overrun overlap hold timers.
     |
     +--> [Argument A4]: ETCS Level 2 braking curves guarantee fail-safe deceleration containment.
               |
               +--> [Evidence E4.1]: Mathematical derivation of Subset-026 Chapter 3.13 braking parabolas.
               +--> [Evidence E4.2]: Strict ordering: V_Indication <= V_Permitted <= V_Warning <= V_SBI <= V_EBI.
               +--> [Evidence E4.3]: Automated emergency trip trigger when speed envelope is crossed.
```

---

## 3. Hazard and Operability (HAZOP) Study

The following HAZOP matrix evaluates core system nodes against standard guidewords (No, More, Less, As Well As, Reverse, Other Than):

| Hazard ID | Subsystem | Parameter | Guideword | Cause | Consequence | Implemented SIL 4 Mitigation |
|:---|:---|:---|:---|:---|:---|:---|
| **HAZ-01** | Interlocking | Switch Position | Other Than | Switch thrown under moving train | Side derailment / gauge widening | Point detector interlock verifies `Occupancy = State_Clear` and `Is_Mechanically_Locked = False` before initiating motor transit. |
| **HAZ-02** | Interlocking | Route Setting | As Well As | Conflicting routes cleared simultaneously | Head-on or converging collision | Symmetrical conflict table enforces mutual exclusion; secondary formal invariant barrier trips system if conflicting routes clear. |
| **HAZ-03** | Signals | Lamp Aspect | More | False clear aspect displayed to driver | Train proceeds into occupied section | Lamp filament current sensing detects open circuits; fail-safe defaults to `Aspect_Stop` upon sensor mismatch. |
| **HAZ-04** | ETCS Braking | Distance Calc | Less | Odometry underestimates travel distance | Late brake application beyond SvL | Multi-sensor fusion (dual wheel impulse + Doppler radar) with balise recalibration; safety margin added to reaction lag. |
| **HAZ-05** | Communication | Euroradio | Reverse | Replay of old Movement Authority frame | Train accelerates onto outdated path | Monotonic 32-bit sequence numbers, session keys, and 5000ms heartbeat watchdog reject stale frames. |
| **HAZ-06** | Vital Executive| Channel Sync | Other Than | Single-event upset (bit-flip) in Channel A | Corrupted switch or signal command | 2oo3 voter identifies divergence, masks faulty output, and isolates channel after 3 consecutive errors. |

---

## 4. Failure Modes, Effects, and Criticality Analysis (FMECA)

Severity (S), Occurrence (O), and Detection (D) are ranked on a 1-10 scale. The Risk Priority Number (RPN) is given by:

$$RPN = S \times O \times D$$

Under SIL 4 requirements, all single-point failures with Severity $\ge 8$ must have automated detection ($D \le 2$), reducing the residual RPN below 40.

| Failure Mode | Direct Effect | S | O | D | RPN | Automated Safety Action | Post-Mitigation RPN |
|:---|:---|:---:|:---:|:---:|:---:|:---|:---:|
| Switch motor stalls mid-stroke | Point blades not locked in Normal/Reverse | 8 | 4 | 1 | 32 | 3500ms stroke timeout flags `Obstacle_Stall_Fault`; origin signal drops to `Aspect_Stop`. | 8 (S=8, O=1, D=1) |
| Audio frequency track circuit ballast leakage | Phantom occupancy or false clear | 9 | 3 | 1 | 27 | Axle counter dual validation and ballast conductance bounds detect rail-to-rail leakage. | 9 (S=9, O=1, D=1) |
| Memory pointer corruption | Random state overwrite | 10 | 2 | 1 | 20 | Complete ban on dynamic heap allocation; all data static BSS with Ada range checks. | 10 (S=10, O=1, D=1) |
| RBC connection timeout | Loss of continuous train supervision | 7 | 4 | 1 | 28 | 5000ms Euroradio timeout triggers onboard EVC Service Brake application to standstill. | 7 (S=7, O=1, D=1) |
| Flank switch uncommanded movement | Lateral fouling of active express path | 9 | 2 | 1 | 18 | Continuous flank lock monitoring; if flank status drops, origin signal drops instantly to danger. | 9 (S=9, O=1, D=1) |

---

## 5. Software Architectural Integrity (EN 50128 Clauses)

### 5.1 Static Memory Allocation (Zero Dynamic Heap)
Under EN 50128 SIL 4 Clause 7.3.2.2, dynamic memory allocation during operational runtime is strictly forbidden due to memory leak risks, fragmentation, and non-deterministic allocation latency.
* The Aspect codebase contains **zero** invocations of `Ada.Unchecked_Deallocation`, `malloc`, or dynamic access types.
* All arrays, route tables, track topology graphs, and voter buffers are statically bounded at compile time using Ada generics and bounded records.
* Maximum memory footprint is verified statically at link time ($< 16$ MB total BSS/Data segment).

### 5.2 Deterministic Execution (Synchronous Cyclic Executive)
* The kernel operates on a hard **50 ms minor cycle** (20 Hz) managed via POSIX monotonic clock bindings (`clock_gettime(CLOCK_MONOTONIC)`).
* Major cycle is configured at 200 ms (4 minor cycles per major cycle).
* Worst-case execution time (WCET) per minor cycle is measured at $< 4.2$ ms on ARM64 and x86-64, providing a $> 90\%$ timing safety margin.
* No asynchronous threads or preemptive interrupts exist inside the vital kernel core.

### 5.3 Strong Typing and Range Proofs
* Physical quantities are declared as distinct Ada scalar types:
  * `Speed_Mps`: range `0.0 .. 150.0`
  * `Distance_M`: range `0.0 .. 500_000.0`
  * `Millivolt`: range `0 .. 24_000`
  * `Milliampere`: range `0 .. 5_000`
* Incompatible dimensional assignments (e.g. assigning a distance to a speed) result in static compilation errors.
* Dynamic range overflow checks (`-gnato`, `-gnata`) are active in verification builds.

---

## 6. Independent Safety Barrier Invariants

In accordance with EN 50129 defense-in-depth principles, the vital output of the 2oo3 voter passes through an independent **Safety Barrier Invariant Monitor** before actuating field relays:

1. **Mutual Route Exclusion**: No two active routes whose topological footprints intersect can both be in `Route_Cleared`.
2. **Detector Locking**: No switch whose point track circuit is in `State_Occupied` or `State_Disturbed` can have `Position = Switch_In_Transit` or `Stroke_Timer_Ms > 0`.
3. **Flank Barrier**: For every cleared route, all protective flank switches must report verified microswitch detection in their designated diverting position.
4. **Signal Lamp Proving**: A signal cannot display `Aspect_Clear` or `Aspect_Caution` unless its route is strictly in `Route_Cleared` and all destination track blocks report `State_Clear`.
5. **Overrun Overlap Protection**: Overlap track sections must maintain unbroken reservation until the train achieves full standstill plus a 30-second thermal dissipation delay.

If any invariant evaluation evaluates to False, the executive executes an immediate atomic transition to **Fail-Safe Mode**:
* All route reservations are revoked.
* All signals are clamped to `Aspect_Stop`.
* All RBC Movement Authorities are truncated to zero meters.
