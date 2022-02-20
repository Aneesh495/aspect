-- Root package specification for Aspect.
-- Aspect is a high-assurance railway Computer-Based Interlocking (CBI) kernel,
-- EN 50128 SIL 4 vital logic engine, and ETCS Level 2 train control processor.

package Aspect with
   Pure
is

   System_Name    : constant String := "Aspect";
   System_Version : constant String := "1.0.0";
   Assurance_SIL  : constant Natural := 4;

   -- Standard cycle durations for vital execution (in milliseconds)
   Minor_Cycle_Ms : constant Positive := 50;
   Major_Cycle_Ms : constant Positive := 200;

   -- Maximum structural constants for bounded deterministic allocation
   Max_Track_Sections   : constant Positive := 512;
   Max_Turnout_Switches : constant Positive := 128;
   Max_Signals          : constant Positive := 256;
   Max_Balises          : constant Positive := 1024;
   Max_Active_Routes    : constant Positive := 128;
   Max_Supervised_Trains: constant Positive := 64;

end Aspect;
