# Aspect Computer-Based Interlocking: Principles and Geographic Safety Rules

This document details the functional specifications, state machines, and mathematical safety principles implemented in the Aspect Computer-Based Interlocking (CBI) kernel. The rules strictly implement standard railway signalling engineering principles complying with British Rail (GK/RT), UIC 790, and CENELEC EN 50128/EN 50129 standards.

---

## 1. The Fundamental Interlocking Problem

A railway interlocking is a safety-critical real-time controller whose fundamental purpose is to guarantee that train movements over junctions and converging track configurations are mutually exclusive. Unlike road vehicles, heavy freight and high-speed trains cannot steer around obstacles or stop within their driver line of sight. Safety depends entirely upon the interlocking:
1. **Never clearing a signal** unless the complete path to the destination is physically locked, verified in alignment, and free of conflicting trains.
2. **Never allowing a switch to move** while a train is moving across or approaching its point blades.
3. **Guarding against unauthorized movements** from side tracks via defensive flank diversions.

---

## 2. Route Reservation Lifecycle State Machine

Each route within the interlocking manages a formal state machine governing its progression from dispatcher request to train passage and subsequent release:

```
                  +--------------------------------+
                  |           Route_Idle           |<-----------------------------+
                  +--------------------------------+                              |
                                  |                                               |
                    Dispatcher Cmd: Set_Route                                     |
                                  v                                               |
                  +--------------------------------+                              |
                  |        Route_Requested         |                              |
                  +--------------------------------+                              |
                                  |                                               |
                    All Turnout Points Thrown &                                   |
                    Microswitches Proved Detected                                 |
                                  v                                               |
                  +--------------------------------+                              |
                  |       Route_Interlocked        |                              |
                  +--------------------------------+                              |
                                  |                                               |
                    Flank Defenses Locked,                                        |
                    Overlap Reserved, Track Blocks Clear                          |
                                  v                                               |
                  +--------------------------------+                              |
                  |         Route_Cleared          |                              |
                  |    (Signal Displays Clear)     |                              |
                  +--------------------------------+                              |
                                  |                                               |
                    First Track Circuit Shunted                                   |
                    by Train Front Axles                                          |
                                  v                                               |
                  +--------------------------------+                              |
                  |         Route_Occupied         |                              |
                  |    (Signal Drops to Stop)      |                              |
                  +--------------------------------+                              |
                                  |                                               |
                    Sectional Release Sequence:                                   |
                    Last Section Cleared +                                        |
                    Overlap Standstill Proved (30s)                               |
                                  |                                               |
                                  +-----------------------------------------------+
```

### Detailed State Transitions:
1. **Route_Idle**: Route is unreserved. Turnouts along the path are available for manual movement or allocation to other routes.
2. **Route_Requested**: Dispatcher has called the route. The interlocking verifies that no conflicting routes are active, sets electrical calls for all required switch point machines, and monitors blade transit timers.
3. **Route_Interlocked**: All points have completed transit, detection microswitches verify blade gap $< 3.5\text{ mm}$, and mechanical lock relays are energized.
4. **Route_Cleared**: Flank protections are verified, overrun safety overlap is reserved, and all track sections are proved in `State_Clear`. The origin signal clears to `Aspect_Clear` (Green) or `Aspect_Caution` (Yellow), and the RBC transmits a Movement Authority frame.
5. **Route_Occupied**: Train shunts the first track circuit in the route. The origin signal automatically drops to `Aspect_Stop` (Red) behind the train to prevent following trains from entering the block.
6. **Route_Released**: As the train advances, rear track sections are released section by section (Sectional Route Release). Once the train clears the exit signal and the 30-second overlap timer expires, the route returns to `Route_Idle`.

---

## 3. Mutual Route Exclusion (Conflicting Route Matrix)

Two routes $R_A$ and $R_B$ are mutually conflicting ($R_A \parallel R_B$) if any of the following conditions hold:
1. **Shared Track Section**: $\text{Sections}(R_A) \cap \text{Sections}(R_B) \neq \emptyset$.
2. **Opposing Movements**: Both routes utilize the same physical track line but in opposite directions of travel.
3. **Switch Contention**: A shared turnout requires divergent positions:
   $$\exists S \in R_A \cap R_B : \text{Target\_Position}(R_A, S) \neq \text{Target\_Position}(R_B, S)$$
4. **Overlap Conflict**: The overrun overlap of $R_A$ intersects the path or overlap of $R_B$.

The Aspect interlocking computes an $N \times N$ symmetric boolean matrix during initialization. If route $R_A$ is in state `Route_Requested`, `Route_Interlocked`, `Route_Cleared`, or `Route_Occupied`, any attempt to reserve conflicting route $R_B$ is immediately rejected with error `Reject_Conflicting_Route_Active`.

---

## 4. Flank Protection Principles

Flank protection prevents unauthorized trains or runaway wagons on adjacent tracks from sideswiping a train traversing a cleared main route.

### 4.1 Defensive Turnout Alignment
When Route 1 is cleared along the mainline through Turnout 1:
* Turnout 2 on the adjacent siding is commanded to its **Normal (straight)** position, leading away from the mainline junction.
* Turnout 2 is mechanically locked in Normal, preventing any siding movement toward the fouling point.

### 4.2 Opposing Signal Clamping
* Shunt Signal 4 guarding the siding exit is clamped to `Aspect_Stop`.
* Any dispatcher command attempting to clear Signal 4 while Route 1 is active is rejected with `Reject_Flank_Protection_Violated`.

### 4.3 Flank Integrity Supervision
If the interlocking detects that a protective flank turnout loses microswitch detection or experiences track circuit shunting in its fouling section while Route 1 is cleared, the origin signal of Route 1 is instantly dropped to `Aspect_Stop`, and the RBC transmits an emergency stop order.

---

## 5. Overrun Safety Overlap and Standstill Release

In railway engineering, an **overlap** is a designated track length (typically 200 to 400 meters) beyond the destination signal that must be kept clear and reserved while the train is braking toward that signal.

### 5.1 Purpose of Overlap
If a train slightly overshoots its target braking curve and passes the destination signal at low speed ($< 25\text{ km/h}$), the overlap guarantees that it does not collide with a train crossing the subsequent junction.

### 5.2 Standstill Release Delay
Under UIC 790, an overlap cannot be released immediately when the train front reaches the signal:
* The train must be confirmed at complete standstill ($v = 0.0\text{ km/h}$) by onboard odometry and track circuit shunting.
* A thermal brake dissipation and roll-away timer ($30\text{ seconds} = 30,000\text{ ms}$) must expire before points inside the overlap zone can be thrown for another route.

---

## 6. Point Detector Locking and Switch Machine Proving

Switches (turnouts) represent the primary mechanical moving components of the permanent way. Aspect enforces four layers of vital point protection:

### 6.1 Point Zone Track Circuit Interlocking (Detector Locking)
Each turnout has a dedicated point zone track circuit (e.g. Section 1 for Switch 1). If the track circuit reports `State_Occupied` or `State_Disturbed`:
* The switch machine motor power is electrically isolated.
* Any manual or automated throw command is rejected with `Reject_Switch_Detector_Locked`.

### 6.2 Blade Gap Verification
Before a route can clear, microswitch detection contacts at the point tips must verify that:
* Closed blade gap: $< 3.5\text{ mm}$ against the stock rail.
* Open blade flangeway clearance: $> 100\text{ mm}$.
* Detection relays (`Normal_Detection_Relay` or `Reverse_Detection_Relay`) must remain continuously energized.

### 6.3 Stroke Timeout and Stall Protection
Standard electro-hydraulic switch machines require $2.5\text{ to }3.5\text{ seconds}$ to complete a full stroke.
* If a point machine does not achieve verified detection within **3500 ms**, the timer trips `Obstacle_Stall_Fault`.
* The point machine motor current is cut to prevent mechanical burnout, and the origin signal is locked to `Aspect_Stop`.

### 6.4 Trailing-Cut Detection
If an unauthorized train runs through a switch aligned in the wrong direction from the trailing end:
* Mechanical cut sensors detect point blade force overload.
* `Trailing_Cut_Detected` is flagged, causing immediate interlocking emergency stop.

---

## 7. Approach Locking and Driver Sighting

When a green signal is displayed to an oncoming train, the driver relies on that aspect to maintain cruising speed.

### 7.1 Sighting Envelope
If a dispatcher attempts to cancel a cleared route while an oncoming train is within the signal approach zone:
* The signal drops to `Aspect_Stop` immediately.
* **However, the turnouts and conflicting route locks CANNOT be released immediately**, because the train may be unable to stop before the signal mast.

### 7.2 Approach Run Timer (120 Seconds)
* The interlocking initiates a **120-second approach locking timer** (`Approach_Timer_Ms`).
* All switches remain immobilized until either:
  1. The 120-second timer expires (ensuring the train has either stopped or passed the signal).
  2. The track circuits confirm the train has achieved verified standstill.
