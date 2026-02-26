---------------------------------------------------------------------------------
-- Defender sound board by Dar (darfpga@aol.fr)
-- http://darfpga.blogspot.fr
---------------------------------------------------------------------------------
-- gen_ram.vhd 
-------------------------------- 
-- Copyright 2005-2008 by Peter Wendrich (pwsoft@syntiac.com)
-- http://www.syntiac.com/fpga64.html
---------------------------------------------------------------------------------
-- cpu68 - Version 9th Jan 2004 0.8
-- 6800/01 compatible CPU core 
-- GNU public license - December 2002 : John E. Kent
---------------------------------------------------------------------------------
-- Educational use only
-- Do not redistribute synthetized file with roms
-- Do not redistribute roms whatever the form
-- Use at your own risk
---------------------------------------------------------------------------------
-- Version 0.0 -- 15/10/2017 -- 
--		    initial version
---------------------------------------------------------------------------------
-- 2020 added speech 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity williams_sound_board is
port(
	clock        : in  std_logic;
	reset        : in  std_logic;
	hand         : in  std_logic;
	select_sound : in  std_logic_vector( 5 downto 0);
	audio_out    : out std_logic_vector( 7 downto 0);
	speech_out   : out std_logic_vector(15 downto 0);
	rom_addr     : out std_logic_vector(13 downto 0);
	rom_do       : in  std_logic_vector( 7 downto 0);
	spch_do      : in  std_logic_vector( 7 downto 0);
	rom_vma      : out std_logic
);
end williams_sound_board;

architecture struct of williams_sound_board is

 signal cpu_addr   : std_logic_vector(15 downto 0);
 signal cpu_di     : std_logic_vector( 7 downto 0);
 signal cpu_do     : std_logic_vector( 7 downto 0);
 signal cpu_rw     : std_logic;
 signal cpu_irq    : std_logic;
 signal cpu_vma    : std_logic;

 signal wram_cs   : std_logic;
 signal wram_we   : std_logic;
 signal wram_do   : std_logic_vector( 7 downto 0);
 
 signal rom_cs    : std_logic;
 signal spch_cs   : std_logic;
 signal ce_089    : std_logic;

-- pia port a
--      bit 0-7 audio output

-- pia port b
--      bit 0-4 select sound input (sel0-4)
--      bit 5-6 switch sound/notes/speech on/off
--      bit 7   sel5

-- pia io ca/cb
--      ca1 vdd
--      cb1 sound trigger (sel0-5 = 1)
--      ca2 speech data N/C
--      cb2 speech clock N/C

 signal speech_cen      : std_logic;
 signal speech_data     : std_logic;
 
 
 signal pia_rw_n   : std_logic;
 signal pia_cs     : std_logic;
 signal pia_irqa   : std_logic;
 signal pia_irqb   : std_logic;
 signal pia_do     : std_logic_vector( 7 downto 0);
 signal pia_pa_o   : std_logic_vector( 7 downto 0);
 signal pia_pb_i   : std_logic_vector( 7 downto 0);
 signal pia_cb1_i  : std_logic;

begin

clk089 : work.CEGen
port map
(
	CLK     => clock,
	IN_CLK  => 1200,
	OUT_CLK => 89,
	CE      => ce_089
);


-- pia cs
wram_cs <= '1' when cpu_addr(15 downto  8) = X"00" else '0';                        -- 0000-007F
pia_cs  <= '1' when cpu_addr(14 downto 12) = "000" and cpu_addr(10) = '1' else '0'; -- 8400-8403 ? => 0400-0403
spch_cs <= '1' when cpu_addr(15 downto 12) >= X"B" and cpu_addr(15 downto 12) <= X"E" else '0'; -- B000-EFFF
rom_cs  <= '1' when cpu_addr(15 downto 12) = X"F" else '0';                         -- F000-FFFF

-- write enables
wram_we  <= '1' when cpu_rw = '0' and wram_cs = '1' else '0';
pia_rw_n <= '0' when cpu_rw = '0' and pia_cs = '1'  else '1'; 

-- mux cpu in data between roms/io/wram
cpu_di <=
	wram_do when wram_cs = '1' else
	pia_do  when pia_cs = '1'  else
	rom_do  when rom_cs   = '1' else 
	spch_do when spch_cs  = '1' else X"55";

-- pia I/O
audio_out <= pia_pa_o;

pia_pb_i(5 downto 0) <= select_sound(5 downto 0);
pia_pb_i(6) <= '1';
pia_pb_i(7) <= hand; -- Handshake from rom board rom_pia_pa_out(7)


-- pia Cb1
pia_cb1_i <= '0' when select_sound = "111111" and hand = '1' else '1';

-- pia irqs to cpu
cpu_irq  <= pia_irqa or pia_irqb;

-- microprocessor 6800
main_cpu : entity work.cpu68
port map(	
	clk      => clock,      -- E clock input (falling edge)
	rst      => reset,      -- reset input (active high)
	rw       => cpu_rw,     -- read not write output
	vma      => cpu_vma,    -- valid memory address (active high)
	address  => cpu_addr,   -- address bus output
	data_in  => cpu_di,     -- data bus input
	data_out => cpu_do,     -- data bus output
	hold     => not ce_089, -- hold input (active high) extend bus cycle
	halt     => '0',        -- halt input (active high) grants DMA
	irq      => cpu_irq,    -- interrupt request input (active high)
	nmi      => '0',        -- non maskable interrupt request input (active high)
	test_alu => open,
	test_cc  => open
);

rom_vma   <= rom_cs and cpu_vma;
rom_addr  <= (cpu_addr(13 downto 12) - "11") & cpu_addr(11 downto 0);

-- cpu wram 
cpu_ram : entity work.gen_ram
generic map( dWidth => 8, aWidth => 7)
port map(
	clk  => clock,
	we   => wram_we,
	addr => cpu_addr(6 downto 0),
	d    => cpu_do,
	q    => wram_do
);

-- pia 
pia : entity work.pia6821
port map
(	
	clk       	=> clock,
	rst       	=> reset,
	cs        	=> pia_cs,
	rw        	=> pia_rw_n,
	addr      	=> cpu_addr(1 downto 0),
	data_in   	=> cpu_do,
	data_out  	=> pia_do,
	irqa      	=> pia_irqa,
	irqb      	=> pia_irqb,
	pa_i      	=> (others => '0'),
	pa_o        => pia_pa_o,
	pa_oe       => open,
	ca1       	=> '1',
	ca2_i      	=> '0',
	ca2_o       => speech_data,
	ca2_oe      => open,
	pb_i      	=> pia_pb_i,
	pb_o        => open,
	pb_oe       => open,
	cb1       	=> pia_cb1_i,
	cb2_i      	=> '0',
	cb2_o       => speech_cen,
	cb2_oe      => open
);

-- CVSD speech decoder	
IC1: entity work.HC55564	
port map(	
	clk => clock,
	cen => speech_cen,
	rst => '0', -- Reset is not currently implemented
	bit_in => speech_data,
	sample_out(15 downto 0) => speech_out
	);

end struct;

-- HC55516 Continuously Variable Slope Delta decoder
-- Rewritten to match MAME's reverse-engineered digital model
-- (based on work by Aaron Giles, Jonathan Gevaryahu, Zonn Moore)
--
-- The real HC55516 is a fully digital chip internally with a 10-bit DAC,
-- 12-bit syllabic digital filter, and dual-edge processing. The previous
-- implementation used a simplified analog model that produced incorrect
-- frequency response (scratchiness and tinny tail artifacts).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hc55564 is
port
(
	clk        : in std_logic;
	cen        : in std_logic;
	rst        : in std_logic;
	bit_in     : in std_logic;
	sample_out : out std_logic_vector(15 downto 0)
);
end hc55564;

architecture hdl of hc55564 is

  -- HC55516 chip constants (from MAME reverse engineering)
  constant SYLMASK   : unsigned(11 downto 0) := x"FC0";
  constant SYLSHIFT  : integer := 6;
  constant SYLADD    : unsigned(11 downto 0) := x"FC1";  -- effectively -63 in 12-bit
  constant INTSHIFT  : integer := 4;

  -- Internal state
  signal shiftreg    : std_logic_vector(2 downto 0) := "000";
  signal sylfilter   : unsigned(11 downto 0) := x"03F";  -- reset value from MAME
  signal intfilter   : signed(9 downto 0) := (others => '0');
  signal next_sample : signed(15 downto 0) := (others => '0');
  signal old_cen     : std_logic := '0';

begin

process(clk)
  variable v_bit         : std_logic;
  variable v_shiftreg    : std_logic_vector(2 downto 0);
  variable v_coincidence : boolean;
  variable v_frozen      : boolean;
  variable v_sum         : signed(9 downto 0);
  variable v_intfilter   : signed(9 downto 0);
  variable v_sylfilter   : unsigned(11 downto 0);
  variable v_not_syl     : unsigned(11 downto 0);
  variable v_decay_term  : unsigned(11 downto 0);
  variable v_syl_step    : unsigned(5 downto 0);
  variable v_step_clamped: integer range 0 to 63;
  variable v_not_int     : signed(9 downto 0);
  variable v_int_wide    : signed(10 downto 0);
  variable v_out_int     : signed(9 downto 0);
  variable v_out_upper   : signed(15 downto 0);
  variable v_out_lower   : unsigned(5 downto 0);
begin
  if rising_edge(clk) then
    old_cen <= cen;

    -- Detect rising edge of cen (active clock transition)
    if old_cen = '0' and cen = '1' then

      v_bit := bit_in;
      v_intfilter := intfilter;

      -- Determine frozen state: integrator near rail and bit would push further
      -- bit=0 pushes positive, bit=1 pushes negative (per MAME convention)
      v_frozen := (v_intfilter >= to_signed(16#180#, 10) and v_bit = '0') or
                  (v_intfilter <= to_signed(-16#180#, 10) and v_bit = '1');

      -- Shift the new bit into the shift register
      v_shiftreg := shiftreg(1 downto 0) & v_bit;
      shiftreg <= v_shiftreg;

      -- Check coincidence: all 0s or all 1s in the 3-bit shift register
      v_coincidence := (v_shiftreg = "000") or (v_shiftreg = "111");

      -- Update syllabic filter (only if not frozen)
      v_not_syl := not sylfilter;
      v_decay_term := shift_right(v_not_syl and SYLMASK, SYLSHIFT);

      if not v_frozen then
        if v_coincidence then
          v_sylfilter := sylfilter + v_decay_term;
        else
          v_sylfilter := sylfilter + v_decay_term + SYLADD;
        end if;
      else
        v_sylfilter := sylfilter;
      end if;
      sylfilter <= v_sylfilter and x"FFF";

      -- Compute integrator decay sum on active edge
      -- sum = sext(((~intfilter) >> INTSHIFT) + 1, 10)
      v_not_int := not v_intfilter;
      v_sum := shift_right(v_not_int, INTSHIFT) + 1;

      if not v_frozen then
        v_int_wide := resize(v_intfilter, 11) + resize(v_sum, 11);
        v_intfilter := v_int_wide(9 downto 0);
      end if;
      intfilter <= v_intfilter;

      -- Scale 10-bit integrator to 16-bit output
      -- (intfilter << 6) | (((intfilter & 0x3FF) ^ 0x200) >> 4)
      v_out_upper := resize(v_intfilter, 16) sll 6;
      v_out_lower := unsigned(std_logic_vector(
                       resize(v_intfilter xor to_signed(16#200#, 10), 10)
                     ))(9 downto 4);
      next_sample <= v_out_upper or resize(signed('0' & v_out_lower), 16);

    -- Detect falling edge of cen (inactive clock transition)
    elsif old_cen = '1' and cen = '0' then

      v_intfilter := intfilter;

      -- Determine frozen state (uses last shifted bit)
      v_frozen := (v_intfilter >= to_signed(16#180#, 10) and shiftreg(0) = '0') or
                  (v_intfilter <= to_signed(-16#180#, 10) and shiftreg(0) = '1');

      -- Compute step from syllabic filter on inactive edge
      -- step = max(2, sylfilter >> 6)
      v_syl_step := unsigned(std_logic_vector(sylfilter(11 downto 6)));

      if to_integer(v_syl_step) < 2 then
        v_step_clamped := 2;
      else
        v_step_clamped := to_integer(v_syl_step);
      end if;

      if shiftreg(0) = '1' then
        -- bit=1: negative step
        v_sum := to_signed(-v_step_clamped, 10);
      else
        -- bit=0: positive step
        v_sum := to_signed(v_step_clamped, 10);
      end if;

      if not v_frozen then
        v_int_wide := resize(v_intfilter, 11) + resize(v_sum, 11);
        v_intfilter := v_int_wide(9 downto 0);
      end if;
      intfilter <= v_intfilter;

      -- Scale 10-bit integrator to 16-bit output
      v_out_upper := resize(v_intfilter, 16) sll 6;
      v_out_lower := unsigned(std_logic_vector(
                       resize(v_intfilter xor to_signed(16#200#, 10), 10)
                     ))(9 downto 4);
      next_sample <= v_out_upper or resize(signed('0' & v_out_lower), 16);

    end if;
  end if;
end process;

-- Convert signed output to unsigned with 0x8000 midpoint bias
-- Invert sign bit to convert signed to offset-binary
-- (matches the original interface convention expected by Arcade-Robotron.sv)
sample_out <= (not next_sample(15)) & std_logic_vector(next_sample(14 downto 0));

end architecture hdl;