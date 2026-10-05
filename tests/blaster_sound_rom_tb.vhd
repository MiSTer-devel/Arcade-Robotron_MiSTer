library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;
	use ieee.std_logic_textio.all;
library std;
	use std.textio.all;

entity blaster_sound_rom_tb is
generic(rom_file : string := "blasterkit.hex");
end;

architecture test of blaster_sound_rom_tb is
	type rom_t is array(0 to 4095) of std_logic_vector(7 downto 0);
	signal image : rom_t;
	signal clock : std_logic := '0';
	signal reset : std_logic := '1';
	signal command : std_logic_vector(5 downto 0) := "111111";
	signal audio, data : std_logic_vector(7 downto 0);
	signal address : std_logic_vector(13 downto 0);
	signal changes : integer := 0;
begin
	clock <= not clock after 5 ns;
	process(clock)
		variable previous : std_logic_vector(7 downto 0);
	begin
		if rising_edge(clock) then
			data <= image(to_integer(unsigned(address(11 downto 0))));
			if reset = '1' then
				changes <= 0;
			elsif audio /= previous and not is_x(audio) then
				changes <= changes + 1;
			end if;
			previous := audio;
		end if;
	end process;
	dut : entity work.williams_sound_board
	port map(clock, reset, '1', command, '1', '1', audio, open, address, data, x"55", open);

	process
		file packet : text open read_mode is rom_file;
		variable row : line;
		variable value : std_logic_vector(7 downto 0);
	begin
		for i in 0 to 16#CFFF# loop
			readline(packet, row);
			hread(row, value);
			if i >= 16#C000# then image(i - 16#C000#) <= value; end if;
		end loop;
		for effect in 1 to 3 loop
			reset <= '1';
			command <= "111111";
			wait for 100 ns;
			reset <= '0';
			wait for 50 us;
			command <= not std_logic_vector(to_unsigned(effect, 6));
			wait for 10 ms;
			assert changes > 20 report "Sound ROM did not produce DAC samples for command " & integer'image(effect) severity failure;
		end loop;
		report "Blaster sound ROM tests passed" severity note;
		std.env.finish;
		wait;
	end process;
end test;
