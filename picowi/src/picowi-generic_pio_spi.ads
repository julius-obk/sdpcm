--  SPDX-FileCopyrightText: 2026 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: MIT
----------------------------------------------------------------

with HAL;

with RP.GPIO;
with RP.PIO;
with RP.DMA;
with Ada.Interrupts;
with Ada.Interrupts.Names;
with RP.Device;
with RP2040_SVD.Pio;
with System;
with Ada.Synchronous_Task_Control;

generic
   WL_CLK : in out RP.GPIO.GPIO_Point;
   WL_D   : in out RP.GPIO.GPIO_Point;
   WL_CS  : in out RP.GPIO.GPIO_Point;
   WL_ON  : in out RP.GPIO.GPIO_Point;

   P  : in out RP.PIO.PIO_Device;
   SM : RP.PIO.PIO_SM;
   DMA_Chan : RP.DMA.DMA_Channel_Id := RP.DMA.DMA_Channel_Id'Last;
   DMA_IRQ : RP.DMA.DMA_IRQ_Id := RP.DMA.DMA_IRQ_Id'Last;
   Event_Pending_Callback : Event_Callback_Access_Type := null;
   use_core1_for_Interrupt : Boolean := True;
package Picowi.Generic_PIO_SPI is

   procedure Configure_GPIO;
   --  Configure GPIO pins and power OFF the WLAN chip

   procedure Power_On;
   --  You can Power On only after a delay since Power_Off/Configure_GPIO.

   procedure Configure_PIO;
   --  You can configure PIO only after a few milliseconds since Power_On
   -- procedure Configure_PIO_DMA;
   --  You can configure PIO only after a few milliseconds since Power_On

   type Status_Type is (Reading, Writing, Idle);
   
  
   
   

   procedure Chip_Select (On : Boolean);
   procedure Write_SPI (Data : HAL.UInt8_Array);
   procedure Write_SPI_DMA (Data :  HAL.UInt8_Array) with Pre => Status.Get_Status = Idle;
   procedure Read_SPI (Data : out HAL.UInt8_Array);
   procedure Read_SPI_DMA (Data : out HAL.UInt8_Array) with Pre => Status.Get_Status = Idle;

   
function Check_Pending_Event return Boolean is (WL_D.Get) with Pre => Status.Get_Status = Idle;

use Ada.Interrupts.Names;
use type RP.DMA.DMA_Channel_Id;
   DMA_Interrupt_ID : constant Ada.Interrupts.Interrupt_ID := (
                                                  if DMA_IRQ = 0 and use_core1_for_Interrupt then DMA_IRQ_0_Interrupt_CPU_1
                                                  elsif DMA_IRQ = 0 and not use_core1_for_Interrupt then DMA_IRQ_0_Interrupt_CPU_2 
                                                  elsif DMA_IRQ = 1 and use_core1_for_Interrupt then DMA_IRQ_1_Interrupt_CPU_1
                                                  else  DMA_IRQ_1_Interrupt_CPU_2);
protected Status is
pragma Keep(status);
pragma Interrupt_Priority(System.Interrupt_Priority'First);
   function Get_Status return Status_Type;
   procedure Set_Status (This : Status_Type);
   procedure DMA_Callback_Handler  with Attach_Handler => DMA_Interrupt_ID;
   pragma Unreferenced(DMA_Callback_Handler);
private
   SPI_Status : Status_Type := Idle;
end Status;

 

private
   use RP.Pio;
   use RP.DMA;
   use RP2040_SVD.Pio;
   
   type txrx_type is (tx,rx);
   trigger_lookup : constant array (PIO_Number range PIO_Number'range,
                                    PIO_SM range PIO_SM'range,
                                    txrx_type range txrx_type'range) of DMA_Request_Trigger :=
      ( 0 => ( 0 => (tx => PIO0_TX0, rx => PIO0_RX0),
               1 => (tx => PIO0_TX1, rx => PIO0_RX1),
               2 => (tx => PIO0_TX2, rx => PIO0_RX2),
               3 => (tx => PIO0_TX3, rx => PIO0_RX3)),
        1 => ( 0 => (tx => PIO1_TX0, rx => PIO1_RX0),
               1 => (tx => PIO1_TX1, rx => PIO1_RX1),
               2 => (tx => PIO1_TX2, rx => PIO1_RX2),
               3 => (tx => PIO1_TX3, rx => PIO1_RX3)));
   
   tx_trigger : constant DMA_Request_Trigger := trigger_lookup(P.Num, SM, tx); 
   rx_trigger : constant DMA_Request_Trigger := trigger_lookup(P.Num, SM, rx);

   
   P1 : RP2040_SVD.Pio.PIO_Peripheral renames RP2040_SVD.Pio.PIO0_Periph;
   P2 : RP2040_SVD.Pio.PIO_Peripheral renames RP2040_SVD.Pio.PIO1_Periph;

   type FIFO_Array_Type is array (PIO_SM range PIO_SM'range) of HAL.Uint32;
   type TXRX_FiFOs_Type is array (txrx_type range txrx_type'range) of FIFO_Array_Type with Object_Size => HAL.Uint32'Size * 4 * 2;
   
   use type System.Address;
   P1_FIFOS : TXRX_FiFOs_Type with import, Address => P1.TXF0'Address;
   P2_FIFOS : TXRX_FiFOs_Type with import, Address => P2.TXF0'Address;
   
   TX_FIfo_Address : constant System.Address := (if P.Num = 0 then P1_FIFOS(tx)( SM)'Address else P2_FIFOS(tx)(SM)'Address);
   RX_FIfo_Address : constant System.Address := (if P.Num = 0 then P1_FIFOS(rx)(SM)'Address else P2_FIFOS(rx)(SM)'Address);
   
   dma_cfg_write : constant DMA_Configuration := (High_Priority => True, Increment_Read => True, Trigger => tx_trigger, Quiet => False,others => <>);
   dma_cfg_read : constant DMA_Configuration := (High_Priority => True, Increment_Write => True, Trigger =>  rx_trigger, Quiet => False,others => <>);

   dma_block : Ada.Synchronous_Task_Control.Suspension_Object;
 
   
end Picowi.Generic_PIO_SPI;
