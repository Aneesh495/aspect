-- Eurobalise transmission points conforming to ETCS Subset-036 / Subset-026.
-- Supports fixed balises (geographical linking and gradient profiles)
-- and controllable transparent balises driven by Lineside Electronic Units (LEU).

with Interfaces; use Interfaces;
with Aspect.Types; use Aspect.Types;
with Aspect.Topology; use Aspect.Topology;
with Aspect.CRC; use Aspect.CRC;

package Aspect.Topology.Balises is

   -- ETCS standard telegram length in bytes (1023 bits serialized in 128 bytes)
   Standard_Telegram_Bytes : constant Positive := 128;

   type Balise_Telegram_Data is array (1 .. Standard_Telegram_Bytes) of Interfaces.Unsigned_8;

   type Balise_Kind is (
      Balise_Fixed,         -- Factory-programmed static track and linking data
      Balise_Controllable   -- Dynamic data updated by LEU based on signal aspect
   );

   type Eurobalise is record
      Id                  : Balise_Id_Base       := Null_Balise_Id;
      Group_Id            : Natural              := 0;
      Position_In_Group   : Positive range 1 .. 8 := 1;
      Total_In_Group      : Positive range 1 .. 8 := 1;
      Kind                : Balise_Kind          := Balise_Fixed;

      -- Topological Placement
      Track_Section       : Section_Id_Base      := Null_Section_Id;
      Chainage            : Track_Chainage       := 0.0;
      Direction_Valid     : Direction_Type       := Dir_Nominal;

      -- Telegram Payloads
      Telegram_Payload    : Balise_Telegram_Data := [others => 0];
      Telegram_Bit_Length : Positive             := 832;
      Telegram_CRC        : CRC10_Type           := 0;
      Is_Transmitting     : Boolean              := True;
   end record;

   type Eurobalise_Array is array (Balise_Id) of Eurobalise;

   procedure Initialize_Balise
     (Balise       : out Eurobalise;
      Id           : Balise_Id;
      Group_Id     : Natural;
      Pos_In_Group : Positive;
      Total_In_Grp : Positive;
      Kind         : Balise_Kind;
      Section      : Section_Id;
      Chainage     : Track_Chainage;
      Direction    : Direction_Type := Dir_Nominal);

   -- Loads telegram payload into balise buffer and computes vital CRC-10
   procedure Load_Telegram
     (Balise     : in out Eurobalise;
      Payload    : Balise_Telegram_Data;
      Bit_Length : Positive := 832);

   -- LEU dynamic update: called by CBI to inject dynamic Movement Authority packets
   procedure Update_LEU_Telegram
     (Balise     : in out Eurobalise;
      New_Payload: Balise_Telegram_Data;
      Bit_Length : Positive := 832);

   -- Interrogates balise on train antenna passage
   procedure Interrogate_Balise
     (Balise     : Eurobalise;
      Payload    : out Balise_Telegram_Data;
      CRC_OK     : out Boolean);

end Aspect.Topology.Balises;
