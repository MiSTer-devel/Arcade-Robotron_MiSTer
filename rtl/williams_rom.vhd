library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

entity williams_rom is
port (
	clock      : in  std_logic;
	game       : in  std_logic_vector(7 downto 0);
	address    : in  std_logic_vector(15 downto 0);
	bank       : in  std_logic_vector(3 downto 0);
	data       : out std_logic_vector(7 downto 0);
	dl_clock   : in  std_logic;
	dl_addr    : in  std_logic_vector(24 downto 0);
	dl_data    : in  std_logic_vector(7 downto 0);
	dl_wr      : in  std_logic
);
end williams_rom;

architecture RTL of williams_rom is
	signal blaster    : std_logic;
	signal fixed_addr : std_logic_vector(15 downto 0);
	signal low_addr   : std_logic_vector(16 downto 0);
	signal low_data, high_data, fixed_data : std_logic_vector(7 downto 0);
	signal low_we, high_we, fixed_we : std_logic;
	signal rom_sel    : std_logic_vector(1 downto 0);
begin
	blaster <= '1' when game = x"08" or game = x"09" else '0';
	fixed_addr <= address(15) & (not address(15) and address(14)) & address(13 downto 0);
	low_addr <= bank(2 downto 0) & address(13 downto 0) when blaster = '1' else '0' & fixed_addr;
	low_we <= dl_wr when unsigned(dl_addr) < 16#C000# or
		(unsigned(dl_addr) >= 16#20000# and unsigned(dl_addr) < 16#40000#) else '0';
	high_we <= dl_wr when unsigned(dl_addr) >= 16#40000# and unsigned(dl_addr) < 16#50000# else '0';
	fixed_we <= dl_wr when unsigned(dl_addr) >= 16#4000# and unsigned(dl_addr) < 16#C000# else '0';

	low_rom : entity work.dpram
	generic map( dWidth => 8, aWidth => 17)
	port map(
		clk_a  => not clock,
		addr_a => low_addr,
		q_a    => low_data,
		clk_b  => dl_clock,
		we_b   => low_we,
		addr_b => dl_addr(16 downto 0),
		d_b    => dl_data
	);

	high_rom : entity work.dpram
	generic map( dWidth => 8, aWidth => 16)
	port map(
		clk_a  => not clock,
		addr_a => bank(1 downto 0) & address(13 downto 0),
		q_a    => high_data,
		clk_b  => dl_clock,
		we_b   => high_we,
		addr_b => dl_addr(15 downto 0),
		d_b    => dl_data
	);

	fixed_rom : entity work.dpram
	generic map( dWidth => 8, aWidth => 15)
	port map(
		clk_a  => not clock,
		addr_a => std_logic_vector(unsigned(fixed_addr(14 downto 0)) - 16#4000#),
		q_a    => fixed_data,
		clk_b  => dl_clock,
		we_b   => fixed_we,
		addr_b => std_logic_vector(unsigned(dl_addr(14 downto 0)) - 16#4000#),
		d_b    => dl_data
	);

	process(clock)
	begin
		if falling_edge(clock) then
			if blaster = '0' then
				rom_sel <= "00";
			elsif address(15 downto 14) /= "00" then
				rom_sel <= "10";
			elsif bank(3) = '0' then
				rom_sel <= "00";
			elsif bank(2) = '0' then
				rom_sel <= "01";
			else
				rom_sel <= "11";
			end if;
		end if;
	end process;

	with rom_sel select data <=
		low_data   when "00",
		high_data  when "01",
		fixed_data when "10",
		x"00"      when others;
end RTL;
