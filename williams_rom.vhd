-- Williams rom for later boards (DW oldgit)
-- Dec 2018
library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_unsigned.all;
	use ieee.numeric_std.all;

entity ROMS is
port (
	CLK  : in  std_logic;
	clk_sys : in  std_logic;
	dn_addr	: in  std_logic_vector(15 downto 0);
	dn_data	: in  std_logic_vector(7 downto 0);
	dn_wr	: in  std_logic;	
	ENA  	: in  std_logic;
	ADDR 	: in  std_logic_vector(15 downto 0);
	DO   	: out std_logic_vector( 7 downto 0)
	);
end;

architecture RTL of ROMS is

	signal roms_addr : std_logic_vector(15 downto 0);
	signal rom_cs    : std_logic;


begin

	roms_addr <= 
	"0000" & ADDR(11 downto 0) when ADDR(15 downto 12) = X"D"  else 
	"0001" & ADDR(11 downto 0) when ADDR(15 downto 12) = X"E"  else 
	"0010" & ADDR(11 downto 0) when ADDR(15 downto 12) = X"F"  else 
	ADDR(15 downto 12) + 3 & ADDR(11 downto 0);
	
	rom_cs <= '0' when dn_addr(15 downto 12) >= X"C" else '1';
	
	cpu_prog_rom : work.dpram generic map (16,8)
port map
(
	clock_a   => clk_sys,
	wren_a    => dn_wr and rom_cs,
	address_a => dn_addr(15 downto 0),
	data_a    => dn_data,

	clock_b   => CLK,
	address_b => roms_addr(15 downto 0),
	q_b       => DO
);

end RTL;