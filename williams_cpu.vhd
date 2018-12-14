-----------------------------------------------------------------------
--
-- Copyright 2012 ShareBrained Technology, Inc.
--
-- This file is part of robotron-fpga.
--
-- robotron-fpga is free software: you can redistribute
-- it and/or modify it under the terms of the GNU General
-- Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your
-- option) any later version.
--
-- robotron-fpga is distributed in the hope that it will
-- be useful, but WITHOUT ANY WARRANTY; without even the
-- implied warranty of MERCHANTABILITY or FITNESS FOR A
-- PARTICULAR PURPOSE. See the GNU General Public License
-- for more details.
--
-- You should have received a copy of the GNU General
-- Public License along with robotron-fpga. If not, see
-- <http://www.gnu.org/licenses/>.
--
-----------------------------------------------------------------------

-- changed system timings and added vertical and horizontal blanking
-- Dec 2018 (DW oldgit)

library ieee;
	use ieee.std_logic_1164.all;
--	use ieee.std_logic_arith.all;
	use ieee.numeric_std.all;
	use ieee.std_logic_unsigned.all;

entity williams_cpu is
port(
	clk_sys			  : in		std_logic;
	CLK12            : in    std_logic;
	clk_1p79         : in    std_logic;
	clk_0p89         : in    std_logic;

	I_RESET		     : in		std_logic;	-- active high reset

	-- VGA out
	vgaR             : out   std_logic_vector(2 downto 0);
	vgaG             : out   std_logic_vector(2 downto 0);
	vgaB             : out   std_logic_vector(1 downto 0);
	O_hblank				: out		std_logic;
	O_vblank				: out		std_logic;
	Hsync            : out   std_logic;
	Vsync            : out   std_logic;
	
	audio_out			: out std_logic_vector(7 downto 0);
	
	dn_addr				: in		std_logic_vector(15 downto 0);
	dn_data				: in		std_logic_vector(7 downto 0);
	dn_wr					: in		std_logic;		

	-- Input connectors
	SW               : in    std_logic_vector(7 downto 0);
	JA               : in    std_logic_vector(8 downto 0);
	JB               : in    std_logic_vector(8 downto 0)
);
end williams_cpu;

architecture Behavioral of williams_cpu is
	signal reset                    : std_logic;

	signal clock                    : std_logic;
	signal clock_n                  : std_logic;
	signal clock_12_phase           : unsigned(11 downto 0) := (0 => '1', others => '0');

	signal PB						 	  : std_logic_vector(6 downto 0);
	signal cepix                    : std_logic;

	-------------------------------------------------------------------

	signal video_count              : unsigned(14 downto 0) := (others => '0');
	signal video_count_next         : unsigned(14 downto 0);
	signal video_address_or_mask    : unsigned(13 downto 0);
	signal video_address            : unsigned(13 downto 0) := (others => '0');

	signal count_240                : std_logic;
	signal irq_4ms                  : std_logic;

	signal horizontal_sync          : std_logic;
	signal vertical_sync            : std_logic;

	signal video_blank              : boolean := true;

	-------------------------------------------------------------------

	signal address                  : std_logic_vector(15 downto 0);

	signal mem_wr                   : boolean;
	signal mem_rd                   : boolean;

	-------------------------------------------------------------------
	-- MPU
	signal cpu_address              : std_logic_vector(15 downto 0);
	signal cpu_data_in              : std_logic_vector( 7 downto 0);
	signal cpu_data_out             : std_logic_vector( 7 downto 0);

	signal cpu_read                 : boolean;
	signal cpu_write                : boolean;

	signal cpu_halt                 : std_logic := '0';
	signal cpu_halted               : boolean := false;
	signal cpu_irq                  : std_logic := '0';

	signal cpu_do                   : std_logic_vector( 7 downto 0);
	signal cpu_ba                   : std_logic := '0';
	signal cpu_bs                   : std_logic := '0';
	signal cpu_rw                   : std_logic := '1';
	-------------------------------------------------------------------
	-- memory
	signal MemWR                    : std_logic := '0';
	signal RamUB                    : std_logic := '0';
	signal RamLB                    : std_logic := '0';
	signal FlashCS                  : std_logic := '0';

	signal ROM_DB                   : std_logic_vector(7 downto 0);
	signal RAM_DB                   : std_logic_vector(7 downto 0);

	signal memory_address           : std_logic_vector(15 downto 0);
	signal memory_data_in           : std_logic_vector(7 downto 0);
	signal memory_data_out          : std_logic_vector(7 downto 0);

	signal memory_oe                : boolean := false;
	signal memory_write             : boolean := false;
	signal flash_enable             : boolean := false;

	signal ram_enable               : boolean := false;
	signal ram_enable_lower         : boolean := false;
	signal ram_enable_upper         : boolean := false;

	-------------------------------------------------------------------

	signal e_rom                    : std_logic := '0';
	signal screen_control           : std_logic := '0';

	signal rom_access               : boolean;
	signal ram_access               : boolean;
	signal color_table_access       : boolean;
	signal widget_pia_access        : boolean;
	signal rom_pia_access           : boolean;
	signal blt_register_access      : boolean;
	signal video_counter_access     : boolean;
	signal watchdog_access          : boolean;
	signal control_access           : boolean;
	signal cmos_access              : boolean;

	signal video_counter_value      : std_logic_vector(7 downto 0);

	-------------------------------------------------------------------

	signal HAND                 : std_logic := '0';
	signal SLAM                 : std_logic := '0';
	signal R_COIN               : std_logic := '0';
	signal C_COIN               : std_logic := '0';
	signal L_COIN               : std_logic := '0';
	signal H_S_RESET            : std_logic := '0';
	signal ADVANCE              : std_logic := '0';
	signal AUTO_UP              : std_logic := '0';

	signal rom_pia_rs           : std_logic_vector(1 downto 0) := (others => '0');
	signal rom_pia_cs           : std_logic := '0';
	signal rom_pia_write        : std_logic := '0';
	signal rom_pia_data_in      : std_logic_vector(7 downto 0);
	signal rom_pia_data_out     : std_logic_vector(7 downto 0);
	signal rom_pia_ca2_out      : std_logic;
	signal rom_pia_irq_a        : std_logic;
	signal rom_pia_pa_in        : std_logic_vector(7 downto 0);
	signal rom_pia_pa_out       : std_logic_vector(7 downto 0);

	signal rom_pia_cb2_out      : std_logic;
	signal rom_pia_irq_b        : std_logic;
	signal rom_pia_pb_in        : std_logic_vector(7 downto 0);
	signal rom_pia_pb_out       : std_logic_vector(7 downto 0);
	signal rom_pia_pb_dir       : std_logic_vector(7 downto 0);

	-------------------------------------------------------------------

	signal MOVE_UP_1            : std_logic := '0';
	signal MOVE_DOWN_1          : std_logic := '0';
	signal MOVE_LEFT_1          : std_logic := '0';
	signal MOVE_RIGHT_1         : std_logic := '0';
	signal PLAYER_1_START       : std_logic := '0';
	signal PLAYER_2_START       : std_logic := '0';
	signal FIRE_UP_1            : std_logic := '0';
	signal FIRE_DOWN_1          : std_logic := '0';
	signal FIRE_RIGHT_1         : std_logic := '0';
	signal FIRE_LEFT_1          : std_logic := '0';
	signal MOVE_UP_2            : std_logic := '0';
	signal MOVE_DOWN_2          : std_logic := '0';
	signal MOVE_LEFT_2          : std_logic := '0';
	signal MOVE_RIGHT_2         : std_logic := '0';
	signal FIRE_RIGHT_2         : std_logic := '0';
	signal FIRE_UP_2            : std_logic := '0';
	signal FIRE_DOWN_2          : std_logic := '0';
	signal FIRE_LEFT_2          : std_logic := '0';

	constant board_interface_w1 : std_logic := '0';  -- Upright application: '1' = jumper present

	signal widget_pia_rs        : std_logic_vector(1 downto 0) := (others => '0');
	signal widget_pia_cs        : std_logic;
	signal widget_pia_write     : std_logic := '0';
	signal widget_pia_data_in   : std_logic_vector(7 downto 0);
	signal widget_pia_data_out  : std_logic_vector(7 downto 0);
	signal widget_pia_pa_in     : std_logic_vector(7 downto 0);
	signal widget_pia_input_select  : std_logic;
	signal widget_pia_pb_in     : std_logic_vector(7 downto 0);

	signal widget_ic3_a         : std_logic_vector(4 downto 1);
	signal widget_ic3_b         : std_logic_vector(4 downto 1);
	signal widget_ic3_y         : std_logic_vector(4 downto 1);

	signal widget_ic4_a         : std_logic_vector(4 downto 1);
	signal widget_ic4_b         : std_logic_vector(4 downto 1);
	signal widget_ic4_y         : std_logic_vector(4 downto 1);

	-------------------------------------------------------------------

	signal blt_rs               : std_logic_vector(2 downto 0) := (others => '0');
	signal blt_reg_cs           : std_logic := '0';
	signal blt_reg_data_in      : std_logic_vector(7 downto 0) := (others => '0');

	signal blt_halt             : boolean := false;
	signal blt_halt_ack         : boolean := false;
	signal blt_read             : boolean := false;
	signal blt_write            : boolean := false;
	signal blt_blt_ack          : std_logic := '0';
	signal blt_address_out      : std_logic_vector(15 downto 0);
	signal blt_data_in          : std_logic_vector(7 downto 0);
	signal blt_data_out         : std_logic_vector(7 downto 0);
	signal blt_en_lower         : boolean := false;
	signal blt_en_upper         : boolean := false;

	-------------------------------------------------------------------

	function to_std_logic(L: boolean) return std_logic is
	begin
		if L then
			return '1';
		else
			return '0';
		end if;
	end function;

	subtype pixel_color_t is std_logic_vector(7 downto 0);
	type color_table_t is array(0 to 15) of pixel_color_t;
	signal color_table : color_table_t := (
		x"00", x"07", x"17", x"c7",
		x"1f", x"3f", x"38", x"c0",
		x"a4", x"ff", x"38", x"17",
		x"cc", x"81", x"81", x"07"); -- init values useful for simulation

	signal pixel_nibbles : std_logic_vector(7 downto 0);
	signal pixel_byte_l : std_logic_vector(7 downto 0);
	signal pixel_byte_h : std_logic_vector(7 downto 0);

	-------------------------------------------------------------------

	signal reset_counter						: std_logic_vector(7 downto 0);
	signal decoder_4_in : std_logic_vector(8 downto 0);
	signal pseudo_address : std_logic_vector(15 downto 8);

	signal decoder_6_in : std_logic_vector(8 downto 0);
	signal video_prom_address : std_logic_vector(13 downto 6);
	
	signal romd4_cs         : std_logic;
	signal romd6_cs         : std_logic;
	signal hblank	         : std_logic;
	signal vblank	         : std_logic;
	signal hcnt : std_logic_vector(4 downto 0);
	signal vcnt : std_logic_vector(8 downto 0);
	-------------------------------------------------------------------

begin
	clock   <=     CLK12;
	clock_n <= not CLK12;
	
	-------------------------------------------------------------------
	-- clock    0   1   2   3   4   5   6   7   8   9   10  11
	-- Q        0   0   0   1   1   1   1   1   1   0   0   0
	-- E        0   0   0   0   0   0   1   1   1   1   1   1
	-- Memory   0   0   1   1   2   2   3   3   4   4   5   5

	-- Delayed Reset generator
	process
	begin
		wait until rising_edge(clock);
		if I_RESET = '1' then
			reset_counter <= (others => '0');
			reset <= '1';
		else
			if reset_counter < x"80" then
				reset_counter <= reset_counter + 1;
			else
				reset <= '0';
			end if;
		end if;
	end process;	
	

	inst_cpu09 : entity work.cpu09
	port map (
		-- ins
		clk	    => clock,
		hold      => not clock_12_phase(2), -- active low clock enable
		rst       => reset,
		halt      => cpu_halt,
		irq       => cpu_irq,
		firq      => '0',
		nmi       => '0',
		data_in   => cpu_data_out,
		-- outs
		data_out  => cpu_do,
		address   => cpu_address,
		rw	       => cpu_rw,
		ba        => cpu_ba,
		bs        => cpu_bs,
		vma       => open,
		pc_out    => open
	);

	inst_RAM : entity work.RAMS
	port map (
		CLK  => clock_n,
		ENL  => RamLB,
		ENH  => RamUB,
		WE   => MemWR,
		ADDR => memory_address,
		DO   => RAM_DB,
		DI   => memory_data_out
	);



	inst_ROM : entity work.ROMS
	port map (
		CLK  => clock_n,
		clk_sys		=> clk_sys,
		dn_addr			=> dn_addr,
		dn_data			=> dn_data,
		dn_wr				=> dn_wr,
		ENA  => FlashCS,
		ADDR => memory_address,
		DO   => ROM_DB
	);

	-------------------------------------------------------------------
	-- data bus multiplexer
	memory_data_in <=
		ROM_DB when flash_enable and memory_oe else
		RAM_DB when ram_enable   and memory_oe else
		(others=>'0');

	-------------------------------------------------------------------

	MemWR   <= '1' when memory_write         else '0';

	RamLB   <= '1' when ram_enable_lower     else '0';
	RamUB   <= '1' when ram_enable_upper     else '0';

	FlashCS <= '1' when flash_enable         else '0';

	cpu_halt  <= to_std_logic(blt_halt);
	cpu_irq   <= rom_pia_irq_a or rom_pia_irq_b;

	address <= blt_address_out when cpu_halted else cpu_address;
	mem_wr  <= blt_write       when cpu_halted else cpu_write;
	mem_rd  <= blt_read        when cpu_halted else cpu_read;

	rom_access <=
		(address <  X"9000" and mem_rd and e_rom = '1') or
		(address >= X"D000" and mem_rd);
	ram_access <=
		(address <  X"9000" and mem_wr) or
		(address <  X"9000" and mem_rd and e_rom = '0') or
		(address >= X"9000" and address < X"C000");

	-- Color table: write: C000-C3FF
	color_table_access   <= std_match(address, "110000----------");

	-- Widget PIA: read/write: C8X4 - C8X7
	widget_pia_access    <= std_match(address, "11001000----01--");

	-- ROM PIA: read/write: C8XC - C8XF
	rom_pia_access       <= std_match(address, "11001000----11--");

	-- Control address: write: C9XX
	control_access       <= std_match(address, "11001001--------");

	-- Special chips: read/write? CAXX
	blt_register_access  <= std_match(address, "11001010--------");

	-- Video counter: read: CBXX (even addresses)
	video_counter_access <= std_match(address, "11001011-------0");

	-- Watchdog register: write: CBFE or CBFF
--	watchdog_access      <= std_match(address, "110010111111111-");

	-- CMOS "nonvolatile" RAM: read/write: CC00 - CFFF
	cmos_access          <= std_match(address, "110011----------");

	-------------------------------------------------------------------
	-- button inputs
	SLAM           <= SW(6);
	R_COIN         <= SW(5);
	C_COIN         <= SW(4);
	L_COIN         <= SW(3);
	H_S_RESET      <= SW(2);
	ADVANCE        <= SW(1);
	AUTO_UP        <= SW(0);

	PLAYER_1_START <= JA(8);
	PLAYER_2_START <= SW(7);

	MOVE_UP_1      <= JA(0);
	MOVE_DOWN_1    <= JA(1);
	MOVE_LEFT_1    <= JA(2);
	MOVE_RIGHT_1   <= JA(3);
	FIRE_UP_1      <= JA(4);
	FIRE_DOWN_1    <= JA(5);
	FIRE_LEFT_1    <= JA(6);
	FIRE_RIGHT_1   <= JA(7);

	MOVE_UP_2      <= JB(0);
	MOVE_DOWN_2    <= JB(1);
	MOVE_LEFT_2    <= JB(2);
	MOVE_RIGHT_2   <= JB(3);
	FIRE_UP_2      <= JB(4);
	FIRE_DOWN_2    <= JB(5);
	FIRE_LEFT_2    <= JB(6);
	FIRE_RIGHT_2   <= JB(7);

	-------------------------------------------------------------------
	-- 1MHz, 12-phase counter.
	clock_12_phase <= clock_12_phase rol 1 when rising_edge(clock);

	-------------------------------------------------------------------
	-- Video counter

	video_count_next <= video_count + 1 when (video_count /= 16639) else (others => '0');
	video_address_or_mask <= "11111100000000" when video_count_next(14) = '1' else (others => '0');
	irq_4ms <= video_address(11);

	process
	begin
		-- Advance video count at end of video memory phase.
		wait until rising_edge(clock);
		if clock_12_phase(11) = '1' then
			video_count <= video_count_next;
			video_address <= video_count_next(13 downto 0) or video_address_or_mask;
		end if;
	end process;

	-------------------------------------------------------------------
	-- Video generator

	hcnt <= std_logic_vector(video_address(4 downto 0));
	vcnt <= std_logic_vector(video_address(13 downto 5));

	count_240       <= '1' when video_address(13 downto 10) =  "1111" else '0';
	horizontal_sync <= '1' when video_address( 4 downto 0)  = "11011" or video_address( 4 downto 0)  = "11100" else '0';
	vertical_sync   <= '1' when video_address(13 downto 9)  = "11111" else '0';

	video_counter_value <= std_logic_vector(video_address(13 downto 8)) & "00";

	decoder_4_in <= screen_control & address(15 downto 8);
	decoder_6_in <= screen_control & std_logic_vector(video_address(13 downto 6));

	-------------------------------------------------------------------

	cpu_halted        <= cpu_bs = '1' and cpu_ba = '1';
	cpu_write         <= cpu_rw = '0' and cpu_ba = '0';
	cpu_read          <= cpu_rw = '1' and cpu_ba = '0';

	process
	begin
		wait until rising_edge(clock);
		if clock_12_phase(5) = '1' then
			cpu_data_in <= cpu_do;
		end if;
	end process;

	process
	begin
		wait until rising_edge(clock);
		ram_enable       <= false;
		ram_enable_lower <= false;
		ram_enable_upper <= false;

		flash_enable     <= false;

		memory_oe        <= false;
		memory_write     <= false;
		memory_data_out  <= (others => '0');

		blt_reg_cs       <= '0';
		blt_blt_ack      <= '0';

		if clock_12_phase( 0) = '1' then
			memory_address <= "00" & video_prom_address & std_logic_vector(video_address(4 downto 0)) & "0";
		end if;

		if clock_12_phase( 2) = '1' then
			memory_address <= "01" & video_prom_address & std_logic_vector(video_address(4 downto 0)) & "0";
		end if;

		if clock_12_phase( 4) = '1' then
			memory_address <= "10" & video_prom_address & std_logic_vector(video_address(4 downto 0)) & "0";
		end if;

		if clock_12_phase( 6) = '1' then
			memory_address <= "00" & video_prom_address & std_logic_vector(video_address(4 downto 0)) & "1";
		end if;

		if clock_12_phase( 8) = '1' then
			memory_address <= "01" & video_prom_address & std_logic_vector(video_address(4 downto 0)) & "1";
		end if;

		if clock_12_phase(10) = '1' then
			memory_address <= "10" & video_prom_address & std_logic_vector(video_address(4 downto 0)) & "1";
		end if;

		if clock_12_phase(5) = '1' then
			if std_match(video_address(4 downto 0) & "1", "11-1-1") then
				video_blank <= true;
			elsif std_match(video_address(4 downto 0) & "1", "0---11") then
				video_blank <= false;
			end if;
		end if;

		if clock_12_phase( 0) = '1' or
			clock_12_phase( 2) = '1' or
			clock_12_phase( 4) = '1' or
			clock_12_phase( 6) = '1' or
			clock_12_phase( 8) = '1' or
			clock_12_phase(10) = '1' then
			memory_oe        <= true;
			ram_enable       <= true;
			ram_enable_lower <= true;
			ram_enable_upper <= true;

			if video_blank then
				vgaR <= (others => '0');
				vgaG <= (others => '0');
				vgaB <= (others => '0');
			else
				vgaR <= pixel_byte_h(2 downto 0);
				vgaG <= pixel_byte_h(5 downto 3);
				vgaB <= pixel_byte_h(7 downto 6);
			end if;
		end if;

		if clock_12_phase( 1) = '1' or
			clock_12_phase( 3) = '1' or
			clock_12_phase( 5) = '1' or
			clock_12_phase( 7) = '1' or
			clock_12_phase( 9) = '1' or
			clock_12_phase(11) = '1' then
			pixel_nibbles <= memory_data_in;

			pixel_byte_l <= color_table(to_integer(unsigned(pixel_nibbles(3 downto 0))));
			pixel_byte_h <= color_table(to_integer(unsigned(pixel_nibbles(7 downto 4))));

			if video_blank then
				vgaR <= (others => '0');
				vgaG <= (others => '0');
				vgaB <= (others => '0');
			else
				vgaR <= pixel_byte_l(2 downto 0);
				vgaG <= pixel_byte_l(5 downto 3);
				vgaB <= pixel_byte_l(7 downto 6);
			end if;
		end if;

		-- BLT-only cycles
		-- NOTE: the next cycle must be a read if coming from RAM, since the
		-- RAM WE# needs to deassert for a time in order for another write to
		-- take place.
		if clock_12_phase(11) = '1' or clock_12_phase(1) = '1' then
			if cpu_halted then
				if ram_access then
					if pseudo_address(15 downto 14) = "11" then
						memory_address <= address;
					else
						memory_address <=
							pseudo_address(15 downto 14) &
							address(7 downto 0) &
							pseudo_address(13 downto 8);
					end if;
				elsif rom_access or cmos_access or color_table_access then
					memory_address <= address;
				end if;

				if ram_access and mem_wr then
					memory_data_out <= blt_data_out;
					memory_write    <= true;
				else
					memory_oe <= true;
				end if;

				if ram_access then
					ram_enable <= true;
					ram_enable_lower <= blt_en_lower;
					ram_enable_upper <= blt_en_upper;
				end if;

				if rom_access then
					flash_enable <= true;
				end if;

				blt_blt_ack <= '1';
			end if;
		end if;

		-- MPU-only cycle
		-- NOTE: the next cycle must be a read if coming from RAM, since the
		-- RAM WE# needs to deassert for a time in order for another write to
		-- take place.
		if clock_12_phase(7) = '1' then
			if not cpu_halted then
				if ram_access then
					if pseudo_address(15 downto 14) = "11" then
						memory_address <= address;
					else
						memory_address <= pseudo_address(15 downto 14) & address(7 downto 0) & pseudo_address(13 downto 8);
					end if;
				elsif rom_access or cmos_access or color_table_access then
					memory_address <= address;
				end if;

				if (ram_access or cmos_access or color_table_access) and mem_wr then
					memory_data_out <= cpu_data_in;
					memory_write    <= true;
				else
					memory_oe <= true;
				end if;

				if ram_access or cmos_access or color_table_access then
					ram_enable       <= true;
					ram_enable_lower <= true;
					ram_enable_upper <= true;
				end if;

				if rom_access then
					flash_enable <= true;
				end if;

				if blt_register_access and mem_wr then
					blt_rs          <= address(2 downto 0);
					blt_reg_cs      <= '1';
					blt_reg_data_in <= cpu_data_in;
				end if;

				if control_access and mem_wr then
					screen_control <= cpu_data_in(1);
					e_rom          <= cpu_data_in(0);
				end if;

				if color_table_access and mem_wr then
					color_table(to_integer(unsigned(address(3 downto 0)))) <= cpu_data_in;
				end if;
			end if;
		end if;

		if clock_12_phase(8) = '1' then
			if not cpu_halted then
				if mem_rd then
					if ram_access or rom_access or cmos_access then
						cpu_data_out <= memory_data_in;
					end if;

					if widget_pia_access then
						cpu_data_out <= widget_pia_data_out;
					end if;

					if rom_pia_access then
						cpu_data_out <= rom_pia_data_out;
					end if;

					if video_counter_access then
						cpu_data_out <= video_counter_value;
					end if;
				end if;
			end if;
		end if;
	end process;

	-------------------------------------------------------------------

	romd4_cs <= '1' when dn_addr(15 downto 9) = "1101000" else '0';
	romd6_cs <= '1' when dn_addr(15 downto 9) = "1101001" else '0';
	
	-- cpu to video addr decoder
cpu_video_addr_decoder : work.dpram generic map (9,8)
port map
(
	clock_a   => clk_sys,
	wren_a    => dn_wr and romd4_cs,
	address_a => dn_addr(8 downto 0),
	data_a    => dn_data,

	clock_b   => clock_n,
	address_b => decoder_4_in,
	q_b       => pseudo_address
);

-- video scan addr decoder
video_scan_addr_decoder : work.dpram generic map (9,8)
port map
(
	clock_a   => clk_sys,
	wren_a    => dn_wr and romd6_cs,
	address_a => dn_addr(8 downto 0),
	data_a    => dn_data,

	clock_b   => clock_n,
	address_b => decoder_6_in,
	q_b       => video_prom_address
);

	-------------------------------------------------------------------

	blt_halt_ack <= cpu_halted;
	blt_data_in  <= memory_data_in;

	inst_blitter: entity work.sc1
	generic map (is_sc1 => true) -- true for SC1, false for SC2
	port map(
		clk             => clock,

		reg_cs          => blt_reg_cs,
		reg_data_in     => blt_reg_data_in,
		rs              => blt_rs,

		halt            => blt_halt,
		halt_ack        => blt_halt_ack,

		blt_ack         => blt_blt_ack,
		blt_address_out => blt_address_out,

		blt_rd          => blt_read,
		blt_wr          => blt_write,

		blt_data_in     => blt_data_in,
		blt_data_out    => blt_data_out,

		en_upper        => blt_en_upper,
		en_lower        => blt_en_lower
	);

	-------------------------------------------------------------------

	rom_pia_pa_in <=
		HAND &
		SLAM &
		C_COIN &
		L_COIN &		
		H_S_RESET &
		R_COIN &
		ADVANCE &
		AUTO_UP;

-- when pins are inputs, external pullups hold pins high
	PB <= rom_pia_pa_out(7) & rom_pia_pb_out(5 downto 0);
	HAND <= '0'; --rom_pia_pa_out(7);

	rom_pia_pb_in   <= (others => '1');

	rom_pia_write   <= to_std_logic(not mem_wr);
	rom_pia_cs      <= '1' when rom_pia_access else '0';

	inst_pia_rom : entity work.pia6821
	port map (
		rst      => reset,
		clk_p    => clock and clock_12_phase(2),
		clk_n    => clock and clock_12_phase(8),

		addr     => address(1 downto 0),
		cs       => rom_pia_cs,
		rw       => rom_pia_write,

		data_in  => cpu_data_in,
		data_out => rom_pia_data_out,

		ca1      => count_240,
		ca2_i    => '1',
		irqa     => rom_pia_irq_a,
		pa_i     => rom_pia_pa_in,
		pa_o     => rom_pia_pa_out,

		cb1      => irq_4ms,
		cb2_i    => '1',
		irqb     => rom_pia_irq_b,
		pb_i     => rom_pia_pb_in,
		pb_o     => rom_pia_pb_out
	);

	-------------------------------------------------------------------

	widget_ic3_a <= (MOVE_RIGHT_2 & MOVE_LEFT_2 & MOVE_DOWN_2 & MOVE_UP_2);
	widget_ic3_b <= (MOVE_RIGHT_1 & MOVE_LEFT_1 & MOVE_DOWN_1 & MOVE_UP_1);

	widget_ic3_y <= widget_ic3_b when widget_pia_input_select = '1' else widget_ic3_a;

	widget_ic4_a <= (FIRE_RIGHT_2 & FIRE_LEFT_2 & FIRE_DOWN_2 & FIRE_UP_2);
	widget_ic4_b <= (FIRE_RIGHT_1 & FIRE_LEFT_1 & FIRE_DOWN_1 & FIRE_UP_1);

	widget_ic4_y <= widget_ic4_b when widget_pia_input_select = '1' else widget_ic4_a;

	widget_pia_pa_in <=
		widget_ic4_y(2) &
		widget_ic4_y(1) &
		PLAYER_2_START &
		PLAYER_1_START &
		widget_ic3_y(4) &
		widget_ic3_y(3) &
		widget_ic3_y(2) &
		widget_ic3_y(1);

	widget_pia_pb_in <=
		board_interface_w1 &
		"00000" &
		widget_ic4_y(4) &
		widget_ic4_y(3);

	widget_pia_write <= to_std_logic(not mem_wr);
	widget_pia_cs    <= '1' when widget_pia_access else '0';

	inst_pia_widget : entity work.pia6821
	port map (
		rst      => reset,
		clk_p    => clock and clock_12_phase(2),
		clk_n    => clock and clock_12_phase(8),

		addr     => address(1 downto 0),
		cs       => widget_pia_cs,
		rw       => widget_pia_write,

		data_in  => cpu_data_in,
		data_out => widget_pia_data_out,

		ca1      => '0',
		ca2_i    => '0',
		pa_i     => widget_pia_pa_in,

		cb1      => '0',
		cb2_i    => '1',
		cb2_o    => widget_pia_input_select,
		pb_i     => widget_pia_pb_in
	);

	-- VGA output
	
	process
	begin
		wait until rising_edge(clock);
		if    hcnt = 27 then hblank <= '1';
		elsif hcnt = 1  then hblank <= '0';
		end if;
		
		if    vcnt = 494 then vblank <= '1';
		elsif vcnt = 15  then vblank <= '0';
		end if;
	end process;	

	Hsync <= horizontal_sync;
	Vsync <= vertical_sync;
	O_hblank	<= hblank;
	O_vblank	<= vblank;

	-------------------------------------------------------------------

	audio: entity work.williams_sound_board
	port map(
		clk_sys 		=> clk_sys,
		clk_1p79 	=> clk_1p79,
		clk_0p89 	=> clk_0p89,        
		reset 		=> reset,
		hand 			=> PB(6),
		dn_addr 		=> dn_addr,       
		dn_data 		=> dn_data,
		dn_wr 		=> dn_wr,       
		select_sound=> PB(5 downto 0),
		audio_o 		=> audio_out
	);

end Behavioral;
