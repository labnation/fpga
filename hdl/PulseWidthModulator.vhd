LIBRARY IEEE;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;


ENTITY PulseWidthModulator IS
	PORT ( 
		in_clk 			: IN  STD_LOGIC;
		in_reset 		: IN  STD_LOGIC;
		in_duty_cycle 	: IN  UNSIGNED(7 DOWNTO 0);
		out_PWM 		: OUT STD_LOGIC			  
	);
END PulseWidthModulator;

ARCHITECTURE Behavioral OF PulseWidthModulator IS

SIGNAL sig_counter		: UNSIGNED(7 DOWNTO 0);

BEGIN

PROCESS(in_clk, in_reset)
BEGIN
	IF (in_reset = '1') THEN
		sig_counter <= (OTHERS => '0');
	ELSIF RISING_EDGE(in_clk) THEN
		sig_counter <= sig_counter + 1;		
		IF (sig_counter > in_duty_cycle) THEN
			out_PWM <= '0';
		ELSE
			out_PWM <= '1';
		END IF;
	END IF;
END PROCESS;


END Behavioral;

