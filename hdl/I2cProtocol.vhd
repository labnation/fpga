----------------------------------------------------------------------------------
-- Company: LabNation
-- Engineer: Jasper van Bourgognie
-- 
-- Create Date:		28 July 2014
-- Design Name: 	SmartScope
-- Module Name:		I2C Protocol
-- Description: 
----------------------------------------------------------------------------------

LIBRARY IEEE;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
USE WORK.Types.all;

ENTITY I2cProtocol IS
	GENERIC(
		LISTEN_ADDRESSES:	TYPE_I2C_ADDRESS_LIST
	);
	PORT ( 
	-- General
		in_clk				:	IN		STD_LOGIC;
		in_reset			:	IN		STD_LOGIC;
	--I2C port
		in_scl				:	IN		STD_LOGIC;
		inout_sda			:	INOUT	STD_LOGIC;
	
	-- Control signals
		out_busy					:	OUT		STD_LOGIC;
		
		out_device_address			:	OUT		TYPE_I2C_ADDRESS;
		out_device_address_valid	:	OUT		STD_LOGIC;
		
		in_data_tx					:	IN 		TYPE_I2C_BYTE;
		out_data_tx_rden			:	OUT		STD_LOGIC;

		out_data_rx					:	OUT		TYPE_I2C_BYTE;
		out_data_rx_valid			:	OUT		STD_LOGIC
	);
END I2cProtocol;

ARCHITECTURE Behavioral OF I2cProtocol IS
	TYPE TYPE_I2C_STATE		IS (IDLE, ADDRESS, TX_ACK, RX_ACK, RX_DATA, TX_DATA);
	SIGNAL sig_state		: TYPE_I2C_STATE;
	SIGNAL sig_state_next	: TYPE_I2C_STATE;
	
	SIGNAL sig_scl, sig_scl_d	: STD_LOGIC;
	SIGNAL sig_sda, sig_sda_d	: STD_LOGIC;
	SIGNAL sig_scl_re			: STD_LOGIC;
	SIGNAL sig_scl_fe			: STD_LOGIC;
	SIGNAL sig_start_condition 	: STD_LOGIC;
	SIGNAL sig_stop_condition	: STD_LOGIC;
	
	SIGNAL sig_address_valid	: STD_LOGIC;
	SIGNAL sig_transmit_mode	: STD_LOGIC;
	
	SIGNAL sig_bit_count		: UNSIGNED(2 DOWNTO 0);
	SIGNAL sig_data 			: TYPE_I2C_BYTE;
	SIGNAL sig_data_valid 		: STD_LOGIC;
	SIGNAL sig_data_tx			: TYPE_I2C_BYTE;
	SIGNAL sig_data_tx_rden		: STD_LOGIC;
	
BEGIN

	-- Asynchronous part of FSM
	state_transition: PROCESS(sig_state, sig_start_condition, sig_transmit_mode, 
		sig_address_valid, sig_scl_fe, sig_scl_re, sig_bit_count, sig_data_valid, sig_sda)
	BEGIN
		CASE(sig_state) IS
		WHEN ADDRESS		=>
			IF sig_data_valid = '1' AND sig_scl_fe = '1' THEN
				IF sig_address_valid = '1' THEN
					sig_state_next <= TX_ACK;
				ELSE
					sig_state_next <= IDLE;
				END IF;
			ELSE
				sig_state_next <= ADDRESS;
			END IF;
		WHEN TX_ACK 		=>
			IF sig_scl_fe = '1' THEN
				IF sig_transmit_mode = '1' THEN
					sig_state_next <= TX_DATA;
				ELSE
					sig_state_next <= RX_DATA;
				END IF;
			ELSE
				sig_state_next <= TX_ACK;
			END IF;
		WHEN RX_DATA		=>
			IF sig_data_valid = '1' AND sig_scl_fe = '1' THEN
				sig_state_next <= TX_ACK;
			ELSE
				sig_state_next <= RX_DATA;
			END IF;
		WHEN TX_DATA		=>
			IF sig_scl_fe = '1' AND sig_bit_count = 0 THEN
				sig_state_next <= RX_ACK;
			ELSE
				sig_state_next <= TX_DATA;
			END IF;
		WHEN RX_ACK			=>
			IF sig_scl_fe = '1' THEN
				IF sig_sda = '0' THEN
					sig_state_next <= TX_DATA;
				ELSE
					sig_state_next <= IDLE;
				END IF;
			ELSE
				sig_state_next <= RX_ACK;
			END IF;
		WHEN OTHERS			=> 
			sig_state_next <= IDLE;
		END CASE;
	END PROCESS;
	
	state_sample: PROCESS(in_clk, in_reset)
	BEGIN
		IF in_reset = '1' THEN
			sig_scl_d <= '1';
			sig_sda_d <= '1';
		ELSIF RISING_EDGE(in_clk) THEN
			sig_scl <= in_scl;
			sig_scl_d <= sig_scl;
			sig_sda <= inout_sda;
			sig_sda_d <= sig_sda;
		END IF;
	END PROCESS;
	
	sig_start_condition <= '1' WHEN sig_sda = '0' AND sig_sda_d /= '0' AND sig_scl_d /= '0' AND sig_scl /= '0' 
							ELSE '0';
	
	sig_stop_condition 	<= '1' WHEN sig_sda /= '0' AND sig_sda_d = '0' AND sig_scl_d /= '0' AND sig_scl /= '0'
							ELSE '0';
							
	sig_scl_re			<= '1' WHEN sig_scl /= '0' AND sig_scl_d = '0' ELSE
							'0';
	sig_scl_fe			<= '1' WHEN sig_scl = '0' AND sig_scl_d /= '0' ELSE 
							'0';
	
	
	inout_sda <= '0' WHEN sig_state = TX_ACK ELSE
				 '0' WHEN sig_state = TX_DATA AND sig_data_tx(TO_INTEGER(sig_bit_count)) = '0' ELSE
				 'Z';
	
	-- Synchronous part of FSM
	state_synchronisation: PROCESS(in_clk, in_reset)
	BEGIN
		IF in_reset = '1' THEN
			sig_state		<= IDLE;
		ELSIF RISING_EDGE(in_clk) THEN
			IF sig_stop_condition = '1' THEN
				sig_state 	<= IDLE;
			ELSIF sig_start_condition = '1' THEN
				sig_state 	<= ADDRESS;
			ELSE
				sig_state 	<= sig_state_next;
			END IF;
		END IF;
	END PROCESS;
	out_busy <= '0' WHEN sig_state = IDLE ELSE '1';
	
	proc_bitcount : PROCESS(in_clk, in_reset)
	BEGIN
		IF in_reset = '1' THEN
			sig_bit_count <= (OTHERS => '1');
		ELSIF RISING_EDGE(in_clk) THEN
			IF sig_start_condition = '1' THEN
				sig_bit_count <= (OTHERS => '1');
			ELSIF sig_state = ADDRESS OR sig_state = RX_DATA THEN
				IF sig_scl_re = '1' THEN
					sig_bit_count <= sig_bit_count - 1;
				END IF;
			ELSIF sig_state = TX_DATA THEN
				IF sig_scl_fe = '1' THEN
					sig_bit_count <= sig_bit_count - 1;
				END IF;
			ELSE
				sig_bit_count <= (OTHERS => '1');
			END IF;
		END IF;
	END PROCESS;
	
	proc_data_composition : PROCESS(in_clk, in_reset)
		VARIABLE index : NATURAL RANGE 0 TO 7;
	BEGIN
		IF in_reset = '1' THEN
			sig_data <= (OTHERS => '0');
			sig_data_valid <= '0';
		ELSIF RISING_EDGE(in_clk) THEN
			IF sig_state = ADDRESS OR sig_state = RX_DATA THEN
				IF sig_scl_re = '1' THEN
					index := TO_INTEGER(sig_bit_count);
					IF(sig_sda = '0') THEN
						sig_data(index) <= '0';
					ELSE 
						sig_data(index) <= '1';
					END IF;
					IF(index = 0) THEN
						sig_data_valid <= '1';
					END IF;
				END IF;
			ELSE
				sig_data_valid <= '0';
			END IF;
		END IF;
	END PROCESS;
	out_data_rx_valid 	<= '1' WHEN sig_state = RX_DATA AND sig_data_valid = '1' ELSE
						   '0';
	out_data_rx 		<= sig_data WHEN sig_state = RX_DATA AND sig_data_valid = '1' ELSE
						   (OTHERS => '0');						 
	
	out_data_tx_rden <= sig_data_tx_rden;
	
	proc_data_transmission : PROCESS(in_clk, in_reset)
		VARIABLE index : NATURAL RANGE 0 TO 7;
	BEGIN
		IF in_reset = '1' THEN
			sig_data_tx <= (OTHERS => '0');
		ELSIF RISING_EDGE(in_clk) THEN
			IF sig_state /= TX_DATA AND sig_state_next = TX_DATA THEN
				sig_data_tx_rden <= '1';
			ELSE
				sig_data_tx_rden <= '0';
			END IF;
			IF sig_data_tx_rden = '1' THEN
				sig_data_tx <= in_data_tx;
			END IF;
		END IF;
	END PROCESS;
	
	proc_verify_address: PROCESS(sig_address_valid, sig_data, sig_data_valid, sig_state)
		VARIABLE address_valid : STD_LOGIC;
	BEGIN
		address_valid := '0';
		IF(sig_data_valid = '1' AND sig_state = ADDRESS) THEN
			FOR i IN LISTEN_ADDRESSES'RANGE LOOP
				address_valid := address_valid OR TO_STD_LOGIC(LISTEN_ADDRESSES(i) = sig_data(7 DOWNTO 1));
			END LOOP;
		END IF;
		sig_address_valid <= address_valid;
	END PROCESS;
	
	proc_transmit_mode: PROCESS(in_clk, in_reset)
	BEGIN
		IF in_reset = '1' THEN
			sig_transmit_mode <= '0';
		ELSIF RISING_EDGE(in_clk) THEN
			IF sig_start_condition = '1' THEN
				sig_transmit_mode <= '0';
			ELSIF sig_address_valid = '1' THEN
				sig_transmit_mode <= sig_data(0);
			END IF;
		END IF;
	END PROCESS;
	
	out_device_address_valid 	<= sig_address_valid;
	out_device_address 			<= sig_data(7 DOWNTO 1) WHEN sig_address_valid = '1' ELSE (OTHERS => '0');
	
END Behavioral;

