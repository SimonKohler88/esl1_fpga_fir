library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- SPI physical layer (CPOL=0, CPHA=0, MSB-first, 8-bit)
-- Pure shift register: shifts bytes in from MOSI, out on MISO,
-- pulses byte_valid for one sys-clk cycle after each complete byte.
entity spi_phy is
    port (
        clk       : in  std_logic;  -- system clock
        rst       : in  std_logic;  -- synchronous reset, active high

        -- SPI bus pins
        spi_clk   : in  std_logic;
        spi_cs_n  : in  std_logic;  -- active-low chip select
        spi_mosi  : in  std_logic;
        spi_miso  : out std_logic;

        -- parallel interface (system clock domain)
        tx_data   : in  std_logic_vector(7 downto 0);  -- byte to send on MISO
        tx_load   : in  std_logic;                      -- load tx_data into shift reg
        rx_data   : out std_logic_vector(7 downto 0);   -- received byte
        byte_valid: out std_logic                        -- one sys-clk pulse per byte
    );
end entity spi_phy;

architecture rtl of spi_phy is

    -- synchroniser stages for SPI signals into sys-clk domain
    signal spi_clk_meta, spi_clk_sync  : std_logic := '0';
    signal spi_cs_meta,  spi_cs_sync   : std_logic := '1';
    signal spi_mosi_meta, spi_mosi_sync: std_logic := '0';

    -- edge detection
    signal spi_clk_prev : std_logic := '0';
    signal spi_clk_rise : std_logic;
    signal spi_clk_fall : std_logic;

    -- shift register
    signal shift_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal bit_cnt   : unsigned(2 downto 0) := (others => '0');

    signal byte_done : std_logic := '0';
    signal byte_buffer : std_logic_vector(7 downto 0) := (others => '0');

begin

    -- 2-FF synchronisers
    p_sync : process(clk)
    begin
        if rising_edge(clk) then
            spi_clk_meta  <= spi_clk;
            spi_clk_sync  <= spi_clk_meta;
            spi_cs_meta   <= spi_cs_n;
            spi_cs_sync   <= spi_cs_meta;
            spi_mosi_meta <= spi_mosi;
            spi_mosi_sync <= spi_mosi_meta;
        end if;
    end process;

    -- edge detect on synchronised SPI clock
    p_edge : process(clk)
    begin
        if rising_edge(clk) then
            spi_clk_prev <= spi_clk_sync;
        end if;
    end process;

    spi_clk_rise <= '1' when spi_clk_sync = '1' and spi_clk_prev = '0' else '0';
    spi_clk_fall <= '1' when spi_clk_sync = '0' and spi_clk_prev = '1' else '0';

    -- shift register & bit counter
    p_shift : process(clk)
    begin
        if rising_edge(clk) then
            byte_done <= '0';

            if rst = '1' or spi_cs_sync = '1' then
                -- deselected: reset counter
                bit_cnt   <= (others => '0');
                shift_reg <= (others => '0');
            else
                -- CPHA=0: sample MOSI on rising edge
                if spi_clk_rise = '1' then
                    shift_reg <= shift_reg(6 downto 0) & spi_mosi_sync;
                    if bit_cnt = 7 then
                        bit_cnt   <= (others => '0');
                        byte_done <= '1';
                        byte_buffer <= shift_reg(6 downto 0) & spi_mosi_sync; -- capture full byte
                    else
                        bit_cnt <= bit_cnt + 1;
                    end if;
                end if;

                -- load tx data from upper layer
                if tx_load = '1' then
                    shift_reg <= tx_data;
                end if;
            end if;
        end if;
    end process;

    -- CPHA=0: update MISO on falling edge (or on CS assert / tx_load)
    p_miso : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' or spi_cs_sync = '1' then
                spi_miso <= '0';
            elsif tx_load = '1' then
                -- immediately present MSB of new tx byte
                spi_miso <= tx_data(7);
            elsif spi_clk_fall = '1' then
                spi_miso <= shift_reg(7);
            end if;
        end if;
    end process;

    -- outputs
    rx_data    <= byte_buffer;
    byte_valid <= byte_done;

end architecture rtl;
