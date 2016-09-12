library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gainctrl is
	port ( 
		in_clk 						: in  std_logic;
		in_reset					: in  std_logic;
		in_gain				        : in  unsigned(3 downto 0);
		out_div1_relay_pulse_off 	: out std_logic;
		out_div1_relay_pulse_on 	: out std_logic;
		out_div10_100_selector		: out std_logic;
        out_mul                     : out unsigned(1 downto 0)
	);
end gainctrl;

architecture behavioral of gainctrl is

type t_gain_setting is record
    multiplier      : integer range 0 to 2;
    divider_power   : integer range 0 to 2;
end record t_gain_setting;

type t_gain_setting_map is array(natural range <>) of t_gain_setting;

constant gain_setting_map : t_gain_setting_map(15 downto 0) := (
    0 => ( multiplier => 0, divider_power => 2), -- /36
    1 => ( multiplier => 1, divider_power => 2), -- /18
    2 => ( multiplier => 2, divider_power => 2), -- /12
    3 => ( multiplier => 0, divider_power => 1), -- /6
    4 => ( multiplier => 1, divider_power => 1), -- /3
    5 => ( multiplier => 2, divider_power => 1), -- /2
    6 => ( multiplier => 0, divider_power => 0), -- /1
    7 => ( multiplier => 1, divider_power => 0), -- * 2
    8 => ( multiplier => 2, divider_power => 0), -- * 3
    others => ( multiplier => 0, divider_power => 2) -- 36
);

signal divider_power : unsigned(1 downto 0) := "00";

begin
    
out_mul <= to_unsigned(gain_setting_map(to_integer(in_gain)).multiplier, 2);
divider_power <= to_unsigned(gain_setting_map(to_integer(in_gain)).divider_power, 2);
divider_control: entity work.divisionstrobetosignals
port map( 
	in_clk 						=> in_clk,
	in_reset					=> in_reset,
	in_power_of_10				=> divider_power,
	out_div1_relay_pulse_off 	=> out_div1_relay_pulse_off,
	out_div1_relay_pulse_on 	=> out_div1_relay_pulse_on,
	out_div10_100_selector		=> out_div10_100_selector
);


end behavioral;

