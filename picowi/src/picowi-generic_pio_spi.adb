--  SPDX-FileCopyrightText: 2026 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: MIT
----------------------------------------------------------------

with Picowi.PIO_SPI_Code;
with RP.DMA;
with System.Storage_Elements;
with Ada.Interrupts; --use Ada.Interrupts;
with Ada.Interrupts.Names;
with RP2040_SVD.PIO;
with RP.Device;
with Ada.Synchronous_Task_Control;

package body Picowi.Generic_PIO_SPI is


  Transfer_Done : Ada.Synchronous_Task_Control.Suspension_Object;

   -----------------
   -- Chip_Select --
   -----------------

   procedure Chip_Select (On : Boolean) is
   begin
      if On then
         WL_CS.Clear;
      else
         WL_CS.Set;
      end if;
   end Chip_Select;

   --------------------
   -- Configure_GPIO --
   --------------------

   procedure Configure_GPIO is
   begin
      --  The WLAN host interface supports gSPI and SDIO v2.0 modes.
      --  This SDIO_DATA_2 pin selects the WLAN host interface mode. The
      --  default is SDIO. For gSPI, pull this pin low.
      --  Strapping Options sampling occurs a few milliseconds after an
      --  Power-On Reset.

      WL_ON.Configure (RP.GPIO.Output);
      WL_ON.Clear;  --  Power OFF

      WL_CS.Configure (RP.GPIO.Output);
      WL_CS.Set;

      WL_CLK.Configure (RP.GPIO.Output);
      WL_CLK.Clear;

      WL_D.Configure (RP.GPIO.Output);
      WL_D.Clear;
   end Configure_GPIO;

   -------------------
   -- Configure_PIO --
   -------------------

   procedure Configure_PIO is

      Config : RP.PIO.PIO_SM_Config := RP.PIO.Default_SM_Config;

   begin
      P.Enable;
      P.Load (Picowi.PIO_SPI_Code.Picowi_Pio_Program_Instructions, 0);

      --  Set I/O pins to be PIO controlled
      WL_CLK.Configure (RP.GPIO.Output, Func => P.GPIO_Function);
      WL_D.Configure (RP.GPIO.Output, Func => P.GPIO_Function);

      RP.PIO.Set_Wrap
        (Config,
         Wrap_Target => Picowi.PIO_SPI_Code.Picowi_Pio_Wrap_Target,
         Wrap        => Picowi.PIO_SPI_Code.Picowi_Pio_Wrap);

      RP.PIO.Set_Sideset (Config, 1, False, False);

      --  Configure data pin as I/O, clock pin as O/P (sideset)
      RP.PIO.Set_Out_Pins (Config, WL_D.Pin, 1);
      RP.PIO.Set_In_Pins (Config, WL_D.Pin);
      RP.PIO.Set_Sideset_Pins (Config, WL_CLK.Pin);

      --  Get 8 bits from FIFOs, disable auto-pull & auto-push
      RP.PIO.Set_Out_Shift (Config, False, False, 8);
      RP.PIO.Set_In_Shift (Config, False, False, 8);

      RP.PIO.Set_Clkdiv_Int_Frac (Config, 1, 0);

      P.SM_Initialize (SM, 0, Config);
      P.Clear_FIFOs (SM);
      P.Set_Enabled (SM, True);
      P.Set_Pin_Direction (SM, WL_CLK.Pin, RP.PIO.Output);
      P.Set_Pin_Direction (SM, WL_D.Pin, RP.PIO.Input);
   end Configure_PIO;

--    procedure Configure_PIO_DMA is
--    
--       Config : RP.PIO.PIO_SM_Config := RP.PIO.Default_SM_Config;
--    
--    begin
--       P.Enable;
--       P.Load (Picowi.PIO_SPI_Code.Picowi_Pio_Program_Instructions, 0);
--    
--       --  Set I/O pins to be PIO controlled
--       WL_CLK.Configure (RP.GPIO.Output, Func => P.GPIO_Function);
--       WL_D.Configure (RP.GPIO.Output, Func => P.GPIO_Function);
--    
--       RP.PIO.Set_Wrap
--         (Config,
--          Wrap_Target => Picowi.PIO_SPI_Code.Picowi_Pio_Wrap_Target,
--          Wrap        => Picowi.PIO_SPI_Code.Picowi_Pio_Wrap);
--    
--       RP.PIO.Set_Sideset (Config, 1, False, False);
--    
--       --  Configure data pin as I/O, clock pin as O/P (sideset)
--       RP.PIO.Set_Out_Pins (Config, WL_D.Pin, 1);
--       RP.PIO.Set_In_Pins (Config, WL_D.Pin);
--       RP.PIO.Set_Sideset_Pins (Config, WL_CLK.Pin);
--    
--       --  Get 8 bits from FIFOs, disable auto-pull & auto-push
--       RP.PIO.Set_Out_Shift (Config,
--                             False, --shift right, false = shift to left
--                             True, --auto pull
--                             8); -- pull threshold
--       RP.PIO.Set_In_Shift (Config,
--                            False, --Shift_Right, false = shift to left (data enters from right)
--                            True, --autopush
--                            8); --push threshold
--    
--       RP.PIO.Set_Clkdiv_Int_Frac (Config, 1, 0);
--    
--       P.SM_Initialize (SM, 0, Config);
--       P.Clear_FIFOs (SM);
--       P.Set_Enabled (SM, True);
--       P.Set_Pin_Direction (SM, WL_CLK.Pin, RP.PIO.Output);
--       P.Set_Pin_Direction (SM, WL_D.Pin, RP.PIO.Input);
--    end Configure_PIO_DMA;

   
   --------------
   -- Power_On --
   --------------

   procedure Power_On is
   begin
      WL_ON.Set;  --  Power ON
   end Power_On;

   --------------
   -- Read_SPI --
   --------------

   procedure Read_SPI (Data : out HAL.UInt8_Array) is
      use type HAL.UInt32;
   begin
      P.Execute (SM, Picowi.PIO_SPI_Code.Offset_reader);
      P.Put (SM, Data'Length - 1);
      for Item of Data loop
         declare
            Value : HAL.UInt32;
         begin
            P.Get (SM, Value);
            Item := HAL.UInt8 (Value);
         end;
      end loop;
   end Read_SPI;

    
  
   
   protected body Status is

   function Get_Status return Status_Type is 
   begin
     return Status.SPI_status;
   end Get_Status;
   
   procedure Set_Status (This : Status_Type) is
   begin
     Status.SPI_status := This;
   end Set_Status;

   -- procedure DMA_Write_Callback is
   -- begin
   --   Disable_IRQ(Channel => DMA_Chan, IRQ => 0);
   --    while not P.TX_FIFO_Empty (SM) loop
   --       null;
   --    end loop;
   -- 
   --    while RP.PIO.Current_Instruction_Address (P, SM) /=
   --      Picowi.PIO_SPI_Code.Offset_writer
   --    loop
   --       null;
   --    end loop;
   -- 
   --    P.Set_Pin_Direction (SM, WL_D.Pin, RP.PIO.Input);
   --    P.Execute (SM, Picowi.PIO_SPI_Code.Offset_stall);
   --    Set_Status(Idle);
   --    if Event_Pending_Callback /= null then
   --      Event_Pending_Callback.all;
   --    end if;
   -- end DMA_Write_Callback;


   -- procedure DMA_Read_Callback is
   -- begin
   --   Disable_IRQ(Channel => DMA_Chan, IRQ => 0);
   --   Set_Status(Idle);
   --    if Event_Pending_Callback /= null then
   --      Event_Pending_Callback.all;
   --    end if;
   -- end DMA_Read_Callback;


   procedure DMA_Callback_Handler is
   begin
     Disable_IRQ(Channel => DMA_Chan, IRQ => DMA_IRQ);
    
     if SPI_Status = Writing then
       while not P.TX_FIFO_Empty (SM) loop
         null;
      end loop;

      while RP.PIO.Current_Instruction_Address (P, SM) /=
        Picowi.PIO_SPI_Code.Offset_writer
      loop
         null;
      end loop;

      P.Set_Pin_Direction (SM, WL_D.Pin, RP.PIO.Input);
      P.Execute (SM, Picowi.PIO_SPI_Code.Offset_stall);
     end if;
     
      Set_Status(Idle);
     if Event_Pending_Callback /= null then
        Event_Pending_Callback.all;
     end if;
     Ada.Synchronous_Task_Control.Set_True(Transfer_Done);
   end DMA_Callback_Handler;
   
   end Status;

   use type HAL.Uint32;
   -- Write_Callback_Access : constant Parameterless_Handler := Status.DMA_Write_Callback'Access;
   -- Read_Callback_Access : constant Parameterless_Handler := Status.DMA_Read_Callback'Access;

 
  
   
   procedure Read_SPI_DMA (Data : out HAL.UInt8_Array) is
   begin
     Status.Set_Status(Reading);
     --configure pio device
     P.Execute (SM, Picowi.PIO_SPI_Code.Offset_reader);
     -- put data length to read into pio machine
     P.Put (SM, Data'Length - 1);

     RP.DMA.Enable;
     Configure( Channel => DMA_Chan, Config => dma_cfg_read);

     Ada.Synchronous_Task_Control.Set_False(Transfer_Done);
     
     --Attach_Handler(New_Handler => Read_Callback_Access, Interrupt => DMA_Interrupt_ID );
     Enable_IRQ(Channel => DMA_Chan, IRQ => DMA_IRQ);
     Start(Channel => DMA_Chan, From => RX_FIfo_Address, To => Data'Address, Count => Data'Length);

     --
     
     Ada.Synchronous_Task_Control.Suspend_Until_True(Transfer_Done);
     

   end Read_SPI_dma;
     
   
   ---------------
   -- Write_SPI --
   ---------------

   procedure Write_SPI (Data : HAL.UInt8_Array) is
   begin
      P.Clear_FIFOs (SM);
      P.Execute (SM, Picowi.PIO_SPI_Code.Offset_writer);
      P.Set_Pin_Direction (SM, WL_D.Pin, RP.PIO.Output);

      for Item of Data loop
         P.Put (SM, HAL.Shift_Left (HAL.UInt32 (Item), 24));
      end loop;

      while not P.TX_FIFO_Empty (SM) loop
         null;
      end loop;

      while RP.PIO.Current_Instruction_Address (P, SM) /=
        Picowi.PIO_SPI_Code.Offset_writer
      loop
         null;
      end loop;

      P.Set_Pin_Direction (SM, WL_D.Pin, RP.PIO.Input);
      P.Execute (SM, Picowi.PIO_SPI_Code.Offset_stall);
   end Write_SPI;

   procedure Write_SPI_DMA (Data :  HAL.UInt8_Array) is
     use System.Storage_Elements;
     use RP.DMA;
  begin
     Status.Set_Status(Writing);
     P.Clear_FIFOs (SM);
     P.Execute (SM, Picowi.PIO_SPI_Code.Offset_writer);
     P.Set_Pin_Direction (SM, WL_D.Pin, RP.PIO.Output);
     
      
     RP.DMA.Enable;
     --configure dma;
     Configure( Channel => DMA_Chan, Config => dma_cfg_write);
     --Attach_Handler(New_Handler => Write_Callback_Access, Interrupt => DMA_Interrupt_ID );

     Ada.Synchronous_Task_Control.Set_False(Transfer_Done);
     
     Enable_IRQ(Channel => DMA_Chan, IRQ => DMA_IRQ);
     Start(Channel => DMA_Chan, From => Data'Address, To => TX_FIfo_Address, Count => Data'Length);

     Ada.Synchronous_Task_Control.Suspend_Until_True(Transfer_Done);
     
   end Write_SPI_DMA;



end Picowi.Generic_PIO_SPI;
