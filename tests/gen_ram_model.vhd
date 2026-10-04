library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

architecture simulation of gen_ram is
	type ram_t is array(0 to 2**aWidth - 1) of std_logic_vector(dWidth - 1 downto 0);
begin
	process(clk)
		variable ram : ram_t;
	begin
		if rising_edge(clk) then
			if we = '1' then
				ram(to_integer(unsigned(addr))) := d;
			end if;
			q <= ram(to_integer(unsigned(addr)));
		end if;
	end process;
end simulation;
