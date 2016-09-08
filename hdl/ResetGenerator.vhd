library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;

entity ResetGenerator is
port (
    -- ADC data port
    in_clk              : in  std_logic;
    in_reset            : in  std_logic;
    out_reset			: out std_logic
);
end ResetGenerator;

architecture behavioral of ResetGenerator is
    
signal sig_reset            : std_logic := '1';
signal reset_counter	    : unsigned(5 downto 0) := (others => '0');
signal soft_reset_counter   : unsigned(5 downto 0) := (others => '1');

begin

-- reset
process(in_clk)
begin
	if rising_edge(in_clk) then
		if reset_counter = (reset_counter'range => '1') then
			sig_reset <= '0';
		else
			reset_counter <= reset_counter + 1;
			sig_reset <= '1';
		end if;
	end if;
end process;

proc_soft_reset: process(in_clk, sig_reset)
begin
	if sig_reset = '1' then
		soft_reset_counter <= (others => '1');
		out_reset <= '1';
	elsif rising_edge(in_clk) then
		if soft_reset_counter = 0 then
			if in_reset = '1' then
				soft_reset_counter <= (others => '1');
				out_reset <= '1';
			else
				out_reset <= '0';
			end if;
		else
			soft_reset_counter <= soft_reset_counter - 1;
		end if;
	end if;
end process;

end behavioral;