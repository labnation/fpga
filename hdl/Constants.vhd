--
--	package file template
--
--	purpose: this package defines supplemental types, subtypes, 
--		 constants, and functions 
--
--   to use any of the example code shown below, uncomment the lines and modify as necessary
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.ceil;
use ieee.math_real.log2;
use work.types.type_i2c_address;

package constants is

constant reg_power				: integer := 0;
constant b_power_rst            : integer := 0;
constant b_power_negen          : integer := 1;
constant b_power_digi_3v_5v     : integer := 2;
constant b_power_opa_b_en       : integer := 3;

constant reg_spi_addr           : integer := 1;
constant reg_spi_value          : integer := 2;
constant reg_cha_gain           : integer := 3;
constant reg_chb_gain           : integer := 4;
constant reg_cha_ypos           : integer := 5;
constant reg_chb_ypos           : integer := 6;

constant reg_flags              : integer := 7;
constant b_flags_spi_cmd        : integer := 0;
constant b_flags_cha_ac_dc      : integer := 1;
constant b_flags_chb_ac_dc      : integer := 2;

constant number_of_registers    : integer := 39;

-- rom
constant rom_fw_git0	  				: integer := 0;
constant rom_fw_git1	  				: integer := 1;
constant rom_fw_git2	  				: integer := 2;
constant rom_fw_git3	  				: integer := 3;
constant rom_spi_received_value 		: integer := 4;
constant number_of_roms					: integer := 5;

constant bytes_per_pic_burst			: natural := 64;
constant bytes_per_pic_burst_log2		: natural := natural(ceil(log2(real(bytes_per_pic_burst))));

constant i2c_address_settings :	type_i2c_address := "0001100";
constant i2c_address_rom      :	type_i2c_address := "0001101";
constant i2c_address_user     :	type_i2c_address := "0001110";

end constants;