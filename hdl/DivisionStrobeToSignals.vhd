library IEEE;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY DivisionStrobeToSignals IS
	PORT ( 
		in_clk 						: IN  STD_LOGIC;
		in_reset					: IN  STD_LOGIC;
		in_power_of_10				: IN  UNSIGNED(1 DOWNTO 0);
		out_div1_relay_pulse_off 	: OUT STD_LOGIC;
		out_div1_relay_pulse_on 	: OUT STD_LOGIC;
		out_div10_100_selector		: OUT STD_LOGIC
	);
END DivisionStrobeToSignals;

ARCHITECTURE Behavioral OF DivisionStrobeToSignals IS

TYPE STATE IS (PULSE_ON, PULSE_OFF, IDLE);

SIGNAL sig_power_of_10	: UNSIGNED(1 DOWNTO 0);
SIGNAL sig_state		: STATE;
SIGNAL sig_counter 		: UNSIGNED(17 DOWNTO 0);

BEGIN

PROCESS(in_clk, in_reset)
BEGIN
	IF in_reset = '1' THEN
		sig_power_of_10				<= "11";
		sig_state					<= IDLE;
		sig_counter					<= (sig_counter'HIGH => '1', OTHERS => '0');
	ELSIF RISING_EDGE(in_clk) THEN
		IF sig_counter(sig_counter'HIGH) = '1' THEN
			IF in_power_of_10 /= sig_power_of_10 THEN 
				sig_counter			<= (sig_counter'HIGH => '0', OTHERS => '1');
				sig_power_of_10 	<= in_power_of_10;
				
				IF in_power_of_10 = 0 THEN 
					sig_state 	<= PULSE_ON;
				ELSE
					sig_state 	<= PULSE_OFF;
				END IF;
			ELSE
				sig_state <= IDLE;
			END IF;
		ELSE
			sig_counter <= sig_counter - 1;
		END IF;
	END IF;
END PROCESS;

out_div1_relay_pulse_on  	<= '1' WHEN sig_state = PULSE_ON  ELSE '0';
out_div1_relay_pulse_off 	<= '1' WHEN sig_state = PULSE_OFF ELSE '0';
out_div10_100_selector		<= '1' WHEN in_power_of_10 = "10" ELSE 
								'0';

end Behavioral;

