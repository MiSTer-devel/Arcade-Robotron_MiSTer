library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;
	use ieee.std_logic_textio.all;
library std;
	use std.textio.all;

entity blaster_boot_tb is
generic(
	rom_file : string := "blasterkit.hex";
	game_number : integer := 8;
	frame_limit : integer := 2200
);
end;

architecture test of blaster_boot_tb is
	component mc6809is is
	port (
		clk : in std_logic;
		D : in std_logic_vector(7 downto 0);
		Dout : out std_logic_vector(7 downto 0);
		ADDR : out std_logic_vector(15 downto 0);
		RnW : out std_logic;
		E, Q : in std_logic;
		BS, BA : out std_logic;
		nIRQ, nFIRQ, nNMI : in std_logic := '1';
		AVMA, BUSY, LIC : out std_logic;
		nHALT, nRESET, nDMABREQ : in std_logic := '1';
		RegData : out std_logic_vector(111 downto 0)
	);
	end component;
	signal cpu_a : std_logic_vector(15 downto 0);
	signal cpu_registers : std_logic_vector(111 downto 0);
	signal cpu_do, cpu_di : std_logic_vector(7 downto 0);
	signal cpu_rw, cpu_e, cpu_q, cpu_bs, cpu_ba : std_logic;
	signal cpu_reset_n, cpu_irq_n, cpu_firq_n, cpu_nmi_n, cpu_halt_n : std_logic;
	signal stereo : std_logic;
	signal clock : std_logic := '0';
	signal game : std_logic_vector(7 downto 0);
	signal btn : std_logic_vector(3 downto 0) := "0001";
	signal sw : std_logic_vector(7 downto 0) := x"00";
	signal mem_addr : std_logic_vector(15 downto 0);
	signal mem_in, mem_out, ram_data, rom_data : std_logic_vector(7 downto 0);
	signal mem_we, ram_cs, ram_lb, ram_ub : std_logic;
	signal bank : std_logic_vector(3 downto 0);
	signal dl_addr : std_logic_vector(24 downto 0) := (others => '0');
	signal dl_data : std_logic_vector(7 downto 0) := x"00";
	signal dl_wr : std_logic := '0';
	signal r, g : std_logic_vector(2 downto 0);
	signal b : std_logic_vector(1 downto 0);
	signal hs, vs : std_logic;
	signal audio_l, audio_r : std_logic_vector(7 downto 0);
	signal ready : boolean := false;
begin
	clock <= not clock after 5 ns;
	game <= std_logic_vector(to_unsigned(game_number, 8));
	stereo <= '1' when game_number = 9 else '0';
	mem_in <= ram_data when ram_cs = '0' else rom_data;

	cpu : mc6809is
	port map(
		clk => not clock, D => cpu_di, Dout => cpu_do, ADDR => cpu_a, RnW => cpu_rw,
		E => cpu_e, Q => cpu_q, BS => cpu_bs, BA => cpu_ba,
		nIRQ => cpu_irq_n, nFIRQ => cpu_firq_n, nNMI => cpu_nmi_n,
		AVMA => open, BUSY => open, LIC => open, nHALT => cpu_halt_n, nRESET => cpu_reset_n,
		RegData => cpu_registers
	);

	dut : entity work.williams_cpu
	port map(
		clock => clock, MemWR => mem_we, RamCS => ram_cs, RamLB => ram_lb, RamUB => ram_ub,
		MemAdr => mem_addr, MemDin => mem_out, MemDout => mem_in,
		blitter_sc2 => '1', sinistar => '0', blaster => '1', blaster_stereo => stereo,
		BLASTER_FIRE => '1', ROM_BANK => bank, SW => sw, BTN => btn,
		A => cpu_a, Dout => cpu_do, Din => cpu_di, R_W_N => cpu_rw,
		E => cpu_e, Q => cpu_q, BS => cpu_bs, BA => cpu_ba, BUSY => '0', LIC => '0', AVMA => '1',
		RESET_N => cpu_reset_n, IRQ_N => cpu_irq_n, FIRQ_N => cpu_firq_n, NMI_N => cpu_nmi_n,
		HALT_N => cpu_halt_n, TSC => open, LED => open,
		SIN_FIRE => '1', SIN_BOMB => '1', vgaRed => r, vgaGreen => g, vgaBlue => b,
		Hsync => hs, Vsync => vs, JA => x"88", JB => x"FF", HAND => open, PB => open,
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

	process
		file image_file : text open read_mode is rom_file;
		variable line_in : line;
		variable value : std_logic_vector(7 downto 0);
		variable addr : integer := 0;
	begin
		while not endfile(image_file) loop
			readline(image_file, line_in);
			hread(line_in, value);
			wait until falling_edge(clock);
			dl_addr <= std_logic_vector(to_unsigned(addr, 25));
			dl_data <= value;
			dl_wr <= '1';
			addr := addr + 1;
		end loop;
		wait until rising_edge(clock);
		wait for 1 ns;
		dl_wr <= '0';
		btn <= "0000";
		ready <= true;
		wait;
	end process;

	process
		file capture : text;
		variable row : line;
		variable writes : integer := 0;
		variable status : file_open_status;
	begin
		wait until ready;
		for frame in 1 to frame_limit loop
			wait until falling_edge(vs);
			if frame mod 300 = 0 then
				report "Frame " & integer'image(frame) & " PC " & to_hstring(cpu_registers(111 downto 96)) severity note;
			end if;
			if frame = 1800 then
				sw(1) <= '1';
			elsif frame = 1802 then
				sw(1) <= '0';
			end if;
			if frame = 30 or frame = 900 or frame = 1800 or frame = frame_limit then
				file_open(status, capture, "frame_" & integer'image(game_number) & "_" & integer'image(frame) & ".ppm", write_mode);
				assert status = open_ok severity failure;
				write(row, string'("P3")); writeline(capture, row);
				write(row, string'("384 260")); writeline(capture, row);
				write(row, string'("255")); writeline(capture, row);
				for pixel in 0 to 384 * 260 - 1 loop
					wait until falling_edge(clock);
					wait until falling_edge(clock);
					if not is_x(r & g & b) then
						write(row, to_integer(unsigned(r)) * 255 / 7);
						write(row, string'(" "));
						write(row, to_integer(unsigned(g)) * 255 / 7);
						write(row, string'(" "));
						write(row, to_integer(unsigned(b)) * 255 / 3);
					else
						write(row, string'("0 0 0"));
					end if;
					writeline(capture, row);
				end loop;
				file_close(capture);
				report "Captured frame " & integer'image(frame) severity note;
			end if;
		end loop;
		report "Blaster boot capture complete" severity note;
		std.env.finish;
		wait;
	end process;
end test;
