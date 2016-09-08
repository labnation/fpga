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

package types is

constant sz_register					: integer := 8;

subtype type_register        is unsigned(sz_register - 1 downto 0);
subtype type_double_register is unsigned(sz_register * 2 - 1 downto 0);
subtype type_tri_register    is unsigned(sz_register * 3 - 1 downto 0);

type type_registers is array(natural range <>) of type_register;

type type_array_of_integers	is array(natural range <>) of integer;

subtype type_i2c_address	is unsigned(6 downto 0);
type type_i2c_address_list	is array(natural range <>) of type_i2c_address;
subtype type_i2c_byte		is unsigned(7 downto 0);

function to_std_logic(l: boolean) return std_logic;

end types;

package body types is

function to_std_logic(l: boolean) return std_logic is
begin
	if l then
		return('1');
	else
		return('0');
	end if;
end function to_std_logic;

end types;