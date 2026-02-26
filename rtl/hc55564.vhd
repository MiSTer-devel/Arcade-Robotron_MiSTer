-- ============================================================================
-- Continuously Variable Slope Demodulator standalone chip emulator
-- 
-- This is a VHDL port of the MAME C++ CVSD emulator.
-- 
-- Original C++ copyright-holders: Aaron Giles, Jonathan Gevaryahu
-- Original C++ thanks-to: Zonn Moore
-- ============================================================================
--
-- License: BSD-3-Clause
--
-- Copyright (c) Aaron Giles, Jonathan Gevaryahu
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- 1. Redistributions of source code must retain the above copyright notice,
--    this list of conditions and the following disclaimer.
--
-- 2. Redistributions in binary form must reproduce the above copyright notice,
--    this list of conditions and the following disclaimer in the documentation
--    and/or other materials provided with the distribution.
--
-- 3. Neither the name of the copyright holder nor the names of its contributors
--    may be used to endorse or promote products derived from this software
--    without specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
-- ============================================================================

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

  -- HC55516 chip constants
  constant SYLMASK   : unsigned(11 downto 0) := x"FC0";
  constant SYLSHIFT  : integer := 6;
  constant SYLADD    : unsigned(11 downto 0) := x"FC1";  -- effectively -63 in 12-bit
  constant INTSHIFT  : integer := 4;

  -- Internal state
  signal shiftreg    : std_logic_vector(2 downto 0) := "000";
  signal sylfilter   : unsigned(11 downto 0) := x"03F";
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
      -- bit=0 pushes positive, bit=1 pushes negative
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
