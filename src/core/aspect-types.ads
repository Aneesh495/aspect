-- Fundamental safety types, bounded identifiers, and physical units
-- for the Aspect high-assurance railway interlocking system.

with Interfaces;

package Aspect.Types with
   Pure
is

   ----------------------------------------------------------------------------
   -- Physical Units and Constrained Ranges
   ----------------------------------------------------------------------------

   type Millimeter is range -100_000_000 .. 100_000_000;
   type Meter is digits 9 range -100_000.0 .. 100_000.0;
   type Distance_M is digits 9 range 0.0 .. 100_000.0;

   type Speed_Kph is digits 7 range 0.0 .. 500.0;
   type Speed_Mps is digits 7 range 0.0 .. 140.0;

   type Acceleration_Mps2 is digits 6 range -15.0 .. 15.0;
   type Deceleration_Mps2 is digits 6 range 0.0 .. 15.0;

   -- Gradient in per mille (1 per mille = 1 millimeter per meter of rise/fall)
   type Gradient_Per_Mille is digits 6 range -100.0 .. 100.0;

   -- Friction coefficient between steel rail and wheel (dimensionless)
   type Adhesion_Factor is digits 6 range 0.01 .. 1.00;

   type Mass_Tonnes is digits 8 range 0.1 .. 10_000.0;
   type Percent is digits 6 range 0.0 .. 100.0;

   ----------------------------------------------------------------------------
   -- Time and Cyclic Executive Types
   ----------------------------------------------------------------------------

   type Time_Ms is range 0 .. 86_400_000; -- 24 hours in milliseconds
   type Tick_Count is new Interfaces.Unsigned_64;
   type Time_Stamp_Us is new Interfaces.Unsigned_64;

   ----------------------------------------------------------------------------
   -- Discrete Identifiers (1-based indices with 0 reserved as Null sentinel)
   ----------------------------------------------------------------------------

   type Section_Id_Base is range 0 .. Max_Track_Sections;
   subtype Section_Id is Section_Id_Base range 1 .. Section_Id_Base'Last;
   Null_Section_Id : constant Section_Id_Base := 0;

   type Switch_Id_Base is range 0 .. Max_Turnout_Switches;
   subtype Switch_Id is Switch_Id_Base range 1 .. Switch_Id_Base'Last;
   Null_Switch_Id : constant Switch_Id_Base := 0;

   type Signal_Id_Base is range 0 .. Max_Signals;
   subtype Signal_Id is Signal_Id_Base range 1 .. Signal_Id_Base'Last;
   Null_Signal_Id : constant Signal_Id_Base := 0;

   type Balise_Id_Base is range 0 .. Max_Balises;
   subtype Balise_Id is Balise_Id_Base range 1 .. Balise_Id_Base'Last;
   Null_Balise_Id : constant Balise_Id_Base := 0;

   type Route_Id_Base is range 0 .. Max_Active_Routes;
   subtype Route_Id is Route_Id_Base range 1 .. Route_Id_Base'Last;
   Null_Route_Id : constant Route_Id_Base := 0;

   type Train_Id_Base is range 0 .. Max_Supervised_Trains;
   subtype Train_Id is Train_Id_Base range 1 .. Train_Id_Base'Last;
   Null_Train_Id : constant Train_Id_Base := 0;

   ----------------------------------------------------------------------------
   -- Topological Orientations and Directions
   ----------------------------------------------------------------------------

   type Direction_Type is (Dir_Nominal, Dir_Reverse);
   type Running_Direction is (Up_Direction, Down_Direction, Both_Directions);

   ----------------------------------------------------------------------------
   -- Track Occupancy and Detection States
   ----------------------------------------------------------------------------

   type Occupancy_State is (
      State_Clear,       -- Section unoccupied, shunt relay energized
      State_Occupied,    -- Train wheels shunting track circuit or axle counter unbalanced
      State_Shunted,     -- Explicit maintenance shunt bar attached
      State_Disturbed    -- Electrical fault, broken rail, or power interruption
   );

   ----------------------------------------------------------------------------
   -- Turnout Switch Positions and Control Commands
   ----------------------------------------------------------------------------

   type Switch_Position is (
      Switch_Normal,          -- Points aligned and locked for through track
      Switch_Reverse,         -- Points aligned and locked for diverging turnout
      Switch_In_Transit,      -- Motor active, points between physical stock rails
      Switch_Lost_Detection   -- Microswitch detection circuit open or out of tolerance
   );

   type Switch_Command is (
      Command_None,
      Command_Throw_Normal,
      Command_Throw_Reverse,
      Command_Lock_Normal,
      Command_Lock_Reverse,
      Command_Unlock
   );

   type Point_Orientation is (
      Facing_Point,   -- Train approaches toe of switch (can divert to either leg)
      Trailing_Point  -- Train approaches heel of switch (merging into single track)
   );

   ----------------------------------------------------------------------------
   -- Railway Signal Aspects and Operational Categories
   ----------------------------------------------------------------------------

   type Signal_Aspect is (
      Aspect_Stop,                  -- Red: Absolute danger, do not pass
      Aspect_Caution,               -- Yellow: Next signal is at Stop
      Aspect_Preliminary_Caution,   -- Double Yellow: Next signal is at Caution
      Aspect_Clear,                 -- Green: Next two signals at Clear or Caution
      Aspect_Shunt,                 -- White / Lunar: Low speed shunting movement
      Aspect_Dark                   -- Lamp extinguished or hardware fail
   );

   type Signal_Category is (
      Category_Main,        -- Governs block entry and speed authority
      Category_Distant,     -- Advance warning for main signal ahead
      Category_Combined,    -- Main and distant integrated in single head
      Category_Shunt,       -- Low-speed yard and siding movements
      Category_Buffer_Stop  -- Fixed red or illuminated buffer end terminal
   );

   ----------------------------------------------------------------------------
   -- Interlocking Route State Machine
   ----------------------------------------------------------------------------

   type Route_State is (
      Route_Unset,             -- Idle, available for reservation
      Route_Requested,         -- Dispatcher commanded route; points moving
      Route_Interlocked,       -- Points locked, flank protection set, awaiting signal
      Route_Cleared,           -- Signal displaying proceed aspect
      Route_Approached,        -- Train occupied approach track circuit (timer active)
      Route_Occupied,          -- Train passed signal and entered first section
      Route_Sectional_Release, -- Sections releasing sequentially behind train
      Route_Released,          -- All sections cleared, route completed
      Route_Cancelled          -- Manually revoked under emergency conditions
   );

   type Route_Class is (
      Class_Main_Train,    -- Full passenger/freight mainline route
      Class_Shunt,         -- Low-speed yard route
      Class_Call_On,       -- Entry into occupied platform berth
      Class_Emergency      -- Forced route release or override
   );

   ----------------------------------------------------------------------------
   -- ETCS Level 2 and Braking Curve Attributes
   ----------------------------------------------------------------------------

   type ETCS_Level is (
      Level_0,   -- Unfitted line or ETCS not in use
      Level_1,   -- Eurobalise lineside signaling overlay with infill
      Level_2,   -- Radio Block Centre (RBC) continuous GSM-R / LTE-R supervision
      Level_3,   -- Moving block without lineside track circuits
      Level_STM  -- Specific Transmission Module (legacy national ATP system)
   );

   type ETCS_Mode is (
      Mode_FS,   -- Full Supervision (cab signaling with active brake curve supervision)
      Mode_OS,   -- On Sight (driver responsible for visual clearance)
      Mode_SR,   -- Staff Responsible (manual movement under train order)
      Mode_SH,   -- Shunting mode
      Mode_TR,   -- Trip (emergency brake applied due to EoA overrun)
      Mode_PT,   -- Post Trip
      Mode_SB,   -- Standby
      Mode_IS,   -- Isolation
      Mode_NL,   -- Non Leading
      Mode_SF    -- System Failure
   );

   type Braking_Curve_Type is (
      Curve_EBI, -- Emergency Brake Intervention
      Curve_EBD, -- Emergency Brake Deceleration
      Curve_SBI, -- Service Brake Intervention
      Curve_SBD, -- Service Brake Deceleration
      Curve_W,   -- Warning Curve
      Curve_P,   -- Permitted Speed Curve
      Curve_I    -- Indication Curve
   );

   ----------------------------------------------------------------------------
   -- Triple Modular Redundancy (2oo3) Voting Classifications
   ----------------------------------------------------------------------------

   type Channel_Id is (Channel_A, Channel_B, Channel_C);

   type Channel_Health is (
      Channel_Nominal,
      Channel_Diverged,
      Channel_Faulted,
      Channel_Isolated
   );

   type Voting_Verdict is (
      Verdict_Unanimous_3oo3,   -- All 3 channels agree identically
      Verdict_Majority_2oo3,    -- 2 channels agree; 1 channel diverged
      Verdict_Degraded_2oo2,    -- 1 channel already dead; remaining 2 agree
      Verdict_Tripped_Fail_Safe -- Tie or total divergence; system clamps to Stop
   );

   ----------------------------------------------------------------------------
   -- Physical Unit Conversion Routines
   ----------------------------------------------------------------------------

   function Kph_To_Mps (Speed : Speed_Kph) return Speed_Mps is
     (Speed_Mps (Float (Speed) / 3.6));

   function Mps_To_Kph (Speed : Speed_Mps) return Speed_Kph is
     (Speed_Kph (Float (Speed) * 3.6));

   function Millimeters_To_Meters (Mm : Millimeter) return Meter is
     (Meter (Float (Mm) / 1000.0));

   function Meters_To_Millimeters (M : Meter) return Millimeter is
     (Millimeter (Float (M) * 1000.0));

   function Clamp_Speed (S : Float; Max_Val : Float) return Speed_Kph is
     (if S < 0.0 then 0.0
      elsif S > Max_Val then Speed_Kph (Max_Val)
      else Speed_Kph (S));

end Aspect.Types;
