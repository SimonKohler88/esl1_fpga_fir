
# Entity: esl_fir_filter 
- **File**: esl_fir_filter.vhdl
- **Title:**  ESL FIR Filter Top-Level (DE1-SoC Audio Processing System)
- **File:**  esl_fir_filter.vhdl
- **Version:**  1.0
- **Date:**  2025-11-10
- **Brief:**  System top-level integrating WM8731 codec, UART→FIR coefficient loader, and FIR core.

## Diagram
![Diagram](esl_fir_filter.svg "Diagram")
## Description


Provides the complete top-level system used for programmable audio filtering on the
Intel/Terasic DE1-SoC FPGA board.

**Subsystem Overview**
- `codec_top`
Generates I²S clocks, configures WM8731 via I²C, streams ADC samples into Avalon-ST,
forwards DAC samples out.

- `uart`
Nios-II driven UART interface. Receives new FIR coefficients (64×16-bit) and updates
the FIR register file dynamically.

- `FIR_Filter`
64-tap, 16-bit MAC-based FIR running at 50 MHz. Samples flow via Avalon-ST handshake.

**Board Integration**
- All audio paths use the DE1-SoC onboard WM8731 codec
- HEX displays disabled (all segments off)
- LEDs show runtime status:
* LEDR(9) = 1 Hz alive blink
* LEDR(8 downto 1) = UART PIO debug
* LEDR(0) = alive indicator LSB

**UART Wiring**
- TX: GPIO_0(0)
- RX: GPIO_1(0)

**Reset**
- Active-low global reset through KEY(0)

**Clocks**
- `CLOCK_50` is the only required input clock (50 MHz)

This top-level is intentionally minimal and exposes only I/O required by
typical incoming student projects.

## Ports

| Port name     | Direction | Type                          | Description                 |
| ------------- | --------- | ----------------------------- | --------------------------- |
| CLOCK_50      | in        | std_logic                     | 50 MHz system clock         |
| KEY           | in        | std_logic_vector(3 downto 0)  | Push buttons (active low)   |
| SW            | in        | std_logic_vector(9 downto 0)  | DIP switches                |
| LEDR          | out       | std_logic_vector(9 downto 0)  | Red LEDs                    |
| HEX0          | out       | std_logic_vector(6 downto 0)  | 7-segment display           |
| HEX1          | out       | std_logic_vector(6 downto 0)  |                             |
| HEX2          | out       | std_logic_vector(6 downto 0)  |                             |
| HEX3          | out       | std_logic_vector(6 downto 0)  |                             |
| HEX4          | out       | std_logic_vector(6 downto 0)  |                             |
| HEX5          | out       | std_logic_vector(6 downto 0)  |                             |
| AUD_ADCDAT    | in        | std_logic                     | Serial ADC data (I²S SDIN)  |
| AUD_DACDAT    | out       | std_logic                     | Serial DAC data (I²S SDOUT) |
| AUD_BCLK      | out       | std_logic                     | I²S bit clock               |
| AUD_DACLRCK   | out       | std_logic                     | LRCLK for DAC               |
| AUD_ADCLRCK   | out       | std_logic                     | LRCLK for ADC               |
| AUD_XCK       | out       | std_logic                     | Master clock (18.432 MHz)   |
| FPGA_I2C_SDAT | inout     | std_logic                     | I²C data                    |
| FPGA_I2C_SCLK | out       | std_logic                     | I²C clock                   |
| GPIO_0        | out       | std_logic_vector(35 downto 0) | UART TX at bit 0            |
| GPIO_1        | in        | std_logic_vector(35 downto 0) | UART RX at bit 0            |

## Signals

| Name                    | Type                          | Description        |
| ----------------------- | ----------------------------- | ------------------ |
| reset_n                 | std_logic                     |                    |
| blink_counter           | unsigned(24 downto 0)         |                    |
| alive                   | std_logic                     |                    |
| nios_pio_data           | std_logic_vector(7 downto 0)  | Debug from Nios-II |
| FIR_Coeffs              | FIR_type_coeffs               | 64×16-bit coeffs   |
| sig_uart_rxd            | std_logic                     |                    |
| sig_uart_txd            | std_logic                     |                    |
| sig_AVS_audio_in        | std_logic_vector(15 downto 0) |                    |
| sig_AVS_audio_in_valid  | std_logic                     |                    |
| sig_AVS_audio_in_ready  | std_logic                     |                    |
| sig_AVS_audio_out       | std_logic_vector(15 downto 0) |                    |
| sig_AVS_audio_out_valid | std_logic                     |                    |
| sig_AVS_audio_out_ready | std_logic                     |                    |

## Constants

| Name        | Type    | Value    | Description                |
| ----------- | ------- | -------- | -------------------------- |
| HALF_PERIOD | integer | 25000000 | CLOCK_50 / 2 → 1 Hz toggle |

## Processes
- blink_proc: ( all )

## Instantiations

- u0: uart
- f0: FIR_Filter
- codec0: codec_top
