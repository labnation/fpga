library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use ieee.math_real.all;   -- for uniform, trunc functions
use ieee.numeric_std.all; -- for to_unsigned function

use work.types.all;
use work.constants.all;
use work.buildversion.all;

library unisim;
use unisim.vcomponents.all;
 
entity SmartScopeHackerSpecial is

port (
	-- general
	in_clk				: in 	std_logic; -- 48 MHz input clock
	inout_sda	 		: inout std_logic; -- PIC <> FPGA I2C bus SDA
	in_scl		 		: in  	std_logic; -- PIC <> FPGA I2C bus SCL
    out_negen			: out 	std_logic; -- Enable negative power supply
	out_digital_3v_5v 	: out 	std_logic; -- Digital I/O select 3.3V or 5.0V
	out_opa_b_en		: out 	std_logic; -- Enable input channel B's opamp
	
    -- ram port
	inout_ram_dq		: inout std_logic_vector(15 downto 0); -- Data
	out_ram_clk			: out   std_logic;                     -- Clock
	out_ram_a			: out   std_logic_vector(11 downto 0); -- Address
	out_ram_ba			: out   std_logic_vector( 1 downto 0); -- Bank
	out_ram_ncs			: out   std_logic;                     -- #Chip select
	out_ram_cmd			: out   unsigned(2 downto 0);          -- RAM command

    -- pic port
	in_pic_rdy			: in  std_logic;     -- PIC ready to receive?
	out_pic_data		: out std_logic_vector(7 downto 0); -- Data for PIC
	
    -- adc
	out_adc_clk			: out   std_logic; -- Clock for ADC
    in_adc_dclk         : in    std_logic; -- Clock aligned with ADC data
	in_adc_data 		: in    unsigned(8 downto 0); --  ADC data (DDR)
	out_adc_cs			: out   std_logic; -- Chip select
	out_adc_sclk		: out   std_logic; -- SPI clock
	inout_adc_dsin		: inout std_logic; -- SPI data

    -- analog channel a
	out_a_div1_pulse_on	: out std_logic; -- EE2-5TNUH-L Relay pin 12
	out_a_div1_pulse_off: out std_logic; -- EE2-5TNUH-L Relay pin 7
	out_a_div_10_100	: out std_logic; -- '1' to choose /10, '0' for /100
	out_a_ypos			: out std_logic; -- PWM for Y-offset
	out_a_dc			: out std_logic; -- DC/AC selector (CPC1125N) control
	out_a_mult_1		: out std_logic; -- Multiplication selector 1
	out_a_mult_2		: out std_logic; -- Multiplication selector 2

    -- analog channel b
	out_b_div1_pulse_on	: out std_logic; -- EE2-5TNUH-L Relay pin 12
	out_b_div1_pulse_off: out std_logic; -- EE2-5TNUH-L Relay pin 7
	out_b_div_10_100	: out std_logic; -- '1' to choose /10, '0' for /100
	out_b_ypos			: out std_logic; -- PWM for Y-offset
	out_b_dc			: out std_logic; -- DC/AC selector (CPC1125N) control
	out_b_mult_1		: out std_logic; -- Multiplication selector 1
	out_b_mult_2		: out std_logic; -- Multiplication selector 2
	
    -- awg/digital input/digital output/trigger
	out_trigger_pwm			: out std_logic; -- PWM to set external trigger lvl
	out_power_digital_io	: out std_logic; -- '1' to enable digital I/O (Logic analyser, digital output)
	inout_awg_digital_input	: inout	unsigned(7 downto 0); -- Bus to either drive
                                                          -- 8-bit AWG output
                                                          -- or read logic
                                                          -- analyser bits
	out_digital				: out unsigned(3 downto 0); -- digital output bus
                                                        -- 4-bit value
	out_digital_input_enable: out std_logic; -- '1' to enable logic analyser
    
    -- Miscellaneous
    in_trigger_ext          : in std_logic;  -- output of external trigger  
                                             -- comparator
    usb_micro_d_n           : inout std_logic; -- Micro usb connector D-
    usb_micro_d_p           : inout std_logic; -- Micro usb connector D+
    inout_gpio : inout unsigned(5 downto 1) -- GPIO's on headers:
                                            -- GPIO 1 =  J10.p5
                                            -- GPIO 2 =   J9.p2
                                            -- GPIO 3 =  J10.p6
                                            -- GPIO 4 =   J9.p4
                                            -- GPIO 5 =   J9.p3
);

end SmartScopeHackerSpecial;
 
architecture behavior of SmartScopeHackerSpecial is 
 
	signal sig_reset		: std_logic;

	-- clock signals
	signal sig_clk_input    : std_logic;
	signal sig_clk_pic	    : std_logic;
	signal sig_clk_adc_spi  : std_logic;

	-- settings
	signal sig_rom			: type_registers(number_of_roms - 1 downto 0);
	signal sig_regs	        : type_registers(number_of_registers-1 downto 0);
    signal sig_regs_user    : type_registers(255 downto 0);
    signal cha_ypos_duty    : unsigned(7 downto 0);
    signal chb_ypos_duty    : unsigned(7 downto 0);
    
    -- USB pic output control signals
    signal sig_pic_data    : std_logic_vector(7 downto 0);
    signal sig_pic_data_dbg: unsigned(7 downto 0);
    signal sig_pic_data_rden: std_logic;
    signal sig_pic_data_rden_d: std_logic;
    signal sig_pic_debug   : std_logic;
    signal sig_pic_dump_req: std_logic;
 
    signal sig_adc_cha      : unsigned(7 downto 0);
    signal sig_adc_chb      : unsigned(7 downto 0);
begin
    
	-- PLL clock generation
	pll: entity work.pll_lf
	port map (
		clk_in1		=> in_clk,          -- 48MHz
		clk_out1	=> sig_clk_input,   -- 100 MHz
		clk_out2	=> sig_clk_pic,     -- 24 MHz
		clk_out3	=> sig_clk_adc_spi  -- 12 MHz
	);
    
    -- reset generation
    resetGenerator: entity work.ResetGenerator
    port map (
        -- ADC data port
        in_clk              => sig_clk_pic,
        in_reset            => '0',
        out_reset			=> sig_reset
    );
		
	-- i2c slave
	i2c_dispatch: entity work.i2cdispatch 
    generic map (
        n_regs => sig_regs'length,
        n_roms => sig_rom'length,
        n_regs_user => sig_regs_user'length
    )
    port map(
		in_clk 				=> sig_clk_pic,
		in_reset 			=> sig_reset,
		
		inout_sda 			=> inout_sda,
		in_scl 				=> in_scl,
		
		out_registers 		=> sig_regs,
        out_registers_user  => sig_regs_user,
		in_rom 				=> sig_rom
	);

	-- rom values
	sig_rom(rom_fw_git0) <= build_version( 7 downto  0);
	sig_rom(rom_fw_git1) <= build_version(15 downto  8);
	sig_rom(rom_fw_git2) <= build_version(23 downto 16);
	sig_rom(rom_fw_git3) <= build_version(31 downto 24);
	
    out_negen			<= sig_regs(reg_power)(b_power_negen);
	out_digital_3v_5v 	<= sig_regs(reg_power)(b_power_digi_3v_5v);
	out_opa_b_en		<= sig_regs(reg_power)(b_power_opa_b_en);
	
    -- ram port
	inout_ram_dq		<= (others => 'Z');
	out_ram_clk			<= '0';
	out_ram_a			<= (others => '0');
	out_ram_ba			<= (others => '0');
	out_ram_ncs			<= '1';
	out_ram_cmd			<= (others => '0');
	
    -- analog channel a
    gain_cha: entity work.gainctrl
    port map( 
		in_clk 						=> sig_clk_adc_spi,
		in_reset					=> sig_reset,
		in_gain				        => sig_regs(reg_cha_gain)(3 downto 0),
		out_div1_relay_pulse_off 	=> out_a_div1_pulse_off,
		out_div1_relay_pulse_on 	=> out_a_div1_pulse_on,
		out_div10_100_selector		=> out_a_div_10_100,
        out_mul(0)                  => out_a_mult_1,
        out_mul(1)                  => out_a_mult_2
    );
    cha_ypos_duty <= sig_regs(reg_cha_ypos);
    pwm_cha_ypos: entity work.PulseWidthModulator
	port map( 
		in_clk 			=> sig_clk_adc_spi,
		in_reset 		=> sig_reset,
		in_duty_cycle 	=> cha_ypos_duty,
		out_pwm 		=> out_a_ypos
	);
	out_a_dc			<= sig_regs(reg_flags)(b_flags_cha_ac_dc);

    -- analog channel b
    gain_chb: entity work.gainctrl
    port map( 
		in_clk 						=> sig_clk_adc_spi,
		in_reset					=> sig_reset,
		in_gain				        => sig_regs(reg_chb_gain)(3 downto 0),
		out_div1_relay_pulse_off 	=> out_b_div1_pulse_off,
		out_div1_relay_pulse_on 	=> out_b_div1_pulse_on,
		out_div10_100_selector		=> out_b_div_10_100,
        out_mul(0)                  => out_b_mult_1,
        out_mul(1)                  => out_b_mult_2
    );
    chb_ypos_duty <= sig_regs(reg_chb_ypos);
    pwm_chb_ypos: entity work.PulseWidthModulator
	port map( 
		in_clk 			=> sig_clk_adc_spi,
		in_reset 		=> sig_reset,
		in_duty_cycle 	=> chb_ypos_duty,
		out_pwm 		=> out_b_ypos
	);
	out_b_dc			<= sig_regs(reg_flags)(b_flags_chb_ac_dc);

    -- awg/digital input/digital output/trigger
	out_trigger_pwm			 <= '0';
	out_power_digital_io	 <= '0';
	inout_awg_digital_input	 <= (others => 'Z');
	out_digital				 <= (others => '0');
	out_digital_input_enable <= '0';
    
    -- Miscellaneous
    usb_micro_d_n           <= 'Z';
    usb_micro_d_p           <= 'Z';
    inout_gpio(5 downto 3)  <= (others => sig_reset);
    
    AdcController: entity work.AdcController
    port map (
        in_reset            => sig_reset,
        -- ADC data port
        in_adc_clk          => sig_clk_input,
        out_adc_clk			=> out_adc_clk,
        in_adc_dclk         => in_adc_dclk,
        in_adc_data 		=> in_adc_data,
    
        -- Data from ADC for internal use, synchronous to in_adc_dclk
        out_channel_a       => sig_adc_cha,
        out_channel_a_ovr   => open,
        out_channel_b       => sig_adc_chb,
        out_channel_b_ovr   => open,
        
        -- ADC SPI register control
        in_adc_reg_addr     => sig_regs(reg_spi_addr),
        in_adc_reg_dout     => sig_regs(reg_spi_value),
        out_adc_reg_din     => sig_rom(rom_spi_received_value),
        in_adc_reg_cmd      => sig_regs(reg_flags)(b_flags_spi_cmd),
    
        -- ADC SPI port
        in_adc_sclk         => sig_clk_adc_spi,
        out_adc_cs			=> out_adc_cs,
        out_adc_sclk		=> out_adc_sclk,
        inout_adc_dsin		=> inout_adc_dsin
    );
                                    
    sig_pic_dump_req <= '1';
    sig_pic_debug <= '1';
    sig_pic_data <= std_logic_vector(sig_pic_data_dbg) when sig_pic_debug = '1' else 
                    (others => '0');
    
    -- Dummy counter for PIC data
    process(sig_clk_pic, sig_reset)
    begin
        if sig_reset = '1' then
            sig_pic_data_dbg <= (others => '0');
            sig_pic_data_rden_d <= '0';
        elsif rising_edge(sig_clk_pic) then
            sig_pic_data_rden_d <= sig_pic_data_rden;
            if sig_pic_data_rden_d = '1' then
                sig_pic_data_dbg <= sig_pic_data_dbg + 1;
            end if;
        end if;
    end process;
    
    PicController: entity work.PicController
    port map (
    	in_reset 		=> sig_reset,
    	in_clk			=> sig_clk_pic,
    	-- Commands
    	in_dump_req		=> sig_pic_dump_req,
    	out_dump_busy	=> open,
    	in_ignore_fifo	=> sig_pic_debug,
    	-- FIFO ports
    	in_fifo_full	=> '0',
    	out_fifo_rdreq	=> sig_pic_data_rden,
    	in_fifo_data	=> sig_pic_data,
    	-- PIC port
    	in_pic_rdy		=> in_pic_rdy,
    	out_data		=> out_pic_data
    );
    
    pwm_cha: entity work.PulseWidthModulator
	port map( 
		in_clk 			=> in_adc_dclk,
		in_reset 		=> sig_reset,
		in_duty_cycle 	=> sig_adc_cha,
		out_pwm 		=> inout_gpio(1)
	);
    
    pwm_chb: entity work.PulseWidthModulator
	port map( 
		in_clk 			=> in_adc_dclk,
		in_reset 		=> sig_reset,
		in_duty_cycle 	=> sig_adc_chb,
		out_pwm 		=> inout_gpio(2)
	);    
     
end;