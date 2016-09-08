library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.types.all;

library unisim;
use unisim.vcomponents.all;

entity AdcController is
port (
    in_reset            : in  std_logic; -- Reset
    -- ADC data port
    in_adc_clk          : in  std_logic; -- PLL clock for aDC
    out_adc_clk			: out std_logic; -- Clock for ADC
    in_adc_dclk         : in  std_logic; -- Clock aligned with ADC data
    in_adc_data 		: in  unsigned (8 downto 0); --  ADC data (DDR)
    
    -- Data from ADC for internal use, synchronous to in_adc_dclk
    out_channel_a       : out unsigned(7 downto 0); 
    out_channel_a_ovr   : out std_logic; -- overflow
    out_channel_b       : out unsigned(7 downto 0);
    out_channel_b_ovr   : out std_logic; -- overflow
        
    -- ADC SPI register control
    in_adc_reg_addr     : in unsigned(7 downto 0); -- register address to access
    in_adc_reg_dout     : in unsigned(7 downto 0); -- data to write to register
    out_adc_reg_din     : out unsigned(7 downto 0); -- data read from SPI
    in_adc_reg_cmd      : in std_logic; -- flag to initiate read
    
    -- ADC SPI port
    in_adc_sclk         : in    std_logic; -- SPI module clock
    out_adc_cs			: out   std_logic; -- Chip select
    out_adc_sclk		: out   std_logic; -- SPI clock
    inout_adc_dsin		: inout std_logic  -- SPI data
);
end AdcController;

architecture behavioral of AdcController is
    
signal sig_adc_clk_180 : std_logic;
signal sig_adc_dclk_180: std_logic;
signal sig_adc_data    : unsigned(17 downto 0);

begin

--------------------------------------------
--
-- ADC DDR to SDR
--
--------------------------------------------

sig_adc_clk_180 <= not in_adc_clk;
adc_clk_fwd : oddr2
generic map(
	ddr_alignment => "none",-- sets output alignment to "none", "c0", "c1"
	init => '0', 			-- sets initial state of the q output to ’0’ or ’1’
	srtype => "sync") 		-- specifies "sync" or "async" set/reset
port map (
	q 	=> out_adc_clk, 	-- 1-bit output data
	c0 	=> in_adc_clk,  	-- 1-bit clock input
	c1 	=> sig_adc_clk_180, -- 1-bit clock input
	ce 	=> '1', 			-- 1-bit clock enable input
	d0 	=> '1', 			-- 1-bit data input (associated with c0)
	d1 	=> '0', 			-- 1-bit data input (associated with c1)
	r 	=> '0',             -- 1-bit reset input
	s 	=> '0'  			-- 1-bit set input
);

sig_adc_dclk_180 <= not(in_adc_dclk);
adc_data_ddr:
for i in 0 to in_adc_data'length-1 generate
	adc_data_ddr_input: iddr2
	generic map(
		ddr_alignment => "c1", -- align output data to adc dclk's rising edge
		srtype => "async"
	)
	port map(
		d	=> in_adc_data(i),
		c0	=> in_adc_dclk,
		c1	=> sig_adc_dclk_180,
		ce	=> '1',
		q0	=> sig_adc_data(i),
		q1	=> sig_adc_data(i + 9)
	);	
end generate;

out_channel_a <= sig_adc_data( 7 downto 0);
out_channel_a_ovr <= sig_adc_data(8);
out_channel_b <= sig_adc_data(16 downto 9);
out_channel_b_ovr <= sig_adc_data(17);


--------------------------------------------
--
-- ADC SPI control
--
--------------------------------------------

spi_master: entity work.spimaster 
port map(
	in_reset 			=> in_reset,
	in_clk 				=> in_adc_sclk,
	in_start_trigger 	=> in_adc_reg_cmd,
	inout_sdin 			=> inout_adc_dsin,
	out_sclk			=> out_adc_sclk,
	out_ncs 			=> out_adc_cs,
	in_spi_address		=> in_adc_reg_addr,
	in_spi_data 		=> in_adc_reg_dout,
	out_spi_data 		=> out_adc_reg_din
);
	
end behavioral;