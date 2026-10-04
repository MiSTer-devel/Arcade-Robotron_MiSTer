library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

entity blaster_sound_tb is end;

architecture test of blaster_sound_tb is
	type rom_t is array(0 to 4095) of std_logic_vector(7 downto 0);
	constant image : rom_t := (
		0 => x"8E", 1 => x"00", 2 => x"FF",
		3 => x"86", 4 => x"A5", 5 => x"97", 6 => x"00",
		7 => x"86", 8 => x"5A", 9 => x"97", 10 => x"80",
		11 => x"86", 12 => x"FF", 13 => x"B7", 14 => x"04", 15 => x"00",
		16 => x"86", 17 => x"04", 18 => x"B7", 19 => x"04", 20 => x"01",
		21 => x"96", 22 => x"00", 23 => x"B7", 24 => x"04", 25 => x"00",
		26 => x"86", 27 => x"04", 28 => x"B7", 29 => x"04", 30 => x"03",
		31 => x"B6", 32 => x"04", 33 => x"02", 34 => x"B7", 35 => x"04", 36 => x"00",
		37 => x"20", 38 => x"F8",
		4094 => x"F0", 4095 => x"00", others => x"01"
	);
	signal clock : std_logic := '0';
	signal reset : std_logic := '1';
	signal blaster : std_logic := '1';
	signal hand, select_board : std_logic := '1';
	signal command : std_logic_vector(5 downto 0) := "111111";
	signal audio, data : std_logic_vector(7 downto 0);
	signal address : std_logic_vector(13 downto 0);
	signal vma : std_logic;
begin
	clock <= not clock after 5 ns;
	process(clock)
	begin
		if rising_edge(clock) then
			data <= image(to_integer(unsigned(address(11 downto 0))));
		end if;
	end process;
	dut : entity work.williams_sound_board
	port map(clock, reset, hand, command, select_board, blaster, audio, open, address, data, x"55", vma);

	process
		procedure expect(value : std_logic_vector(7 downto 0)) is
		begin
			wait until audio = value for 100 us;
			assert audio = value report "Sound PIA output: " & to_hstring(audio) & " expected " & to_hstring(value) severity failure;
		end procedure;
	begin
		wait for 100 ns;
		reset <= '0';
		expect(x"A5");
		expect(x"FF");
		command <= "010101";
		expect(x"D5");
		select_board <= '0';
		expect(x"95");
		hand <= '0';
		expect(x"15");
		reset <= '1';
		blaster <= '0';
		wait for 100 ns;
		reset <= '0';
		expect(x"5A");
		expect(x"15");
		report "Blaster sound board tests passed" severity note;
		std.env.finish;
		wait;
	end process;
end test;
