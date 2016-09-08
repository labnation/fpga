LIBRARY IEEE;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
USE WORK.Types.all;

ENTITY SpiMaster IS
	PORT ( 	
	in_reset 			: IN    STD_LOGIC;
	in_clk 				: IN    STD_LOGIC;
	in_start_trigger	: IN    STD_LOGIC;
	inout_sdin 			: INOUT STD_LOGIC;
	out_sclk			: OUT   STD_LOGIC;
	out_ncs				: OUT   STD_LOGIC;
	in_spi_address		: IN    UNSIGNED(7 downto 0); --MSB will be sent first
	in_spi_data			: IN    UNSIGNED(7 downto 0); --MSB will be sent first
	out_spi_data		: OUT   UNSIGNED(7 downto 0)
	);
END SpiMaster;

architecture Behavioral of SpiMaster is
	-- types
	type state_type is (st_idle, st_sendingAddress, st_sendingValue, st_receivingValue);		
	

	-- input signals
	signal sig_start_trigger_d			: std_logic;
	signal sig_sdin_sync				: std_logic;
	signal sig_shiftRegister_sdin		: UNSIGNED(1 downto 0);
	signal sig_address					: UNSIGNED(7 downto 0);
	signal sig_data						: UNSIGNED(7 downto 0);
	
	-- output signals
	signal sig_sclk						: std_logic;
	signal sig_sclk_re					: std_logic;
	signal sig_sclk_fe					: std_logic;	
	signal sig_sclk_d					: std_logic;
		
	-- reset logic
	signal sig_moduleReset				: std_logic;
	
	-- states
	signal sig_state					: state_type;	
	signal sig_next_state				: state_type;	
	
	-- i2c combi logic
	signal sig_bitCounter				: integer range 0 to 10;
	signal sig_addressSent				: std_logic;
	signal sig_valueSent				: std_logic;
	signal sig_valueReceived			: std_logic;
	signal sig_incomingByte				: UNSIGNED(7 downto 0);

begin

-- sig_moduleReset
sig_moduleReset <= in_reset;

sig_sclk_re <= sig_sclk and not sig_sclk_d;
sig_sclk_fe <= sig_sclk_d and not sig_sclk; --needed for ACKing, where the bit needs to be placed on the fe

out_sclk <= sig_sclk;

--important process:
---- immediately after st_idle is reached, it should produce a fe on sig_sclk => counter always inited at 11
---- should keep out_ncs low some time after last re on sig_sclk
--sig_sclk, out_ncs
process(in_clk, sig_moduleReset)
	variable var_counter					: integer range 0 to 15;
begin
	if sig_moduleReset = '1' then
		sig_sclk <= '1';
		var_counter := 11;
		out_ncs <= '1';
	elsif rising_edge(in_clk) then		
		if (var_counter = 11) then
			if (sig_state = st_idle) then --this builds in some delay of 12 clocks, so the out_ncs can be risen some delay after the st_idle state is reached
				sig_sclk <= '1';
				out_ncs <= '1';
			else
				out_ncs <= '0';
				var_counter := 0;
				sig_sclk <= not sig_sclk;
			end if;
		else
			var_counter := var_counter + 1;
		end if;
	end if;
end process;

----out_ncs
--process(in_clk, in_reset)
--	variable var_counter					: integer range 0 to 15;
--begin
--	if sig_moduleReset = '1' then
--		out_ncs <= '1';
--	elsif rising_edge(in_clk) then		
--		if (sig_state = st_idle) then
--			out_ncs <= '1';
--		else
--			out_ncs <= '0';
--		end if;
--	end if;
--end process;

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
-- Synching of external signals
--

-- filter and sync SDA
process(sig_moduleReset, in_clk, inout_sdin)
begin
	if sig_moduleReset = '1' then
		sig_shiftRegister_sdin <= "01";
		sig_sdin_sync <= '0';
	elsif rising_edge(in_clk) then
		if (sig_shiftRegister_sdin = "00") then
			sig_sdin_sync <= '0';
		elsif (sig_shiftRegister_sdin = "11") then
			sig_sdin_sync <= '1';
		end if;
		sig_shiftRegister_sdin(1) <= sig_shiftRegister_sdin(0);
		sig_shiftRegister_sdin(0) <= inout_sdin;
	end if;
end process;

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
-- Generate all delayed signals
--

process(sig_moduleReset, in_clk, sig_sclk, sig_sdin_sync, in_start_trigger)
begin
	if sig_moduleReset = '1' then
		sig_start_trigger_d <= '0';
		sig_sclk_d <= '0';
	elsif rising_edge(in_clk) then
		sig_start_trigger_d <= in_start_trigger;
		sig_sclk_d <= sig_sclk;
	end if;
end process;

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
-- Combi part FSM
--

process(sig_state,
		sig_start_trigger_d, in_start_trigger,
		sig_addressSent, sig_address(7),
		sig_valueReceived,
		in_spi_address,
		in_spi_data,
		sig_address,
		sig_valueSent
		)
begin
	case (sig_state) is
------------------------------------------------------------------------------------
		when st_idle =>
			if (sig_start_trigger_d = '0') and (in_start_trigger = '1') then-- if re on start trigger
				sig_next_state <= st_sendingAddress;
				
				-- latch command and data, so no glitches occur when registers are being overwritten during spi transaction
				sig_address <= in_spi_address;
				sig_data <= in_spi_data;
			else
				sig_next_state <= st_idle;
			end if;		
			
------------------------------------------------------------------------------------			
		when st_sendingAddress => 
			if (sig_addressSent = '1') then
				if (sig_address(7) = '1') then --MSB of address register indicates W/R
					sig_next_state <= st_receivingValue;
				else
					sig_next_state <= st_sendingValue;
				end if;
			else
				sig_next_state <= st_sendingAddress;
			end if;
		
------------------------------------------------------------------------------------			
		when st_receivingValue =>
			if (sig_valueReceived = '1') then
				sig_next_state <= st_idle;
			else
				sig_next_state <= st_receivingValue;
			end if;
		
------------------------------------------------------------------------------------			
		when st_sendingValue =>
			if (sig_valueSent = '1') then
				sig_next_state <= st_idle;
			else
				sig_next_state <= st_sendingValue;
			end if;
		
------------------------------------------------------------------------------------							
		when others =>
			sig_next_state <= st_idle;
			
	end case;
	
end process;

-- sig_next_state
-- makes the FSM fully synchronous
process(in_clk, sig_next_state, sig_moduleReset)
begin
	if sig_moduleReset = '1' then
		sig_state <= st_idle;
	elsif rising_edge(in_clk) then
		sig_state <= sig_next_state;
	end if;
end process;

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
-- Sync part FSM
--



-- sig_bitcounter
process(in_clk, sig_moduleReset, sig_sclk_re, sig_state, sig_bitCounter)
begin
	if sig_moduleReset = '1' then
		sig_bitCounter <= 0;
	elsif rising_edge(in_clk) then
		if (sig_sclk_re = '1') then
			case sig_state is
------------------------------------------------------------------------------------							
				when st_idle =>
					sig_bitCounter <= 0;
------------------------------------------------------------------------------------							
				when others =>
					if (sig_bitCounter = 7) then
						sig_bitCounter <= 0;
					else
						sig_bitCounter <= sig_bitCounter + 1;
					end if;
------------------------------------------------------------------------------------					
			end case;
		end if;
	end if;
end process;

-- inout_sdin, taking care of ACKing
process(in_clk, sig_moduleReset, sig_sclk_fe, sig_state, sig_bitCounter)
	variable	var_outgoingByte		: UNSIGNED(7 downto 0);
begin
	if sig_moduleReset = '1' then
		inout_sdin <= 'Z';
	elsif rising_edge(in_clk) then		
		case sig_state is
------------------------------------------------------------------------------------							
			when st_sendingAddress =>
				if (sig_sclk_fe = '1') then -- all data is placed on the bus at the falling edge!
					inout_sdin <= sig_address(7-sig_bitCounter); -- needs to be '7-', as MSB must be put first
				end if;
------------------------------------------------------------------------------------							
			when st_sendingValue =>
				if (sig_sclk_fe = '1') then -- all data is placed on the bus at the falling edge!
					inout_sdin <= sig_data(7-sig_bitCounter); -- needs to be '7-', as MSB must be put first
				end if;
------------------------------------------------------------------------------------							
			when others => 
				inout_sdin <= 'Z';
------------------------------------------------------------------------------------												
		end case;
	end if;
end process;

-- sig_incomingByte
-- implemented as simple shift register
process(in_clk, sig_sclk_re, sig_moduleReset, sig_incomingByte, sig_sdin_sync)
begin
	if sig_moduleReset = '1' then
		sig_incomingByte <= "00000000";
	elsif rising_edge(in_clk) then
		if (sig_sclk_re = '1') then
			sig_incomingByte(7 downto 1) <= sig_incomingByte(6 downto 0);
			sig_incomingByte(0) <= sig_sdin_sync;
		end if;
	end if;
end process;



-- out_spi_data
-- this one only resets on in_reset, as otherwise the register contents is erased after eachs stopCondition!
process(in_clk, in_reset, sig_sclk_re, sig_bitCounter, sig_incomingByte)
begin
	if in_reset = '1' then
		out_spi_data <= "00000000";
	elsif rising_edge(in_clk) then		
		if (sig_sclk_re = '1') then
			if sig_state = st_receivingValue then
				if sig_bitCounter = 7 then
					-- sig_register is limiter to the max index of registerBank. this is needed not to get a warning on the next line
					out_spi_data(7 downto 1) <= sig_incomingByte(6 downto 0);
					out_spi_data(0) <= inout_sdin;
				end if;
			end if;
		end if;
	end if;
end process;

-- sig_addressSent
-- sig_valueSent
-- sig_valueReceived
process(in_clk, sig_moduleReset, sig_sclk_re, sig_bitCounter, sig_sdin_sync)
begin
	if sig_moduleReset = '1' then
		sig_addressSent <= '0';		
	elsif rising_edge(in_clk) then
		if (sig_sclk_re = '1') then
			case sig_state is
------------------------------------------------------------------------------------												
				when st_sendingAddress =>
					if sig_bitCounter = 7 then									
						sig_addressSent <= '1';						
					else
						sig_addressSent <= '0';
					end if;
					sig_valueSent <= '0'; --important to get these low before next comm starts
					sig_valueReceived <= '0'; --important to get these low before next comm starts
------------------------------------------------------------------------------------												
				when st_sendingValue =>
					if sig_bitCounter = 7 then									
						sig_valueSent <= '1';						
					else
						sig_valueSent <= '0';
					end if;	
					sig_addressSent <= '0';	--important to get these low before next comm starts
------------------------------------------------------------------------------------												
				when st_receivingValue =>
					if sig_bitCounter = 7 then									
						sig_valueReceived <= '1';						
					else
						sig_valueReceived <= '0';
					end if;	
					sig_addressSent <= '0';	--important to get these low before next comm starts

------------------------------------------------------------------------------------												
				when others =>
					sig_addressSent <= '0';
					sig_valueSent <= '0';
					sig_valueReceived <= '0';
			end case;
		end if;
	end if;
end process;

end Behavioral;

