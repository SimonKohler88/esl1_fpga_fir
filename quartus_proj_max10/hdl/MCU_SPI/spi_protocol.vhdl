
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.SPI_CMD_PACKAGE.all;

-- Layer 2: SPI protocol FSM
-- Consumes byte_valid + rx_byte from the PHY, drives tx_byte/tx_load back.
-- Command format: bit 7 = R/W (1=read, 0=write), bits 6:0 = command Nr.
-- Fixed payload per command: defined in command list package.

entity spi_protocol is
    port (
        clk        : in  std_logic;
        rst        : in  std_logic;

        -- from/to spi_phy
        phy_rx_data   : in  std_logic_vector(7 downto 0);
        phy_byte_valid: in  std_logic;
        phy_tx_data   : out std_logic_vector(7 downto 0);
        phy_tx_load   : out std_logic;

        -- directly from the SPI bus (active-low, already synchronised in PHY)
        spi_cs_n      : in  std_logic;

        -- bus interface to register bank
        reg_cmd    : out std_logic_vector(6 downto 0);
        reg_byte_nr : out std_logic_vector(8 downto 0);
        reg_wdata  : out std_logic_vector(7 downto 0);
        reg_wr_en  : out std_logic;
        reg_rdata  : in  std_logic_vector(7 downto 0)
    );
end entity spi_protocol;

architecture rtl of spi_protocol is

    type state_t is (S_CMD, S_PAYLOAD);
    signal state      : state_t := S_CMD;

    signal cmd_rw     : std_logic := '0';            -- '1' = read, '0' = write
    signal cmd_nr     : unsigned(6 downto 0) := (others => '0');
    signal byte_cnt   : unsigned(8 downto 0) := (others => '0');  -- payload byte counter
    signal payload_len: unsigned(8 downto 0) := (others => '0');  -- expected payload bytes

    -- CS rising-edge detection (directly on spi_cs_n which is already synchronised)
    signal cs_n_prev  : std_logic := '1';
    signal cs_deassert: std_logic;

begin

    cs_deassert <= '1' when spi_cs_n = '1' and cs_n_prev = '0' else '0';

    p_fsm : process(clk)
        variable v_cmd_idx : integer range 0 to NUM_OF_CMD - 1;
    begin
        if rising_edge(clk) then
            -- defaults: single-cycle pulses
            reg_wr_en  <= '0';
            phy_tx_load <= '0';

            cs_n_prev <= spi_cs_n;

            if rst = '1' or cs_deassert = '1' then
                state     <= S_CMD;
                byte_cnt  <= (others => '0');
                cmd_rw    <= '0';
                cmd_nr    <= (others => '0');
            else
                case state is

                    when S_CMD =>
                        if phy_byte_valid = '1' then
                            cmd_rw  <= phy_rx_data(7);
                            cmd_nr  <= unsigned(phy_rx_data(6 downto 0));

                            -- look up payload length from command list
                            if unsigned(phy_rx_data(6 downto 0)) < NUM_OF_CMD then
                           
                                v_cmd_idx := to_integer(unsigned(phy_rx_data(6 downto 0)));
                                
                                payload_len <= resize(command_list(v_cmd_idx)(0), 9);
                                
                                byte_cnt <= (others => '0');
                                state    <= S_PAYLOAD;
                                
                                -- for reads: pre-load first TX byte so PHY
                                -- can shift it out during the next SPI byte
                                if phy_rx_data(7) = '1' then
                                    phy_tx_load <= '1';
                                end if;
                            end if;
                        end if;

                    when S_PAYLOAD =>
                        if phy_byte_valid = '1' then
                            if cmd_rw = '0' then
                                -- write: forward received byte to register bank
                                reg_wr_en <= '1';
                            else
                                -- read: load next TX byte for following transfer
                                phy_tx_load <= '1';
                            end if;

                            byte_cnt <= byte_cnt + 1;
                        end if;

                end case;
            end if;
        end if;
    end process;

    -- register-bank address / data outputs (active in S_PAYLOAD)
    reg_cmd     <= std_logic_vector(cmd_nr);
    reg_byte_nr <= std_logic_vector(byte_cnt);
    reg_wdata   <= phy_rx_data;

    -- read data from register bank feeds PHY TX
    phy_tx_data <= reg_rdata;

end architecture rtl;
