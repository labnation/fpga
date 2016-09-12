library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity pulsewidthmodulator is
	port ( 
		in_clk 			: in  std_logic;
		in_reset 		: in  std_logic;
		in_duty_cycle 	: in  unsigned(7 downto 0);
		out_pwm 		: out std_logic			  
	);
end pulsewidthmodulator;

architecture behavioral of pulsewidthmodulator is

signal sig_counter		: unsigned(7 downto 0);

begin

process(in_clk, in_reset)
begin
	if (in_reset = '1') then
		sig_counter <= (others => '0');
	elsif rising_edge(in_clk) then
		sig_counter <= sig_counter + 1;		
		if (sig_counter > in_duty_cycle) then
			out_pwm <= '0';
		else
			out_pwm <= '1';
		end if;
	end if;
end process;


end behavioral;

