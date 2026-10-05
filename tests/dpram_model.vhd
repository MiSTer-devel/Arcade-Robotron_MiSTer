library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

architecture simulation of dpram is
	type ram_t is array(0 to 2**aWidth - 1) of std_logic_vector(dWidth - 1 downto 0);
begin
	process(clk_a, clk_b)
		variable ram : ram_t;
	begin
		if rising_edge(clk_a) then
			if we_a = '1' then
				ram(to_integer(unsigned(addr_a))) := d_a;
			end if;
			q_a <= ram(to_integer(unsigned(addr_a)));
		end if;
		if rising_edge(clk_b) then
			if we_b = '1' then
				ram(to_integer(unsigned(addr_b))) := d_b;
			end if;
			q_b <= ram(to_integer(unsigned(addr_b)));
		end if;
	end process;
end simulation;
