LIBRARY IEEE;
USE ieee.std_logic_1164.all;

ENTITY GenericRam IS
GENERIC (
	WORDS : POSITIVE;
	WORD_SIZE : POSITIVE
);
PORT ( 
	clka 		: IN  STD_LOGIC;
	addra		: IN  NATURAL;
	dina		: IN  STD_LOGIC_VECTOR(WORD_SIZE - 1 DOWNTO 0);
	wrena		: IN  STD_LOGIC;
	
	clkb 		: IN  STD_LOGIC;
	addrb		: IN  NATURAL;
	doutb 		: OUT  STD_LOGIC_VECTOR(WORD_SIZE - 1 DOWNTO 0)
);
END GenericRam;

ARCHITECTURE behavioral OF GenericRam IS

TYPE TYPE_MEMORY IS ARRAY(0 TO WORDS - 1) OF STD_LOGIC_VECTOR(WORD_SIZE - 1 DOWNTO 0);
SIGNAL sig_memory			: TYPE_MEMORY;

BEGIN

proc_a: PROCESS(clka)
BEGIN
	IF RISING_EDGE(clka) THEN
		IF wrena = '1' THEN
			sig_memory(addra) <= dina;
		END IF;
	END IF;
END PROCESS;

proc_b: PROCESS(clkb)
BEGIN
	IF RISING_EDGE(clkb) THEN
		doutb <= sig_memory(addrb);
	END IF;
END PROCESS;

END behavioral;