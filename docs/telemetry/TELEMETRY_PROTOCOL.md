# Aspect Real-Time Telemetry Protocol and Command Specification

This document defines the schema, encoding rules, and network transport mechanisms used by the Aspect telemetry subsystem to stream real-time operational snapshots and accept remote dispatcher commands without allocating heap memory.

---

## 1. Zero-Heap Allocation Architecture

In compliance with CENELEC EN 50128 SIL 4 guidelines forbidding dynamic heap allocation in safety kernels:
* The telemetry engine constructs all JSON payloads in place within a pre-allocated static buffer:
  ```ada
  type Large_String_Buffer is record
     Data   : String (1 .. 16_384);
     Length : Natural := 0;
  end record;
  ```
* Serialization functions (`Append_String`, `Append_Int`, `Append_Float`, `Append_Bool`) perform deterministic index updates with runtime bounds checks.
* The kernel streams serialized bytes directly to the non-blocking POSIX socket descriptor via ANSI C `write(2)` without intermediate string allocations.

---

## 2. Telemetry Snapshot Payload Schema

The kernel outputs a line-delimited JSON object (`\n`) on every minor cycle epoch (or throttled interval, default 100 ms):

```json
{
  "seq": 1420,
  "sim_time_ms": 71000,
  "mode": "Mode_Triplicated_3oo3",
  "trains": [
    {
      "id": 1,
      "chainage_m": 1250.4,
      "speed_kph": 118.5,
      "section": 2,
      "v_target": 0.0,
      "v_perm": 130.8,
      "v_warn": 134.4,
      "v_sbi": 143.6,
      "v_ebi": 175.4,
      "status": "Normal"
    }
  ],
  "sections": [
    {"id": 1, "occupied": false, "locked": true},
    {"id": 2, "occupied": true, "locked": true},
    {"id": 3, "occupied": false, "locked": true},
    {"id": 4, "occupied": false, "locked": false}
  ],
  "switches": [
    {"id": 1, "position": "Normal", "target": "Normal", "locked": true},
    {"id": 2, "position": "Normal", "target": "Normal", "locked": true}
  ],
  "signals": [
    {"id": 1, "aspect": "Clear", "section": 1},
    {"id": 2, "aspect": "Caution", "section": 3},
    {"id": 4, "aspect": "Stop", "section": 6}
  ],
  "routes": [
    {"id": 1, "state": "Route_Cleared"}
  ],
  "voter": {
    "total_cycles": 1420,
    "divergences": 0,
    "chan_a": {"div": 0, "isolated": false},
    "chan_b": {"div": 0, "isolated": false},
    "chan_c": {"div": 0, "isolated": false}
  }
}
```

### 2.1 Schema Field Definitions

| JSON Path | Type | Units / Enum | Description |
|:---|:---|:---:|:---|
| `seq` | Integer | - | Monotonically increasing 64-bit frame counter |
| `sim_time_ms` | Integer | ms | Elapsed simulation time since system boot |
| `mode` | String | Enum | Operational mode (`Mode_Triplicated_3oo3`, `Mode_Degraded_2oo2`, `Mode_Tripped_Fail_Safe`) |
| `trains[].chainage_m` | Float | m | Absolute linear track distance from datum |
| `trains[].speed_kph` | Float | km/h | Instantaneous true wheel velocity |
| `trains[].v_perm` | Float | km/h | ETCS Permitted driver speed ceiling |
| `trains[].v_warn` | Float | km/h | ETCS Overspeed Warning threshold |
| `trains[].v_sbi` | Float | km/h | Automated Service Brake Intervention speed |
| `trains[].v_ebi` | Float | km/h | Emergency Brake Intervention trip speed |
| `trains[].status` | String | Enum | Supervision state (`Normal`, `Indication`, `Warning`, `Intervention`, `Trip`) |
| `sections[].occupied` | Boolean | - | True if track circuit shunted or axle counter unbalanced |
| `sections[].locked` | Boolean | - | True if section reserved by an active route |
| `switches[].position` | String | Enum | Proved physical position (`Normal`, `Reverse`, `In_Transit`) |
| `signals[].aspect` | String | Enum | Optical aspect displayed (`Stop`, `Caution`, `Preliminary_Caution`, `Clear`) |
| `routes[].state` | String | Enum | Route lifecycle state (`Route_Idle`, `Route_Requested`, `Route_Interlocked`, `Route_Cleared`, `Route_Occupied`, `Route_Released`) |
| `voter.divergences` | Integer | - | Cumulative Byzantine divergence events across all channels |

---

## 3. Remote Dispatcher Command Grammar

Remote clients (such as the web dispatcher cockpit or test harnesses) send ASCII command lines terminated by `\n` to the server socket.

### 3.1 Command Syntax Specification

```
Command ::= SetRoute | CancelRoute | ThrowSwitch | EmergencyStop | AckAlarm

SetRoute      ::= "SET_ROUTE" SP RouteId
CancelRoute   ::= "CANCEL_ROUTE" SP RouteId
ThrowSwitch   ::= "THROW_SWITCH" SP SwitchId SP Position
EmergencyStop ::= "EMERGENCY_STOP"
AckAlarm      ::= "ACK_ALARM"

RouteId       ::= [1-9][0-9]*
SwitchId      ::= [1-9][0-9]*
Position      ::= "NORMAL" | "REVERSE"
SP            ::= " "
```

### 3.2 Command Semantics and Safety Checks

1. **`SET_ROUTE <route_id>`**:
   * Initiates route reservation.
   * Interlocking validates that no conflicting routes are active, aligns switches, checks flank protections, and reserves the overrun overlap.
   * If any precondition fails, the command is rejected with an operational error code.

2. **`CANCEL_ROUTE <route_id>`**:
   * Requests route release.
   * If the approach track is unoccupied, release is instantaneous.
   * If a train is in the sighting envelope, the origin signal drops to `Stop` and the 120-second approach locking timer is engaged.

3. **`THROW_SWITCH <switch_id> <NORMAL|REVERSE>`**:
   * Requests manual point movement.
   * Rejected if the point zone track circuit is shunted (`State_Occupied`), if the switch is mechanically locked by a route, or if already in the target position.

4. **`EMERGENCY_STOP`**:
   * Trips all signals immediately to `Aspect_Stop`.
   * Truncates all active RBC Movement Authorities to zero meters.
   * Latches emergency stop state until manually acknowledged.

5. **`ACK_ALARM`**:
   * Resets the latch after an emergency stop once track hazards are cleared.

---

## 4. Network Transport Topology

```
+------------------------------+
|   Aspect Core Process        |
|   (POSIX Non-Blocking TCP)   |
+------------------------------+
               |
               | TCP Socket: 127.0.0.1:8088
               | Line-delimited JSON stream
               v
+------------------------------+
|   Python Visualizer Bridge   |
|   (RFC 6455 WebSocket & HTTP)|
+------------------------------+
        |              |
        | Port 8080    | Port 8080
        | WebSocket    | HTTP Static (HTML/CSS/JS)
        v              v
+------------------------------+
|   HTML5 Web Dispatcher UI    |
|   (Browser / SVG Canvas)     |
+------------------------------+
```

1. **Aspect TCP Server (Port 8088)**:
   * Uses non-blocking POSIX sockets (`O_NONBLOCK`).
   * Guarantees zero blocking during kernel execution. If a client buffer is full, telemetry frames are dropped rather than delaying the 50ms minor cycle.

2. **Python Gateway Bridge (`scripts/visualizer_server.py`)**:
   * Standard library async server requiring zero third-party dependencies (`pip`).
   * Implements RFC 6455 WebSocket framing, SHA-1 handshake hashing, and HTTP file serving on port 8080.
   * Bi-directionally multiplexes browser UI commands into the Aspect TCP stream.

3. **HTML5 Dispatcher Cockpit (`web/`)**:
   * Interactive dark-mode user interface.
   * Reactive SVG layout updating point blade positions and lamp colors.
   * Circular ETCS Driver Machine Interface (DMI) speedometer gauge rendering instantaneous speed against $V_{Permitted}$, $V_{Warning}$, and $V_{EBI}$ arcs.
