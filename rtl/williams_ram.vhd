-- Williams memory for later boards (DW oldgit)
-- Dec 2018
library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_unsigned.all;
	use ieee.numeric_std.all;

entity williams_ram is
port (
	CLK      : in  std_logic;
	ENL      : in  std_logic;
	ENH      : in  std_logic;
	WE       : in  std_logic;
	ADDR     : in  std_logic_vector(15 downto 0);
	DI       : in  std_logic_vector( 7 downto 0);
	DO       : out std_logic_vector( 7 downto 0);

	dn_clock : in  std_logic;
	dn_addr	: in  std_logic_vector(15 downto 0);
	dn_data	: in  std_logic_vector(7 downto 0);
	dn_wr	   : in  std_logic;
   dn_din   : out  std_logic_vector(7 downto 0);
   dn_nvram : in  std_logic

	);
end;

architecture RTL of williams_ram is
	signal dl_cs, cmos_cs : std_logic;
	signal ram_out, cmos_out, ram_data : std_logic_vector(7 downto 0);
begin

	-- cpu/video wram low
	cpu_video_low : entity work.gen_ram
	generic map( dWidth => 4, aWidth => 16)
	port map(
		clk  => CLK,
		we   => ENL and WE,
		addr => ADDR(15 downto 0),
		d    => DI(3 downto 0),
		q    => ram_out(3 downto 0)
	);

	cpu_video_high : entity work.gen_ram
	generic map( dWidth => 4, aWidth => 16)
	port map(
		clk  => CLK,
		we   => ENH and WE,
		addr => ADDR(15 downto 0),
		d    => DI(7 downto 4),
		q    => ram_out(7 downto 4)
	);
			   

	ram_data(7 downto 4) <= ram_out(7 downto 4) when ENH = '1' else "0000";
	ram_data(3 downto 0) <= ram_out(3 downto 0) when ENL = '1' else "0000";
	
	cmos_cs  <= '1' when ADDR(15 downto 10) = "110011" else '0';
	dl_cs <= '1' when (dn_addr(15 downto 10) = "110100") or (dn_nvram='1') else '0';
	
	
	
	-- cmos ram 
	cmos_ram : entity work.dpram
	generic map( dWidth => 8, aWidth => 10)
	port map
	(
		clk_a   => dn_clock,
		we_a    => dn_wr and dl_cs,
		addr_a  => dn_addr(9 downto 0),
		d_a     => dn_data,
		q_a     => dn_din,
	
		clk_b   => CLK,
		addr_b  => ADDR(9 downto 0),
		d_b     => DI,
		we_b    => cmos_cs and WE,
		q_b     => cmos_out
	);

	DO  <= cmos_out when cmos_cs = '1' else ram_data;

end RTL;	