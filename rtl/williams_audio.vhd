library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

entity williams_audio is
port (
	clock      : in  std_logic;
	reset      : in  std_logic;
	game       : in  std_logic_vector(7 downto 0);
	mono       : in  std_logic_vector(15 downto 0);
	dac_l      : in  std_logic_vector(7 downto 0);
	dac_r      : in  std_logic_vector(7 downto 0);
	audio_l    : out std_logic_vector(15 downto 0);
	audio_r    : out std_logic_vector(15 downto 0)
);
end williams_audio;

architecture RTL of williams_audio is
	type accum_t is array(0 to 1) of unsigned(15 downto 0);
	type sample_t is array(0 to 1) of unsigned(7 downto 0);
	type filter_t is array(0 to 1) of signed(25 downto 0);
	type output_t is array(0 to 1) of std_logic_vector(15 downto 0);
	signal accum : accum_t := (others => (others => '0'));
	signal filtered : sample_t := (others => (others => '0'));
	signal hpf_x1, hpf_y : filter_t := (others => (others => '0'));
	signal count : unsigned(7 downto 0) := (others => '0');
	signal output : output_t;
begin
	process(clock)
		variable sum : unsigned(15 downto 0);
		variable sample : signed(25 downto 0);
		variable mix : unsigned(17 downto 0);
	begin
		if rising_edge(clock) then
			if reset = '1' then
				count <= (others => '0');
				accum <= (others => (others => '0'));
				filtered <= (others => (others => '0'));
				hpf_x1 <= (others => (others => '0'));
				hpf_y <= (others => (others => '0'));
			else
				count <= count + 1;
				for i in 0 to 1 loop
					if i = 0 then
						sum := accum(i) + unsigned(dac_l);
					else
						sum := accum(i) + unsigned(dac_r);
					end if;
					if count = 255 then
						filtered(i) <= sum(15 downto 8);
						accum(i) <= (others => '0');
						sample := shift_left(signed(resize(filtered(i), 26)), 16);
						hpf_x1(i) <= sample;
						hpf_y(i) <= sample - hpf_x1(i) + hpf_y(i) - shift_right(hpf_y(i), 6);
					else
						accum(i) <= sum;
					end if;
				end loop;
			end if;
			for i in 0 to 1 loop
				mix := unsigned(hpf_y(i)(25 downto 8)) + 16#10000#;
				output(i) <= "00" & std_logic_vector(mix(16 downto 3));
			end loop;
		end if;
	end process;

	audio_l <= output(0) when game = x"08" or game = x"09" else mono;
	audio_r <= output(1) when game = x"09" else
	           output(0) when game = x"08" else mono;
end RTL;
