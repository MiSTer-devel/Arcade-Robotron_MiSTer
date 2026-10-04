library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

entity blaster_rom_tb is end;

architecture test of blaster_rom_tb is
	signal clock   : std_logic := '0';
	signal game    : std_logic_vector(7 downto 0) := x"08";
	signal address : std_logic_vector(15 downto 0) := x"0000";
	signal bank    : std_logic_vector(3 downto 0) := x"0";
	signal data    : std_logic_vector(7 downto 0);
	signal dl_addr : std_logic_vector(24 downto 0) := (others => '0');
	signal dl_data : std_logic_vector(7 downto 0) := x"00";
	signal dl_wr   : std_logic := '0';
begin
	clock <= not clock after 5 ns;

	dut : entity work.williams_rom
	port map(clock, game, address, bank, data, clock, dl_addr, dl_data, dl_wr);

	process
		function pattern(a : integer) return integer is
		begin
			return (a * 13 + a / 256 * 7 + a / 16384 * 19) mod 256;
		end function;
		procedure load(a, d : integer) is
		begin
			wait until falling_edge(clock);
			dl_addr <= std_logic_vector(to_unsigned(a, 25));
			dl_data <= std_logic_vector(to_unsigned(d, 8));
			dl_wr <= '1';
			wait until rising_edge(clock);
			wait for 1 ns;
			dl_wr <= '0';
		end procedure;
		procedure check(a, d : integer) is
		begin
			address <= std_logic_vector(to_unsigned(a, 16));
			wait until falling_edge(clock);
			wait for 1 ns;
			assert data = std_logic_vector(to_unsigned(d, 8))
				report "ROM mismatch at " & integer'image(a) & " bank " & to_hstring(bank) severity failure;
		end procedure;
	begin
		for i in 0 to 7 loop
			game <= std_logic_vector(to_unsigned(i, 8));
			for a in 0 to 16#BFFF# loop
				load(a, (pattern(a) + i) mod 256);
			end loop;
			load(16#C000#, 16#EE#);
			load(16#10000#, 16#EE#);
			load(16#200000#, 16#EE#);
			for a in 0 to 16#BFFF# loop
				check(a, (pattern(a) + i) mod 256);
			end loop;
			for a in 16#C000# to 16#FFFF# loop
				check(a, (pattern(a - 16#4000#) + i) mod 256);
			end loop;
		end loop;
		for g in 8 to 9 loop
			for a in 0 to 16#BFFF# loop
				load(a, pattern(a));
			end loop;
			for a in 16#20000# to 16#4FFFF# loop
				load(a, pattern(a));
			end loop;
			load(16#50000#, 16#EE#);
			load(16#5FFFF#, 16#EE#);
			load(16#60000#, 16#EE#);
			load(16#204000#, 16#EE#);
			game <= std_logic_vector(to_unsigned(g, 8));
			for i in 0 to 15 loop
				bank <= std_logic_vector(to_unsigned(i, 4));
				for a in 0 to 16#3FFF# loop
					if i < 12 then
						check(a, pattern(16#20000# + i * 16384 + a));
					else
						check(a, 0);
					end if;
				end loop;
				check(16#4000#, pattern(16#4000#));
				check(16#8000#, pattern(16#8000#));
				check(16#D000#, pattern(16#9000#));
				check(16#FFFF#, pattern(16#BFFF#));
			end loop;
			for a in 16#4000# to 16#BFFF# loop
				check(a, pattern(a));
			end loop;
			for a in 16#C000# to 16#FFFF# loop
				check(a, pattern(a - 16#4000#));
			end loop;
		end loop;
		load(0, 16#5A#);
		game <= x"00";
		check(0, 16#5A#);
		report "Blaster ROM tests passed" severity note;
		std.env.finish;
		wait;
	end process;
end test;
