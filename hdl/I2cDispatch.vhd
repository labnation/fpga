library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;
use work.constants.i2c_address_settings;
use work.constants.i2c_address_rom;
use work.constants.i2c_address_user;

entity I2cDispatch is
    generic (
        n_regs      : natural := 1;
        n_regs_user : natural := 256;
        n_roms      : natural := 1
    );
    port (
        in_clk                      : in    std_logic;
        in_reset                    : in    std_logic;

        inout_sda                   : inout std_logic;
        in_scl                      : in    std_logic;

        out_registers               : out   type_registers(n_regs - 1 downto 0);
        out_registers_user          : out   type_registers(n_regs_user - 1 downto 0);
        in_rom                      : in    type_registers(n_roms - 1 downto 0)
    );
end I2cDispatch;

architecture rtl of I2cDispatch is

signal regmap_reg                   : type_registers(n_regs - 1 downto 0);
signal regmap_update_vect           : std_logic_vector(n_regs-1 downto 0);
signal regmap_user_reg              : type_registers(n_regs_user - 1 downto 0);
signal regmap_user_update_vect      : std_logic_vector(n_regs_user-1 downto 0);

signal sig_i2c_busy                 : std_logic;
signal sig_i2c_device_address       : type_i2c_address;
signal sig_i2c_device_address_valid : std_logic;
signal sig_i2c_device_address_current: type_i2c_address;
signal sig_i2c_data_tx              : type_i2c_byte;
signal sig_i2c_data_tx_rden         : std_logic;
signal sig_i2c_data_rx              : type_i2c_byte;
signal sig_i2c_data_rx_valid        : std_logic;
signal sig_i2c_data_rx_valid_d      : std_logic;
signal sig_i2c_data_rx_valid_re     : std_logic;
signal sig_first_byte               : std_logic;

signal sig_register_address         : std_logic_vector(7 downto 0);
signal i2c_regmap_wren              : std_logic;
signal i2c_regmap_wrdata            : std_logic_vector(7 downto 0);
signal i2c_regmap_wraddr            : std_logic_vector(5 downto 0);
signal i2c_regmap_rdaddr            : std_logic_vector(5 downto 0);
signal i2c_regmap_rdata             : std_logic_vector(7 downto 0);

signal i2c_regmap_user_wren         : std_logic;
signal i2c_regmap_user_rdata        : std_logic_vector(7 downto 0);

begin

--------------------------------------------------------------------------------
-- i2c slave
--------------------------------------------------------------------------------

i2c_protocol: entity work.i2cprotocol
generic map (
    listen_addresses => ( i2c_address_settings, i2c_address_user, i2c_address_rom )
)
port map (
        in_clk                      => in_clk,
        in_reset                    => in_reset,

        in_scl                      => in_scl,
        inout_sda                   => inout_sda,

    -- control signals
        out_busy                    => sig_i2c_busy,

        out_device_address          => sig_i2c_device_address,
        out_device_address_valid    => sig_i2c_device_address_valid,

        in_data_tx                  => sig_i2c_data_tx,
        out_data_tx_rden            => sig_i2c_data_tx_rden,

        out_data_rx                 => sig_i2c_data_rx,
        out_data_rx_valid           => sig_i2c_data_rx_valid
);

--------------------------------------------------------------------------------
-- i2c regmap ramblock
--------------------------------------------------------------------------------

process(sig_i2c_data_rx_valid_re, sig_i2c_device_address_current, sig_first_byte, i2c_regmap_wren)
begin
    if sig_i2c_data_rx_valid_re = '1' and sig_i2c_device_address_current = i2c_address_settings and sig_first_byte = '0' then
        i2c_regmap_wren     <=  '1';
    else
        i2c_regmap_wren     <=  '0';
    end if;
end process;

process(sig_i2c_data_rx_valid_re, sig_i2c_device_address_current, sig_first_byte, i2c_regmap_user_wren)
begin
    if sig_i2c_data_rx_valid_re = '1' and sig_i2c_device_address_current = i2c_address_user and sig_first_byte = '0' then
        i2c_regmap_user_wren     <=  '1';
    else
        i2c_regmap_user_wren     <=  '0';
    end if;
end process;

i2c_regmap_wrdata   <=  std_logic_vector(sig_i2c_data_rx);
i2c_regmap_wraddr   <=  sig_register_address(i2c_regmap_wraddr'range);
i2c_regmap_rdaddr   <=  sig_register_address(i2c_regmap_rdaddr'range);

i2c_regmap : entity work.i2c_regs_ramb
  port map(
    clka        => in_clk,
    wea(0)      => i2c_regmap_wren,
    addra       => i2c_regmap_wraddr,
    dina        => i2c_regmap_wrdata,
    clkb        => in_clk,
    addrb       => i2c_regmap_rdaddr,
    doutb       => i2c_regmap_rdata
  );
  
i2c_regmap_user : entity work.i2c_regs_ramb
port map(
  clka        => in_clk,
  wea(0)      => i2c_regmap_user_wren,
  addra       => i2c_regmap_wraddr,
  dina        => i2c_regmap_wrdata,
  clkb        => in_clk,
  addrb       => i2c_regmap_rdaddr,
  doutb       => i2c_regmap_user_rdata
);  

--------------------------------------------------------------------------------
-- smart regmap system
--------------------------------------------------------------------------------

regmap_update_sig_gen : for i in 0 to n_regs-1 generate

process(in_reset, in_clk)
begin
    if in_reset = '1' then
        regmap_update_vect(i)   <=  '0';
    elsif rising_edge(in_clk) then
        regmap_update_vect(i)   <=  '0';
        if i2c_regmap_wraddr = std_logic_vector(to_unsigned(i, i2c_regmap_wraddr'length)) then
            regmap_update_vect(i)   <=  i2c_regmap_wren;
        end if;
    end if;
end process;

process(in_reset, in_clk)
begin
    if in_reset = '1' then
        regmap_reg(i)   <=  (others => '0');
    elsif rising_edge(in_clk) then
        if regmap_update_vect(i) = '1' then
            regmap_reg(i)   <=  unsigned(i2c_regmap_wrdata);
        end if;
    end if;
end process;

end generate regmap_update_sig_gen;

out_registers   <=  regmap_reg;


regmap_update_sig_user_gen : for i in 0 to n_regs_user-1 generate

process(in_reset, in_clk)
begin
    if in_reset = '1' then
        regmap_user_update_vect(i)   <=  '0';
    elsif rising_edge(in_clk) then
        regmap_user_update_vect(i)   <=  '0';
        if i2c_regmap_wraddr = std_logic_vector(to_unsigned(i, i2c_regmap_wraddr'length)) then
            regmap_user_update_vect(i)   <=  i2c_regmap_user_wren;
        end if;
    end if;
end process;

process(in_reset, in_clk)
begin
    if in_reset = '1' then
        regmap_user_reg(i)   <=  (others => '0');
    elsif rising_edge(in_clk) then
        if regmap_user_update_vect(i) = '1' then
            regmap_user_reg(i)   <=  unsigned(i2c_regmap_wrdata);
        end if;
    end if;
end process;

end generate regmap_update_sig_user_gen;

out_registers_user   <=  regmap_user_reg;

--------------------------------------------------------------------------------
-- control logic
--------------------------------------------------------------------------------

proc_rx_valid_edge: process(in_reset, in_clk)
begin
    if in_reset = '1' then
        sig_i2c_data_rx_valid_d <= '0';
    elsif rising_edge(in_clk) then
        sig_i2c_data_rx_valid_d <= sig_i2c_data_rx_valid;
    end if;
end process;
sig_i2c_data_rx_valid_re <= sig_i2c_data_rx_valid and not sig_i2c_data_rx_valid_d;

proc_memory_mux: process(in_reset, in_clk)
begin
    if in_reset = '1' then
        sig_i2c_device_address_current  <=  (others => '1');
        sig_first_byte                  <=  '1';
        sig_register_address            <=  (others => '0');
    elsif rising_edge(in_clk) then
        -- store the device address
        if sig_i2c_device_address_valid = '1' then
            sig_i2c_device_address_current  <= sig_i2c_device_address;
            sig_first_byte                  <= '1';
        end if;

        -- update address
        if sig_i2c_data_rx_valid_re = '1' then
            if sig_first_byte = '1' then
                sig_first_byte          <= '0';
                sig_register_address    <= std_logic_vector(resize(sig_i2c_data_rx, sig_register_address'length));
            else
                sig_register_address    <= std_logic_vector(unsigned(sig_register_address) + 1);
            end if;
        -- transmitting data - update register, mux below process
        elsif sig_i2c_data_tx_rden = '1' then
            sig_register_address    <= std_logic_vector(unsigned(sig_register_address) + 1);
        end if;
    end if;
end process;

sig_i2c_data_tx <=  unsigned(i2c_regmap_rdata)      when sig_i2c_device_address_current = i2c_address_settings else
                    unsigned(i2c_regmap_user_rdata) when sig_i2c_device_address_current = i2c_address_user else
                    in_rom(to_integer(unsigned(sig_register_address)));

--------------------------------------------------------------------------------

end rtl;