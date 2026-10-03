--  SPDX-FileCopyrightText: 2026 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: MIT
----------------------------------------------------------------

with SDPCM.Generic_SPI;
with Pico;
with RP.Device;
with RP.GPIO;
with Picowi.Generic_PIO_SPI;
with Ada.Interrupts.Names;

package Picowi.PIO_SPI is
  --pragma Preelaborate;

   procedure Configure_GPIO (Power_On : Boolean);
   procedure Power_On;
   procedure Configure_PIO;  --  After Power_On and a delay

   procedure Chip_Select (On : Boolean);
   procedure Read (Data : out SDPCM.Buffer_Byte_Array);
   procedure Write (Data : SDPCM.Buffer_Byte_Array);

   package gSPI is new SDPCM.Generic_SPI
     (Chip_Select => Chip_Select,
      Read        => Read,
      Write       => Write);
private

   GP29 : RP.GPIO.GPIO_Point := (Pin => 29);

   package SPI is new Picowi.Generic_PIO_SPI
     (WL_ON  => Pico.GP23,
      WL_D   => Pico.GP24,
      WL_CS  => Pico.GP25,
      WL_CLK => GP29,
      P      => RP.Device.PIO_0,
      SM     => 0);
  
   

end Picowi.PIO_SPI;
