-------------------------------------------------------------------------------
-- File        : ram.vhd
-- Project     : qmtech-workspace / ram_test
-- Standard    : IEEE 1076-2008 (VHDL), IEEE 1164 (std_logic)
-- Description : Synchronous single-port RAM, initialized from a constant
--               array at elaboration time.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ram is
    generic (
        g_width : integer := 8;
        g_depth : integer := 16
    );
    port (
        clk  : in  std_logic;
        we   : in  std_logic;
        addr : in  std_logic_vector(3 downto 0);
        din  : in  std_logic_vector(g_width-1 downto 0);
        dout : out std_logic_vector(g_width-1 downto 0)
    );
end entity;

architecture rtl of ram is
    type ram_type is array (0 to g_depth-1) of std_logic_vector(g_width-1 downto 0);

    constant c_init_values : integer_vector(0 to 15) := (
        10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160
    );

    function init_ram return ram_type is
        variable temp_ram : ram_type := (others => (others => '0'));
    begin
        for i in 0 to g_depth - 1 loop
            if i <= c_init_values'high then
                temp_ram(i) := std_logic_vector(to_unsigned(c_init_values(i), g_width));
            end if;
        end loop;
        return temp_ram;
    end function;

    signal r_ram : ram_type := init_ram;
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if we = '1' then
                r_ram(to_integer(unsigned(addr))) <= din;
            end if;
            dout <= r_ram(to_integer(unsigned(addr)));
        end if;
    end process;
end architecture;
