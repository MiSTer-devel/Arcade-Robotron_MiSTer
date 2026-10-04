library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

entity blaster_sc1_tb is end;

architecture test of blaster_sc1_tb is
	signal clock : std_logic := '0';
	signal reg_cs : std_logic := '0';
	signal reg_data : std_logic_vector(7 downto 0) := x"00";
	signal rs : std_logic_vector(2 downto 0) := "000";
	signal halt, rd, wr, en_upper, en_lower, slow : boolean;
	signal ack : std_logic := '0';
	signal address : std_logic_vector(15 downto 0);
	signal data_in : std_logic_vector(7 downto 0) := x"00";
	signal data_out : std_logic_vector(7 downto 0);
	signal remap : std_logic := '1';
	signal remap_sel : std_logic_vector(6 downto 0) := (others => '0');
	signal dl_addr : std_logic_vector(10 downto 0) := (others => '0');
	signal dl_data : std_logic_vector(3 downto 0) := x"0";
	signal dl_wr : std_logic := '0';
	signal win_en : std_logic := '0';

	function mapped(d, s : integer) return std_logic_vector is
		variable n : unsigned(3 downto 0);
	begin
		n := to_unsigned(s mod 16, 4);
		return std_logic_vector((to_unsigned(d / 16, 4) xor n) & (to_unsigned(d mod 16, 4) xor n));
	end function;
begin
	clock <= not clock after 5 ns;

	dut : entity work.sc1
	port map(
		clk => clock, blt_slow => slow, sc2 => '1', clip => x"9700",
		remap => remap, remap_sel => remap_sel, dl_clock => clock,
		dl_addr => dl_addr, dl_data => dl_data, dl_wr => dl_wr,
		reg_cs => reg_cs, reg_data_in => reg_data, rs => rs, win_en => win_en,
		halt => halt, halt_ack => true, blt_ack => ack,
		blt_rd => rd, blt_wr => wr, blt_address_out => address,
		blt_data_in => data_in, blt_data_out => data_out,
		en_upper => en_upper, en_lower => en_lower
	);

	process
		procedure reg_write(r, d : integer) is
		begin
			wait until falling_edge(clock);
			rs <= std_logic_vector(to_unsigned(r, 3));
			reg_data <= std_logic_vector(to_unsigned(d, 8));
			reg_cs <= '1';
			wait until rising_edge(clock);
			wait for 1 ns;
			reg_cs <= '0';
		end procedure;
		procedure start(c, dst, width : integer) is
		begin
			reg_write(2, 16#20#);
			reg_write(3, 0);
			reg_write(4, dst / 256);
			reg_write(5, dst mod 256);
			reg_write(6, width);
			reg_write(7, 1);
			reg_write(0, c);
			wait until rising_edge(clock);
			wait for 1 ns;
			assert rd severity failure;
		end procedure;
		procedure pixel(d : integer; expected : std_logic_vector(7 downto 0); upper, lower, writable : boolean) is
		begin
			data_in <= std_logic_vector(to_unsigned(d, 8));
			ack <= '1';
			wait until rising_edge(clock);
			wait for 1 ns;
			ack <= '0';
			assert data_out = expected report "Remap data mismatch" severity failure;
			assert en_upper = upper and en_lower = lower report "Remap transparency mismatch" severity failure;
			assert wr = writable report "Window mismatch" severity failure;
			data_in <= not std_logic_vector(to_unsigned(d, 8));
			for i in 0 to 2 loop
				wait until rising_edge(clock);
				wait for 1 ns;
				assert data_out = expected report "Remap changed between memory slots" severity failure;
			end loop;
			ack <= '1';
			wait until rising_edge(clock);
			wait for 1 ns;
			ack <= '0';
		end procedure;
		variable expected : std_logic_vector(7 downto 0);
		variable flags : std_logic_vector(2 downto 0);
	begin
		for i in 0 to 2047 loop
			wait until falling_edge(clock);
			dl_addr <= std_logic_vector(to_unsigned(i, 11));
			dl_data <= std_logic_vector(to_unsigned(i mod 16, 4) xor to_unsigned((i / 16) mod 16, 4));
			dl_wr <= '1';
		end loop;
		wait until rising_edge(clock);
		wait for 1 ns;
		dl_wr <= '0';
		reg_write(1, 16#E7#);
		for s in 0 to 127 loop
			remap_sel <= std_logic_vector(to_unsigned(s, 7));
			for d in 0 to 255 loop
				start(0, 16#9000#, 1);
				pixel(d, mapped(d, s), true, true, true);
				assert not halt severity failure;
			end loop;
		end loop;
		remap_sel <= "0000011";
		for c in 0 to 7 loop
			flags := std_logic_vector(to_unsigned(c, 3));
			for d in 0 to 255 loop
				expected := mapped(d, 3);
				start(to_integer(unsigned(flags(2 downto 1))) * 64 + to_integer(unsigned(flags(0 downto 0))) * 8, 16#9000#, 1);
				pixel(d, expected,
				      (flags(2) = '0') xor (flags(0) = '1' and expected(7 downto 4) = x"0"),
				      (flags(1) = '0') xor (flags(0) = '1' and expected(3 downto 0) = x"0"), true);
			end loop;
		end loop;
		start(16#08#, 16#9000#, 1);
		pixel(16#30#, x"03", false, true, true);
		start(16#18#, 16#9000#, 1);
		pixel(16#03#, x"E7", true, false, true);
		start(16#20#, 16#9000#, 2);
		pixel(16#12#, x"02", true, true, true);
		pixel(16#45#, x"17", true, true, true);
		win_en <= '1';
		for a in 0 to 3 loop
			case a is
				when 0 => start(0, 16#96FF#, 1);
				when 1 => start(0, 16#9700#, 1);
				when 2 => start(0, 16#BFFF#, 1);
				when others => start(0, 16#C000#, 1);
			end case;
			pixel(16#12#, x"21", true, true, a = 0 or a = 3);
		end loop;
		win_en <= '0';
		remap <= '0';
		start(0, 16#9000#, 1);
		pixel(16#12#, x"12", true, true, true);
		report "Blaster SC2 tests passed" severity note;
		std.env.finish;
		wait;
	end process;
end test;
