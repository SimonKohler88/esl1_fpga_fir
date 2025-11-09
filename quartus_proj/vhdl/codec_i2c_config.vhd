--------------------------------------------------------------------------------
-- Project : DE2-35 Framework
--------------------------------------------------------------------------------
-- File    : codec_i2c_config.vhd
-- Library : ime_lib
-- Author  : michael.pichler@fhnw.ch
-- Company : Institute of Microelectronics (IME) FHNW
--------------------------------------------------------------------------------
-- Description : Configuration sequence for the codec
--------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

ENTITY codec_i2c_config IS
  GENERIC (
    --  Look-up table length
    CONSTANT g_lut_size          : unsigned(5 DOWNTO 0) := "110100";  -- = 51 entries
    --  I2C Address Table
    CONSTANT g_audio_i2c_address : unsigned(7 DOWNTO 0) := x"34";
    CONSTANT g_video_i2c_address : unsigned(7 DOWNTO 0) := x"40";
    --  Audio Data Index
    CONSTANT g_reset             : unsigned(5 DOWNTO 0) := "00" & x"0";
    CONSTANT g_set_lin_l         : unsigned(5 DOWNTO 0) := "00" & x"1";
    CONSTANT g_set_lin_r         : unsigned(5 DOWNTO 0) := "00" & x"2";
    CONSTANT g_set_head_l        : unsigned(5 DOWNTO 0) := "00" & x"3";
    CONSTANT g_set_head_r        : unsigned(5 DOWNTO 0) := "00" & x"4";
    CONSTANT g_a_path_ctrl       : unsigned(5 DOWNTO 0) := "00" & x"5";
    CONSTANT g_d_path_ctrl       : unsigned(5 DOWNTO 0) := "00" & x"6";
    CONSTANT g_power_on          : unsigned(5 DOWNTO 0) := "00" & x"7";
    CONSTANT g_set_format        : unsigned(5 DOWNTO 0) := "00" & x"8";
    CONSTANT g_sample_ctrl       : unsigned(5 DOWNTO 0) := "00" & x"9";
    CONSTANT g_set_active        : unsigned(5 DOWNTO 0) := "00" & x"A";
    --  Video Data Index
    CONSTANT g_set_video         : unsigned(5 DOWNTO 0) := "00" & x"B"
    );

  PORT (
    --  System signals
    clk     : IN  std_logic;
    rst_n   : IN  std_logic;
    --  Host control
    wr_data : OUT std_logic_vector(23 DOWNTO 0);  -- Slave_addr, sub_addr,data
    wr_go   : OUT std_logic;                      -- Go transfer
    wr_end  : IN  std_logic                       -- End transfer
    );

END ENTITY codec_i2c_config;

--------------------------------------------------------------------------------

ARCHITECTURE rtl OF codec_i2c_config IS

  TYPE t_i2c_config_states IS (start, wait_for_end_to_go_away, wait_for_end_to_come_back, finish);
  SIGNAL current_state  : t_i2c_config_states;
  SIGNAL next_state     : t_i2c_config_states;

  SIGNAL wr_go_i        : std_logic;
  SIGNAL wr_go_update   : std_logic;

  SIGNAL wr_data_i      : std_logic_vector(23 DOWNTO 0);
  SIGNAL wr_next_data   : std_logic_vector(23 DOWNTO 0);

  SIGNAL lut_data       : unsigned(15 DOWNTO 0);
  SIGNAL next_lut_data  : unsigned(15 DOWNTO 0);

  SIGNAL lut_index      : unsigned(5 DOWNTO 0);
  SIGNAL lut_next_index : unsigned(5 DOWNTO 0);

  --------------------------------------------------------------------
  -- Simulation constants (locally static equivalents for GHDL)
  --------------------------------------------------------------------
  constant C_RESET          : integer := 0;
  constant C_SET_LIN_L      : integer := 1;
  constant C_SET_LIN_R      : integer := 2;
  constant C_SET_HEAD_L     : integer := 3;
  constant C_SET_HEAD_R     : integer := 4;
  constant C_A_PATH_CTRL    : integer := 5;
  constant C_D_PATH_CTRL    : integer := 6;
  constant C_POWER_ON       : integer := 7;
  constant C_SET_FORMAT     : integer := 8;
  constant C_SAMPLE_CTRL    : integer := 9;
  constant C_SET_ACTIVE     : integer := 10;
  constant C_SET_VIDEO      : integer := 11;

BEGIN

  --------------------------------------------------------------------
  -- Configuration Control
  --------------------------------------------------------------------
  p_i2c_config_comb : PROCESS (current_state, wr_end, lut_index, lut_data, wr_data_i)
    VARIABLE v_next_state     : t_i2c_config_states;
    VARIABLE v_wr_next_data   : std_logic_vector(23 DOWNTO 0);
    VARIABLE v_lut_next_index : unsigned(5 DOWNTO 0);
    VARIABLE v_next_lut_data  : unsigned(15 DOWNTO 0);
    VARIABLE v_wr_go          : std_logic;
  BEGIN

    v_wr_go          := '0';
    v_lut_next_index := lut_index;
    v_next_state     := start;
    v_wr_next_data   := wr_data_i;

    -- only run through table once
    IF lut_index = g_lut_size THEN
      v_next_state := current_state;
    ELSE
      CASE current_state IS
        WHEN start =>
          IF lut_index = g_lut_size - 1 THEN
            v_wr_next_data := x"8B0000";
          ELSIF lut_index < g_set_video THEN
            v_wr_next_data := std_logic_vector(g_audio_i2c_address & lut_data);
          ELSE
            v_wr_next_data := std_logic_vector(g_video_i2c_address & lut_data);
          END IF;
          v_wr_go      := '1';
          v_next_state := wait_for_end_to_go_away;

        WHEN wait_for_end_to_go_away =>
          IF wr_end = '0' THEN
            v_next_state := wait_for_end_to_come_back;
          ELSE
            v_next_state := wait_for_end_to_go_away;
          END IF;

        WHEN wait_for_end_to_come_back =>
          IF wr_end = '1' THEN
            v_next_state := finish;
          ELSE
            v_next_state := wait_for_end_to_come_back;
          END IF;

        WHEN finish =>
          v_lut_next_index := lut_index + 1;
          v_next_state     := start;

        WHEN OTHERS =>
          v_next_state := start;
      END CASE;
    END IF;

    --------------------------------------------------------------------
    -- Lookup table (WM8731 + ADV7181B)
    --------------------------------------------------------------------
    CASE to_integer(v_lut_next_index) IS
      WHEN C_RESET          => v_next_lut_data := x"1E00";
      WHEN C_SET_LIN_L      => v_next_lut_data := x"0017";
      WHEN C_SET_LIN_R      => v_next_lut_data := x"0217";
      WHEN C_SET_HEAD_L     => v_next_lut_data := x"047B";
      WHEN C_SET_HEAD_R     => v_next_lut_data := x"067B";
      WHEN C_A_PATH_CTRL    => v_next_lut_data := x"0812";
      WHEN C_D_PATH_CTRL    => v_next_lut_data := x"0A06";
      WHEN C_POWER_ON       => v_next_lut_data := x"0C00";
      WHEN C_SET_FORMAT     => v_next_lut_data := x"0E01";
      WHEN C_SAMPLE_CTRL    => v_next_lut_data := x"1002";
      WHEN C_SET_ACTIVE     => v_next_lut_data := x"1201";
      WHEN C_SET_VIDEO + 0  => v_next_lut_data := x"1500";
      WHEN C_SET_VIDEO + 1  => v_next_lut_data := x"1741";
      WHEN C_SET_VIDEO + 2  => v_next_lut_data := x"3A16";
      WHEN C_SET_VIDEO + 3  => v_next_lut_data := x"5004";
      WHEN C_SET_VIDEO + 4  => v_next_lut_data := x"C305";
      WHEN C_SET_VIDEO + 5  => v_next_lut_data := x"C480";
      WHEN C_SET_VIDEO + 6  => v_next_lut_data := x"0E80";
      WHEN C_SET_VIDEO + 7  => v_next_lut_data := x"5020";
      WHEN C_SET_VIDEO + 8  => v_next_lut_data := x"5218";
      WHEN C_SET_VIDEO + 9  => v_next_lut_data := x"58ED";
      WHEN C_SET_VIDEO + 10 => v_next_lut_data := x"77C5";
      WHEN C_SET_VIDEO + 11 => v_next_lut_data := x"7C93";
      WHEN C_SET_VIDEO + 12 => v_next_lut_data := x"7D00";
      WHEN C_SET_VIDEO + 13 => v_next_lut_data := x"D048";
      WHEN C_SET_VIDEO + 14 => v_next_lut_data := x"D5A0";
      WHEN C_SET_VIDEO + 15 => v_next_lut_data := x"D7EA";
      WHEN C_SET_VIDEO + 16 => v_next_lut_data := x"E43E";
      WHEN C_SET_VIDEO + 17 => v_next_lut_data := x"EA0F";
      WHEN C_SET_VIDEO + 18 => v_next_lut_data := x"3112";
      WHEN C_SET_VIDEO + 19 => v_next_lut_data := x"3281";
      WHEN C_SET_VIDEO + 20 => v_next_lut_data := x"3384";
      WHEN C_SET_VIDEO + 21 => v_next_lut_data := x"37A0";
      WHEN C_SET_VIDEO + 22 => v_next_lut_data := x"E580";
      WHEN C_SET_VIDEO + 23 => v_next_lut_data := x"E603";
      WHEN C_SET_VIDEO + 24 => v_next_lut_data := x"E785";
      WHEN C_SET_VIDEO + 25 => v_next_lut_data := x"5000";
      WHEN C_SET_VIDEO + 26 => v_next_lut_data := x"5100";
      WHEN C_SET_VIDEO + 27 => v_next_lut_data := x"0050";
      WHEN C_SET_VIDEO + 28 => v_next_lut_data := x"1000";
      WHEN C_SET_VIDEO + 29 => v_next_lut_data := x"0402";
      WHEN C_SET_VIDEO + 30 => v_next_lut_data := x"0B00";
      WHEN C_SET_VIDEO + 31 => v_next_lut_data := x"0A20";
      WHEN C_SET_VIDEO + 32 => v_next_lut_data := x"1100";
      WHEN C_SET_VIDEO + 33 => v_next_lut_data := x"2B00";
      WHEN C_SET_VIDEO + 34 => v_next_lut_data := x"2C8C";
      WHEN C_SET_VIDEO + 35 => v_next_lut_data := x"2DF2";
      WHEN C_SET_VIDEO + 36 => v_next_lut_data := x"2EEE";
      WHEN C_SET_VIDEO + 37 => v_next_lut_data := x"2FF4";
      WHEN C_SET_VIDEO + 38 => v_next_lut_data := x"30D2";
      WHEN OTHERS           => v_next_lut_data := x"0E05";
    END CASE;

    next_state     <= v_next_state;
    lut_next_index <= v_lut_next_index;
    next_lut_data  <= v_next_lut_data;
    wr_next_data   <= v_wr_next_data;
    wr_go_update   <= v_wr_go;

  END PROCESS p_i2c_config_comb;

  --------------------------------------------------------------------
  -- Sequential register process
  --------------------------------------------------------------------
  p_i2c_config_reg : PROCESS (rst_n, clk)
  BEGIN
    IF rst_n = '0' THEN
      current_state <= start;
      lut_index     <= (OTHERS => '0');
      lut_data      <= (OTHERS => '0');
      wr_data_i     <= (OTHERS => '0');
      wr_go_i       <= '0';
    ELSIF rising_edge(clk) THEN
      current_state <= next_state;
      lut_index     <= lut_next_index;
      lut_data      <= next_lut_data;
      wr_data_i     <= wr_next_data;
      wr_go_i       <= wr_go_update;
    END IF;
  END PROCESS p_i2c_config_reg;

  --------------------------------------------------------------------
  -- Output assignments
  --------------------------------------------------------------------
  wr_data <= wr_data_i;
  wr_go   <= wr_go_i;

END ARCHITECTURE rtl;