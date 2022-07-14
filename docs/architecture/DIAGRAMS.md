# Aspect Architectural and Process Diagrams

This document contains Mermaid diagrams illustrating the core control flows, state machines, topological schematics, and voting architectures of the Aspect Railway Vital Interlocking and ETCS Level 2 Kernel.

---

## 1. Route Reservation Lifecycle State Machine

This state machine visualizes the complete lifecycle of a railway route from initial dispatcher request through turnout proving, flank lock verification, train passage, and sectional release.

```mermaid
stateDiagram-v2
    [*] --> Route_Idle
    Route_Idle --> Route_Requested : Cmd_Set_Route received
    
    state Route_Requested {
        [*] --> Check_Conflicts
        Check_Conflicts --> Align_Turnouts : No Conflicting Route Active
        Align_Turnouts --> Prove_Microswitches : Switch Machines Thrown
        Prove_Microswitches --> [*] : Blade Gap < 3.5mm Verified
    }
    
    Route_Requested --> Route_Idle : Conflict Detected / Rejection
    Route_Requested --> Route_Interlocked : All Required Points Detected
    
    state Route_Interlocked {
        [*] --> Lock_Flank_Turnouts
        Lock_Flank_Turnouts --> Clamp_Opposing_Shunts
        Clamp_Opposing_Shunts --> Reserve_Overlap
        Reserve_Overlap --> Verify_Track_Clear
        Verify_Track_Clear --> [*]
    }
    
    Route_Interlocked --> Route_Cleared : Flanks Held & Overlap Locked
    
    state Route_Cleared {
        [*] --> Signal_Clear_Aspect
        Signal_Clear_Aspect --> Issue_ETCS_MA
        Issue_ETCS_MA --> [*]
    }
    
    Route_Cleared --> Route_Occupied : First Track Section Shunted
    Route_Cleared --> Route_Idle : Cancel (Approach Free)
    Route_Cleared --> Route_Requested : Cancel (Approach Occupied: 120s Run Timer)
    
    state Route_Occupied {
        [*] --> Drop_Origin_Signal_To_Stop
        Drop_Origin_Signal_To_Stop --> Step_Sectional_Release
        Step_Sectional_Release --> Await_Overlap_Clear
        Await_Overlap_Clear --> Proving_Standstill
        Proving_Standstill --> [*] : 30s Overlap Timer Expired
    }
    
    Route_Occupied --> Route_Released : Train Fully Clears Route & Overlap
    Route_Released --> Route_Idle : Route Reset to Idle Baseline
```

---

## 2. 2oo3 Triple Modular Redundancy (TMR) Voter Pipeline

This flowchart illustrates how independent channel outputs are compared, how Byzantine bit-flip faults are masked, and how degraded modes are triggered.

```mermaid
flowchart TD
    subgraph Channels["Independent Triplicated Channels"]
        CA["Channel A<br/>(Interlocking Core)"]
        CB["Channel B<br/>(Interlocking Core)"]
        CC["Channel C<br/>(Interlocking Core)"]
    end

    subgraph Voter["2oo3 Majority Voter"]
        VComp{"Compare Outputs<br/>Val_A, Val_B, Val_C"}
        VUnan["Verdict: Unanimous (3oo3)<br/>Apply Consensus Output"]
        VMajA["Verdict: Majority (2oo3)<br/>Mask Faulty Channel A"]
        VMajB["Verdict: Majority (2oo3)<br/>Mask Faulty Channel B"]
        VMajC["Verdict: Majority (2oo3)<br/>Mask Faulty Channel C"]
        VFail["Verdict: Tripped Fail-Safe<br/>De-energize All Outputs"]
    end

    subgraph FDIR["Fault Detection and Recovery"]
        FTrack["Increment Divergence Counter"]
        FCheck{"Consecutive Divergences >= 3?"}
        FIsolate["Permanently Isolate Channel<br/>Transition to Mode_Degraded_2oo2"]
        FNom["Maintain Nominal Mode"]
    end

    subgraph InvariantFilter["Independent Safety Invariant Monitor"]
        Inv1{"Mutual Route Exclusion OK?"}
        Inv2{"Detector Locking OK?"}
        Inv3{"Flank Integrity OK?"}
        Inv4{"Signal Proving OK?"}
        InvSafe["Actuate Field Hardware Relays"]
        InvTrip["Trip System to Fail-Safe Emergency Stop"]
    end

    CA --> VComp
    CB --> VComp
    CC --> VComp

    VComp -->|All Equal| VUnan
    VComp -->|A /= B and B == C| VMajA
    VComp -->|B /= A and A == C| VMajB
    VComp -->|C /= A and A == B| VMajC
    VComp -->|Total Disagreement| VFail

    VMajA --> FTrack
    VMajB --> FTrack
    VMajC --> FTrack
    FTrack --> FCheck
    FCheck -->|Yes| FIsolate
    FCheck -->|No| FNom

    VUnan --> Inv1
    VMajA --> Inv1
    VMajB --> Inv1
    VMajC --> Inv1
    VFail --> InvTrip

    Inv1 -->|Passed| Inv2
    Inv1 -->|Violated| InvTrip
    Inv2 -->|Passed| Inv3
    Inv2 -->|Violated| InvTrip
    Inv3 -->|Passed| Inv4
    Inv3 -->|Violated| InvTrip
    Inv4 -->|Passed| InvSafe
    Inv4 -->|Violated| InvTrip
```

---

## 3. FDIR Operational Mode Transition State Diagram

```mermaid
stateDiagram-v2
    [*] --> Mode_Triplicated_3oo3
    
    Mode_Triplicated_3oo3 --> Mode_Triplicated_3oo3 : Single transient divergence (counter < 3)
    Mode_Triplicated_3oo3 --> Mode_Degraded_2oo2 : 3 consecutive divergences on one channel
    Mode_Triplicated_3oo3 --> Mode_Tripped_Fail_Safe : Unrecoverable Byzantine divergence
    
    Mode_Degraded_2oo2 --> Mode_Degraded_2oo2 : Unanimous agreement between 2 healthy channels
    Mode_Degraded_2oo2 --> Mode_Tripped_Fail_Safe : Disagreement between remaining 2 channels
    
    Mode_Tripped_Fail_Safe --> [*] : Requires manual physical maintenance reset
```

---

## 4. ETCS Level 2 Closed-Loop Supervision Sequence

This sequence diagram depicts the interaction between the Simulated Train (EVC), the Radio Block Centre (RBC), and the Computer-Based Interlocking (CBI) during active train control.

```mermaid
sequenceDiagram
    autonumber
    participant Train as Train Onboard (EVC)
    participant Balise as Eurobalise Transponder
    participant RBC as Radio Block Centre
    participant CBI as Computer-Based Interlocking
    participant Field as Track & Points

    Train->>Balise: Passes Fixed Balise Group
    Balise-->>Train: 1023-bit Telegram (Exact Chainage Calibrated)
    
    Train->>RBC: Euroradio Position Report (PR) [Chainage, Speed, Section]
    CBI->>Field: Field Sensor Scan (Track Circuits, Microswitches)
    Field-->>CBI: Section 1 Occupied, Section 2 Clear, Switch 1 Normal
    
    CBI->>RBC: Route Status Update (Route 1 Cleared to Signal 3)
    RBC->>RBC: Synthesize Dynamic Movement Authority (MA)
    RBC-->>Train: Packet 12 (MA) + Packet 21 (Gradients) + Packet 27 (Speed Profiles)
    
    Note over Train: EVC computes Subset-026 Braking Curves:<br/>V_Ind <= V_Perm <= V_Warn <= V_SBI <= V_EBI
    
    loop Every 50ms Minor Cycle
        Train->>Train: Evaluate Instantaneous Supervision State
        alt Speed < V_Permitted - 10 km/h
            Train->>Train: Driver Command: Accelerate / Cruise
        else Speed in [V_Permitted, V_Warning]
            Train->>Train: DMI Warning: Overspeed Acoustic Alert
        else Speed in [V_Warning, V_SBI]
            Train->>Train: Automated Service Brake Intervention (SBI)
        else Speed >= V_EBI
            Train->>Train: Automated Emergency Brake Trip (EBI)
        end
    end
    
    Train->>Field: Wheel Axles Shunt Next Track Circuit
    Field-->>CBI: Track Section State Transition
    CBI->>Field: Drop Origin Signal to Stop Behind Train
```

---

## 5. ETCS Braking Curve Hierarchy and Supervision Envelopes

```mermaid
flowchart LR
    Target["Target Restriction Point<br/>(EoA or SvL)"]
    
    subgraph Envelopes["Speed Supervision Envelopes"]
        EBI["EBI: Emergency Brake Intervention<br/>Anchored at SvL, a = 1.20 m/s2<br/>Lag = 1.8s"]
        SBI["SBI: Service Brake Intervention<br/>Anchored at EoA, a = 0.85 m/s2<br/>Lag = 2.5s"]
        Warn["Warning Curve (W)<br/>Acoustic Alert Window<br/>Time = 3.0s"]
        Perm["Permitted Speed (P)<br/>Driver Maximum Cruising Speed<br/>Floored at Release Speed (25 km/h)"]
        Ind["Indication Curve (I)<br/>DMI Visual Braking Cue<br/>Driver Reaction Time = 4.0s"]
    end
    
    Ind -->|"<="| Perm
    Perm -->|"<="| Warn
    Warn -->|"<="| SBI
    SBI -->|"<="| EBI
    EBI --> Target
```

---

## 6. Grand Central Junction Track Topology Schematic

This network graph visualizes the physical track configuration of the Grand Central Junction reference scenario (`scenarios/junction.json`).

```mermaid
graph LR
    subgraph UpMainline["Up Mainline (West to East)"]
        Sec1["Section 1<br/>(Up Approach)"] --- Sig1["Signal 1<br/>(Main Home)"]
        Sig1 --- Sec2["Section 2<br/>(Main Platform)"]
        Sec2 --- Sw1{"Switch 1<br/>(Main/Branch)"}
        Sw1 -->|"Normal (Straight)"| Sec3["Section 3<br/>(Express Main)"]
        Sec3 --- Sig2["Signal 2<br/>(Main Advance)"]
        Sig2 --- Sec4["Section 4<br/>(Main Exit Block)"]
    end

    subgraph BranchDivergence["Branch Siding and Flank Protection"]
        Sw1 -->|"Reverse (Diverging)"| Sec5["Section 5<br/>(Branch Lead)"]
        Sec5 --- Sw2{"Switch 2<br/>(Flank Trap)"}
        Sw2 -->|"Normal (Diverting)"| Sec6["Section 6<br/>(Sand Trap / Siding)"]
        Sw2 -.->|"Reverse (Fouling Path)"| Sec3
        Sec6 --- Sig4["Signal 4<br/>(Shunt Ground)"]
    end

    subgraph OverrunBuffer["Safety Overlaps"]
        Sec4 --- Ov1["Overlap 1<br/>(200m Buffer)"]
        Sec6 --- Ov2["Overlap 2<br/>(150m Buffer)"]
    end

    classDef track fill:#1e293b,stroke:#475569,stroke-width:2px,color:#f8fafc;
    classDef signal fill:#0f172a,stroke:#38bdf8,stroke-width:2px,color:#38bdf8;
    classDef switch fill:#334155,stroke:#f59e0b,stroke-width:2px,color:#f59e0b;
    classDef overlap fill:#14532d,stroke:#22c55e,stroke-width:2px,color:#86efac;

    class Sec1,Sec2,Sec3,Sec4,Sec5,Sec6 track;
    class Sig1,Sig2,Sig4 signal;
    class Sw1,Sw2 switch;
    class Ov1,Ov2 overlap;
```

---

## 7. Hard 50ms Minor Cycle Executive Pipeline

```mermaid
flowchart TD
    T0["t = 0 ms: Cycle Tick Start (POSIX CLOCK_MONOTONIC)"] --> S1
    
    subgraph Step1["Phase 1: Input Sampling (0.0 - 0.8 ms)"]
        S1["Sample Field Hardware Sensors:<br/>- Track Circuit Voltages<br/>- Axle Counter Pulse Counters<br/>- Point Microswitch Contacts<br/>- Read Non-Blocking Euroradio Socket"]
    end

    subgraph Step2["Phase 2: Triplicated Execution (0.8 - 2.3 ms)"]
        S2["Execute Channel Logic Concurrently:<br/>- Channel A CBI Step<br/>- Channel B CBI Step<br/>- Channel C CBI Step<br/>- Advance Route & Approach Timers"]
    end

    subgraph Step3["Phase 3: Majority Voting & FDIR (2.3 - 3.1 ms)"]
        S3["2oo3 Voter Evaluation:<br/>- Boolean & Aspect Relational Voting<br/>- Detect Single-Event Bit-Flips<br/>- Update Consecutive Divergence Counts<br/>- Trigger Channel Isolation if Divergences >= 3"]
    end

    subgraph Step4["Phase 4: Safety Barrier Audit (3.1 - 3.7 ms)"]
        S4["Formal Invariant Barrier:<br/>- Check Route Exclusions<br/>- Check Detector Point Locks<br/>- Check Flank Diverter Locks<br/>- If Violation: Force Atomic Fail-Safe Clamp"]
    end

    subgraph Step5["Phase 5: Output & Telemetry (3.7 - 4.5 ms)"]
        S5["Actuation & Telemetry Streaming:<br/>- Latch Field Relays<br/>- Stream Zero-Heap JSON Telemetry Snapshot<br/>- Service Dispatcher Command Queue"]
    end

    subgraph Step6["Phase 6: High-Resolution Sleep (4.5 - 50.0 ms)"]
        S6["POSIX nanosleep until Next 50ms Epoch<br/>(Pacing Jitter < 2ms)"]
    end

    Step1 --> Step2
    Step2 --> Step3
    Step3 --> Step4
    Step4 --> Step5
    Step5 --> Step6
    Step6 --> T50["t = 50 ms: Next Minor Cycle"]
```
