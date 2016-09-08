library IEEE;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

package BuildVersion is

-- This is a DUMMY BuildVersion file included in the ISE project
-- When compiling using the build script, this file is NOT USED but
-- generated in the BUILD_DIR with a dynamically updated version nr
constant BUILD_VERSION	:	UNSIGNED(31 DOWNTO 0) 	:=  x"deadbeef";

end BuildVersion;
