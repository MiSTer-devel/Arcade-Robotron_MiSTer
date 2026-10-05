library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

entity blaster_audio_tb is end;

architecture test of blaster_audio_tb is
	signal clock : std_logic := '0';
	signal reset : std_logic := '1';
	signal game : std_logic_vector(7 downto 0) := x"09";
	signal mono, left_out, right_out : std_logic_vector(15 downto 0);
	signal dac_l, dac_r : std_logic_vector(7 downto 0) := x"00";
	signal ce : std_logic;
	signal in_clk : integer := 48000000;
	signal out_clk : integer := 3579545;
begin
	clock <= not clock after 5 ns;
	dut : entity work.williams_audio
	port map(clock, reset, game, mono, dac_l, dac_r, left_out, right_out);
	divider : entity work.CEGen
	port map(clock, not reset, in_clk, out_clk, ce);

	process
		procedure clocks(n : integer) is
		begin
			for i in 1 to n loop
				wait until rising_edge(clock);
				wait for 1 ns;
			end loop;
		end procedure;
		variable pulses : integer;
	begin
		clocks(3);
		assert left_out = x"2000" and right_out = x"2000" report "Audio reset level" severity failure;
		reset <= '0';
		dac_l <= x"FF";
		clocks(513);
		assert unsigned(left_out) > 16#2000# report "Left DAC missing" severity failure;
		assert right_out = x"2000" report "Left DAC leaked into right channel" severity failure;
		game <= x"08";
		wait for 1 ns;
		assert right_out = left_out report "Kit audio is not mono" severity failure;
		game <= x"09";
		reset <= '1';
		clocks(3);
		dac_l <= x"00";
		dac_r <= x"FF";
		reset <= '0';
		clocks(513);
		assert unsigned(right_out) > 16#2000# report "Right DAC missing" severity failure;
		assert left_out = x"2000" report "Right DAC leaked into left channel" severity failure;
		clocks(256 * 700);
		assert abs(to_integer(unsigned(right_out)) - 16#2000#) <= 2 report "DC does not decay" severity failure;
		for mode in 0 to 7 loop
			game <= std_logic_vector(to_unsigned(mode, 8));
			for value in 0 to 255 loop
				mono <= std_logic_vector(to_unsigned(value * 257, 16));
				wait for 1 ns;
				assert left_out = mono and right_out = mono report "Legacy audio changed" severity failure;
			end loop;
		end loop;
		reset <= '1';
		clocks(3);
		reset <= '0';
		pulses := 0;
		for i in 1 to 48000 loop
			wait until falling_edge(clock);
			wait for 1 ns;
			if ce = '1' then pulses := pulses + 1; end if;
		end loop;
		assert pulses = 3579 report "Blaster sound clock rate" severity failure;
		in_clk <= 1200;
		out_clk <= 89;
		reset <= '1';
		clocks(3);
		reset <= '0';
		pulses := 0;
		for i in 1 to 12000 loop
			wait until falling_edge(clock);
			wait for 1 ns;
			if ce = '1' then pulses := pulses + 1; end if;
		end loop;
		assert pulses = 890 report "Legacy sound clock rate changed" severity failure;
		report "Blaster audio tests passed" severity note;
		std.env.finish;
		wait;
	end process;
end test;
