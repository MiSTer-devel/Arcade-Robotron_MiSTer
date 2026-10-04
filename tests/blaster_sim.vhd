library ieee;
	use ieee.std_logic_1164.all;

entity blaster_sim is
port (
	clock      : in  std_logic;
	reset      : in  std_logic;
	game       : in  std_logic_vector(7 downto 0);
	buttons    : in  std_logic_vector(3 downto 0);
	fire       : in  std_logic_vector(2 downto 0);
	switches   : in  std_logic_vector(7 downto 0);
	joy_x      : in  std_logic_vector(3 downto 0);
	joy_y      : in  std_logic_vector(3 downto 0);
	dl_addr    : in  std_logic_vector(24 downto 0);
	dl_data    : in  std_logic_vector(7 downto 0);
	dl_wr      : in  std_logic;
	red        : out std_logic_vector(2 downto 0);
	green      : out std_logic_vector(2 downto 0);
	blue       : out std_logic_vector(1 downto 0);
	hs, vs     : out std_logic;
	audio_l    : out std_logic_vector(15 downto 0);
	audio_r    : out std_logic_vector(15 downto 0)
);
end;

architecture test of blaster_sim is
	signal address : std_logic_vector(15 downto 0);
	signal memory_in, memory_out, ram_data, rom_data : std_logic_vector(7 downto 0);
	signal ram_cs, ram_lb, ram_ub, memory_we : std_logic;
	signal bank : std_logic_vector(3 downto 0);
	signal dac_l, dac_r : std_logic_vector(7 downto 0);
begin
	memory_in <= ram_data when ram_cs = '0' else rom_data;
	soc : entity work.williams_soc
	port map(
		clock => clock, MemWR => memory_we, RamCS => ram_cs, RamLB => ram_lb, RamUB => ram_ub,
		MemAdr => address, MemDin => memory_out, MemDout => memory_in,
		blitter_sc2 => '1', sinistar => '0', game => game, ROM_BANK => bank,
		JOY_X => joy_x, JOY_Y => joy_y, DIGITAL_X => x"7", DIGITAL_Y => x"7",
		BLASTER_BTN => buttons(3 downto 1) & fire(2), sg_state => open,
		SW => switches, BTN => buttons(3 downto 1) & reset,
		SIN_FIRE => not fire(0), SIN_BOMB => not fire(1),
		vgaRed => red, vgaGreen => green, vgaBlue => blue, Hsync => hs, Vsync => vs,
		audio_out => dac_l, audio_out_r => dac_r, speech_out => open,
		JA => x"FF", JB => x"FF", pause => '0',
		dl_clock => clock, dl_addr => dl_addr, dl_data => dl_data, dl_wr => dl_wr, dl_upload => '0'
	);
	rom : entity work.williams_rom
	port map(clock, game, address, bank, rom_data, clock, dl_addr, dl_data, dl_wr);
	ram : entity work.williams_ram
	port map(
		CLK => not clock, ENL => not ram_lb, ENH => not ram_ub,
		WE => not ram_cs and not memory_we, ADDR => address, DI => memory_out, DO => ram_data,
		game => game, dn_clock => clock, dn_addr => dl_addr, dn_data => dl_data,
		dn_wr => dl_wr, dn_din => open, dn_nvram => '0'
	);
	audio : entity work.williams_audio
	port map(clock, reset, game, x"0000", dac_l, dac_r, audio_l, audio_r);
end test;
