
# Entity: codec_top 
- **File**: codec_top.vhd
- **Title:**  Codec Top-Level (Mono Interface, Avalon-ST Compliant)
- **File:**  codec_top.vhd
- **Author:**  Benedikt Sele
- **Version:**  1.3
- **Date:**  10.11.2025
- **Brief:**  Mono I²S codec interface for Wolfson WM8731 with Avalon-ST bridging.

## Diagram
![Diagram](codec_top.svg "Diagram")
## Description


Generates all required clocks (via PLL), configures the WM8731 codec via I²C,
and bridges between I²S audio and Avalon-ST streaming interfaces for FIR connection.
Only the left channel is used (mono). Each 48 kHz audio frame transfers one 16-bit sample.

**Instantiation Credits**
- PLL (`ime_vga_audio_pll`)
- Codec configuration (`codec_i2c_top`)
- I²S interface (`codec_if`)
provided by **Prof. Michael Pichler (FHNW IME)**

**Avalon-ST Interface Behavior**
- *ADC → FIR (Source)*
- `Av_S_AUDIO_IN`: 16-bit sample captured from ADC
- `Av_S_AUDIO_IN_valid`: asserted once per 48 kHz frame when new data available
- `Av_S_AUDIO_IN_ready`: from FIR; acknowledges acceptance
- if `ready='0'`, the current sample is skipped

- *FIR → DAC (Sink)*
- `Av_S_AUDIO_OUT`: 16-bit filtered sample
- `Av_S_AUDIO_OUT_valid`: high when new FIR output available
- `Av_S_AUDIO_OUT_ready`: asserted once per 48 kHz frame to request new sample
- when both high → sample latched and sent to DAC

**Clocks**
- `clk_50`      : 50 MHz system clock
- `SYS_CLCK`    : 18.432 MHz system clock (PLL output)
- `clk_48k`     : derived sample-rate clock
- `BCLCK`       : 1.536 MHz I²S bit clock
- `XCK`         : 18 MHz master clock to codec

**Direction Summary**
- `ADC → FIR`  : Source (Avalon-ST producer)
- `FIR → DAC`  : Sink   (Avalon-ST consumer)

## Ports

| Port name            | Direction | Type                          | Description                        |
| -------------------- | --------- | ----------------------------- | ---------------------------------- |
| clk_50               | in        | std_logic                     | 50 MHz reference clock             |
| rst_n                | in        | std_logic                     | Global active-low reset            |
| I2C_CLCK             | out       | std_logic                     | I²C serial clock to WM8731         |
| I2C_DATA             | inout     | std_logic                     | I²C bidirectional data line        |
| ADC_DAT              | in        | std_logic                     | Serial audio data in (ADC)         |
| DAC_DAT              | out       | std_logic                     | Serial audio data out (DAC)        |
| ADC_LR_SEL           | out       | std_logic                     | ADC L/R select (48 kHz frame sync) |
| DAC_LR_SEL           | out       | std_logic                     | DAC L/R select (48 kHz frame sync) |
| BCLCK                | out       | std_logic                     | I²S bit clock (1.536 MHz)          |
| XCK                  | out       | std_logic                     | Master clock (18 MHz)              |
| Av_S_AUDIO_OUT       | in        | std_logic_vector(15 downto 0) | FIR → DAC sample                   |
| Av_S_AUDIO_OUT_valid | in        | std_logic                     | FIR sample valid                   |
| Av_S_AUDIO_OUT_ready | out       | std_logic                     | Request next sample                |
| Av_S_AUDIO_IN        | out       | std_logic_vector(15 downto 0) | ADC → FIR sample                   |
| Av_S_AUDIO_IN_valid  | out       | std_logic                     | ADC sample valid                   |
| Av_S_AUDIO_IN_ready  | in        | std_logic                     | FIR ready flag                     |

## Signals

| Name           | Type                          | Description |
| -------------- | ----------------------------- | ----------- |
| SYS_CLCK       | std_logic                     |             |
| clk_48k        | std_logic                     |             |
| locked         | std_logic                     |             |
| adc_sample_reg | std_logic_vector(15 downto 0) |             |
| dac_sample_48k | std_logic_vector(15 downto 0) |             |
| dac_sample_50m | std_logic_vector(15 downto 0) |             |
| clk48k_ff1     | std_logic                     |             |
| clk48k_ff2     | std_logic                     |             |
| frame_stb_50m  | std_logic                     |             |

## Processes
- sync_48k_to_50m: ( clk_50, rst_n )
- adc_to_fir_proc: ( clk_50, rst_n )
- fir_to_dac_proc_50m: ( clk_50, rst_n )
- fir_to_dac_proc_48k: ( clk_48k, rst_n )

## Instantiations

- i_pll: work.ime_vga_audio_pll
- i_i2c_cfg: work.codec_i2c_top
- i_codec_if: work.codec_if
