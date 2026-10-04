library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;
	use ieee.std_logic_textio.all;
library std;
	use std.textio.all;

entity blaster_board_tb is
generic(rom_file : string := "blasterkit.hex");
end;

architecture test of blaster_board_tb is
	signal clock : std_logic := '0';
	signal blaster : std_logic := '1';
	signal stereo : std_logic := '0';
	signal fire : std_logic := '1';
	signal game : std_logic_vector(7 downto 0) := x"08";
	signal a : std_logic_vector(15 downto 0) := x"FFFF";
	signal dout : std_logic_vector(7 downto 0) := x"00";
	signal din : std_logic_vector(7 downto 0);
	signal rw : std_logic := '1';
	signal e, q, halt_n, ba, reset_n : std_logic;
	signal btn : std_logic_vector(3 downto 0) := "0001";
	signal mem_addr : std_logic_vector(15 downto 0);
	signal mem_in, mem_out, ram_data, rom_data : std_logic_vector(7 downto 0);
	signal mem_we, ram_cs, ram_lb, ram_ub : std_logic;
	signal bank : std_logic_vector(3 downto 0);
	signal dl_addr : std_logic_vector(24 downto 0) := (others => '0');
	signal dl_data : std_logic_vector(7 downto 0) := x"00";
	signal dl_wr : std_logic := '0';
	signal r, g : std_logic_vector(2 downto 0);
	signal b : std_logic_vector(1 downto 0);
	signal background_seen : boolean := false;
	signal edge_check, edge_seen, edge_left, edge_right : boolean := false;
begin
	clock <= not clock after 5 ns;
	ba <= not halt_n;
	mem_in <= ram_data when ram_cs = '0' else rom_data;

	dut : entity work.williams_cpu
	port map(
		clock => clock, blitter_sc2 => '1', sinistar => '0', blaster => blaster,
		blaster_stereo => stereo, BLASTER_FIRE => fire, ROM_BANK => bank,
		A => a, Dout => dout, Din => din, RESET_N => reset_n,
		NMI_N => open, FIRQ_N => open, IRQ_N => open, LIC => '0', AVMA => '1',
		R_W_N => rw, TSC => open, HALT_N => halt_n, BA => ba, BS => ba, BUSY => '0',
		E => e, Q => q, MemWR => mem_we, RamCS => ram_cs, RamLB => ram_lb, RamUB => ram_ub,
		MemAdr => mem_addr, MemDin => mem_out, MemDout => mem_in, LED => open,
		SW => x"00", BTN => btn, vgaRed => r, vgaGreen => g, vgaBlue => b,
		Hsync => open, Vsync => open, JA => x"88", JB => x"FF",
		SIN_FIRE => fire, SIN_BOMB => fire, HAND => open, PB => open,
		dl_clock => clock, dl_addr => dl_addr, dl_data => dl_data, dl_wr => dl_wr
	);

	rom : entity work.williams_rom
	port map(clock, game, mem_addr, bank, rom_data, clock, dl_addr, dl_data, dl_wr);

	ram : entity work.williams_ram
	port map(
		CLK => not clock, ENL => not ram_lb, ENH => not ram_ub,
		WE => not ram_cs and not mem_we, ADDR => mem_addr, DI => mem_out, DO => ram_data,
		game => game, dn_clock => clock, dn_addr => dl_addr, dn_data => dl_data,
		dn_wr => dl_wr, dn_din => open, dn_nvram => '0'
	);

	process(clock)
	begin
		if falling_edge(clock) and (b & g & r) = x"A3" then
			background_seen <= true;
		end if;
	end process;
	process(clock)
	begin
		if falling_edge(clock) then
			if not edge_check then
				edge_seen <= false;
				edge_left <= false;
				edge_right <= false;
			else
				if (b & g & r) = x"38" then edge_seen <= true; end if;
				if (b & g & r) = x"07" then edge_left <= true; end if;
				if (b & g & r) = x"C0" then edge_right <= true; end if;
			end if;
		end if;
	end process;

	process
		file image_file : text open read_mode is rom_file;
		type image_t is array(0 to 16#5FFFF#) of std_logic_vector(7 downto 0);
		variable image : image_t;
		variable line_in : line;
		variable value : std_logic_vector(7 downto 0);
		variable expected : std_logic_vector(7 downto 0);
		procedure bus_write(addr : integer; data : std_logic_vector(7 downto 0)) is
		begin
			wait until falling_edge(e);
			a <= std_logic_vector(to_unsigned(addr, 16));
			dout <= data;
			rw <= '0';
			wait until falling_edge(e);
			rw <= '1';
		end procedure;
		procedure bus_check(addr : integer; expected : std_logic_vector(7 downto 0)) is
		begin
			wait until falling_edge(e);
			a <= std_logic_vector(to_unsigned(addr, 16));
			rw <= '1';
			wait until falling_edge(e);
			assert din = expected report "Read mismatch at " & integer'image(addr) & ": " & to_hstring(din) & " expected " & to_hstring(expected) severity failure;
		end procedure;
	begin
		for i in image'range loop
			readline(image_file, line_in);
			hread(line_in, image(i));
			wait until falling_edge(clock);
			dl_addr <= std_logic_vector(to_unsigned(i, 25));
			dl_data <= image(i);
			dl_wr <= '1';
		end loop;
		wait until rising_edge(clock);
		wait for 1 ns;
		dl_wr <= '0';
		btn <= "0000";
		wait until reset_n = '1';
		bus_check(16#CC00#, x"F0");
		bus_check(16#D000#, image(16#9000#));
		bus_write(16#C900#, x"01");
		for i in 0 to 15 loop
			bus_write(16#C980#, std_logic_vector(to_unsigned(i, 8)));
			bus_check(0, image(16#20000# + i * 16384));
			bus_check(16#3FFF#, image(16#23FFF# + i * 16384));
		end loop;
		bus_write(16#C940#, x"FF");
		bus_write(16#C9FF#, x"00");
		bus_check(0, image(16#5C000#));
		bus_write(0, x"A5");
		bus_check(0, image(16#5C000#));
		bus_write(16#C900#, x"00");
		bus_check(0, x"A5");
		bus_write(16#CC00#, x"AB");
		bus_check(16#CC00#, x"FB");
		bus_write(16#C805#, x"04");
		bus_write(16#C807#, x"3C");
		bus_check(16#C804#, x"77");
		bus_write(16#C807#, x"34");
		bus_check(16#C804#, x"00");
		btn <= "1100";
		fire <= '0';
		bus_check(16#C804#, x"0F");
		bus_check(16#C806#, x"01");
		stereo <= '1';
		game <= x"09";
		bus_check(16#C804#, x"77");
		bus_check(16#C806#, x"37");
		bus_write(16#C807#, x"3C");
		bus_check(16#C804#, x"00");
		bus_check(16#C806#, x"30");
		stereo <= '0';
		game <= x"08";
		btn <= "0000";
		fire <= '1';
		bus_write(16#C980#, x"07");
		bus_write(16#C900#, x"01");
		for s in 0 to 127 loop
			bus_write(16#C940#, std_logic_vector(to_unsigned(s, 8)));
			bus_write(16#CA02#, x"00");
			bus_write(16#CA03#, x"00");
			bus_write(16#CA04#, x"90");
			bus_write(16#CA05#, x"00");
			bus_write(16#CA06#, x"01");
			bus_write(16#CA07#, x"01");
			bus_write(16#CA00#, x"00");
			if halt_n /= '0' then wait until halt_n = '0' for 10 us; end if;
			assert halt_n = '0' report "Blitter did not start" severity failure;
			wait until halt_n = '1' for 10 us;
			assert halt_n = '1' report "Blitter did not finish" severity failure;
			value := image(16#3C000#);
			expected(7 downto 4) := image(16#12000# + s * 16 + to_integer(unsigned(value(7 downto 4))))(3 downto 0);
			expected(3 downto 0) := image(16#12000# + s * 16 + to_integer(unsigned(value(3 downto 0))))(3 downto 0);
			bus_check(16#9000#, expected);
		end loop;
		bus_write(16#C900#, x"00");
		for i in 0 to 15 loop
			bus_write(16#C000# + i, x"22");
		end loop;
		bus_write(16#BB00#, x"FF");
		bus_write(16#BB0A#, x"7E");
		bus_write(16#BC0A#, x"03");
		bus_write(16#030A#, x"12");
		bus_write(16#020A#, x"EF");
		bus_write(16#950A#, x"17");
		bus_write(16#C9C0#, x"03");
		wait for 5 ms;
		bus_check(16#030A#, x"00");
		bus_check(16#020A#, x"EF");
		bus_check(16#950A#, x"17");
		bus_check(16#BB0A#, x"7E");
		bus_check(16#BC0A#, x"03");
		assert background_seen report "Scanline background missing" severity failure;
		bus_write(16#C9C0#, x"01");
		bus_write(16#030A#, x"77");
		wait for 3 ms;
		bus_check(16#030A#, x"77");
		bus_write(16#C9C0#, x"00");
		bus_write(16#BB00#, x"FF");
		for i in 0 to 15 loop
			bus_write(16#C000# + i, x"00");
		end loop;
		bus_write(16#C00E#, x"38");
		bus_write(16#C00F#, x"07");
		bus_write(16#C00D#, x"C0");
		bus_write(16#CA01#, x"00");
		bus_write(16#CA02#, x"00");
		bus_write(16#CA03#, x"00");
		bus_write(16#CA04#, x"03");
		bus_write(16#CA05#, x"07");
		bus_write(16#CA06#, x"92");
		bus_write(16#CA07#, x"F0");
		bus_write(16#CA00#, x"12");
		if halt_n /= '0' then wait until halt_n = '0' for 10 us; end if;
		assert halt_n = '0' severity failure;
		wait until halt_n = '1' for 10 ms;
		assert halt_n = '1' severity failure;
		bus_write(16#020A#, x"EE");
		bus_write(16#030A#, x"FF");
		bus_write(16#940A#, x"DD");
		bus_write(16#950A#, x"EE");
		edge_check <= true;
		wait for 4 ms;
		assert edge_left and edge_right report "Blaster visible edge pixels missing" severity failure;
		assert not edge_seen report "Blaster displayed pixels outside its visible window" severity failure;
		edge_check <= false;
		wait for 100 ns;
		blaster <= '0';
		game <= x"00";
		wait until falling_edge(clock);
		dl_addr <= (others => '0');
		dl_data <= image(0);
		dl_wr <= '1';
		wait until rising_edge(clock);
		wait for 1 ns;
		dl_wr <= '0';
		edge_check <= true;
		wait for 4 ms;
		assert edge_seen report "Legacy visible window changed" severity failure;
		assert edge_left and edge_right report "Legacy edge pixels missing" severity failure;
		edge_check <= false;
		bus_write(16#CC00#, x"12");
		bus_check(16#CC00#, x"12");
		bus_write(16#C9FF#, x"01");
		bus_check(0, image(0));
		report "Blaster board tests passed" severity note;
		std.env.finish;
		wait;
	end process;
end test;
