library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;
use ieee.math_real.ceil;
use ieee.math_real.log2;

entity piccontroller is
generic (
	bytes_per_burst 				: natural := 64
);
port ( 
	in_reset 					: in  std_logic;
	in_clk						: in  std_logic;
	-- commands
	in_dump_req					: in  std_logic;
	out_dump_busy				: out std_logic;
	in_ignore_fifo				: in  std_logic;
	-- fifo ports
	in_fifo_full				: in  std_logic;
	out_fifo_rdreq				: out std_logic;
	in_fifo_data				: in  std_logic_vector(7 downto 0);
	-- pic port
	in_pic_rdy					: in  std_logic;
	out_data					: out std_logic_vector(7 downto 0)
	);
end piccontroller;

architecture behavioral of piccontroller is

type pic_controller_state is (idle, wait_for_fifo, wait_for_pic, dumping);

signal sig_state						: pic_controller_state;   
signal sig_state_next					: pic_controller_state;
signal sig_words_to_send				: unsigned(natural(ceil(log2(real(bytes_per_burst)))) downto 0);
signal sig_cycle_count					: unsigned(1 downto 0); --to divice clock by 4
	
begin
	
	-- asynchronous part of fsm
	state_transition: process(sig_state, in_dump_req, in_ignore_fifo, in_fifo_full, in_pic_rdy, sig_words_to_send(sig_words_to_send'high), sig_cycle_count)
	begin
		case(sig_state) is
    --------------------------------------------
		when idle			=>
			if in_dump_req = '1' then
				if in_ignore_fifo = '0' then
					sig_state_next <= wait_for_fifo;
				else
					sig_state_next <= wait_for_pic;
				end if;
			else
				sig_state_next <= idle;
			end if;
    --------------------------------------------
		when wait_for_fifo 	=>
			if in_fifo_full = '1' or in_ignore_fifo = '1' then
				sig_state_next <= wait_for_pic;
			else
				sig_state_next <= wait_for_fifo;
			end if;
    --------------------------------------------
		when wait_for_pic 	=>
			if in_pic_rdy = '1' then
				sig_state_next <= dumping;
			else
				sig_state_next <= wait_for_pic;
			end if;			
    --------------------------------------------
		when dumping		=>
			if sig_words_to_send(sig_words_to_send'high) = '1' and sig_cycle_count = "11" then
				sig_state_next <= idle;
			else
				sig_state_next <= dumping;
			end if;
		end case;
	end process;
	
	-- synchronous part of fsm
	state_synchronisation: process(in_clk, in_reset)
	begin
		if in_reset = '1' then
			sig_state	<= idle;
		elsif rising_edge(in_clk) then
			sig_state 	<= sig_state_next;			
		end if;
	end process;
	
	-- generate out_dump_busy
	busy: process(in_clk, in_reset)
	begin
		if in_reset = '1' then
			out_dump_busy	<= '0';
		elsif rising_edge(in_clk) then
			if sig_state = idle then
				out_dump_busy <= '0';
			else
				out_dump_busy <= '1';
			end if;
		end if;
	end process;
	
	cycle_count: process(in_clk, in_reset)
	begin
		if in_reset = '1' then
			sig_cycle_count  <= (others => '0');
		elsif rising_edge(in_clk) then
			if sig_state = dumping or sig_state = idle then
				sig_cycle_count <= sig_cycle_count + 1;
			else
				sig_cycle_count  <= (others => '0');
			end if;
		end if;
	end process;

	
	word_cnt: process(in_clk, in_reset)
	begin
		if rising_edge(in_clk) then
			if sig_state = dumping then
				if sig_cycle_count = "11" then
					sig_words_to_send	<= sig_words_to_send - 1;
				end if;
			else
				sig_words_to_send	<= to_unsigned(bytes_per_burst - 2, sig_words_to_send'length);
			end if;
		end if;
	end process;
	
	out_data_mux: process(in_clk, in_reset)
	begin
		if in_reset = '1' then
			out_data <= x"00";
		elsif rising_edge(in_clk) then
			if sig_state = dumping and sig_cycle_count = 1 then
				out_data <= in_fifo_data;
			elsif sig_state = wait_for_pic then
				out_data <= x"f0";
			elsif sig_state = idle and sig_cycle_count = 1 then
				out_data <= x"00";
			end if;
		end if;
	end process;
	
	out_fifo_rdreq <= '1' when sig_state = dumping and sig_cycle_count = 0 else
					  '0';

end behavioral;