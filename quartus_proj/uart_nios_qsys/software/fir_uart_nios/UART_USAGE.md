# RS232 UART Module - Proper Usage Guide

## Overview

This implementation uses **Option B: Dual Communication Channels** with clean separation:
- **RS232 UART**: User interface and command console
- **JTAG UART**: Debug messages and system diagnostics

## Hardware Configuration

### UART Module (uart_0) Settings
```
Base Address:    0x41400
IRQ:            2
Baud Rate:      115200 bps
Data Bits:      8
Parity:         None
Stop Bits:      1
Flow Control:   None (CTS/RTS disabled)
System Clock:   120 MHz
```

### Pin Connections Required

In your FPGA top-level VHDL/Verilog, ensure UART signals are connected:
```vhdl
-- Connect these signals to your RS232 transceiver
uart_0_rxd : IN  std_logic;   -- UART Receive (from RS232 transceiver)
uart_0_txd : OUT std_logic;   -- UART Transmit (to RS232 transceiver)
```

Check your `.qsf` pin assignment file to ensure proper GPIO mapping.

## Software Architecture

### 1. Interrupt-Driven Buffered Transmission

The implementation uses a **512-byte circular buffer** for TX with interrupt-driven transmission:

```c
// TX Buffer Management
#define TX_BUFFER_SIZE 512  // Configurable: 256, 512, 1024, 2048, etc.
volatile char tx_buffer[TX_BUFFER_SIZE];
volatile uint16_t tx_head = 0;  // Write pointer
volatile uint16_t tx_tail = 0;  // Read pointer (ISR)
```

**Advantages:**
- Non-blocking: `uart_putchar()` returns immediately
- Efficient: CPU freed while UART transmits
- Reliable: No character drops when FIFO is temporarily full
- High throughput: Continuous transmission from buffer
- Auto CRLF: `uart_puts()` automatically converts `\n` to `\r\n` for terminal compatibility

### 2. Error Handling

UART ISR monitors and counts three error types:

```c
volatile uint32_t uart_parity_errors = 0;   // Parity errors (PE)
volatile uint32_t uart_frame_errors = 0;    // Frame errors (FE)
volatile uint32_t uart_overrun_errors = 0;  // Receiver overrun (ROE)
```

These counters are reported periodically via JTAG UART debug channel.

### 3. Interrupt Service Routine (ISR)

The UART ISR handles three operations:

```c
static void uart_isr(void *context)
{
    // 1. ERROR HANDLING - Check PE, FE, ROE status bits
    // 2. RECEIVE HANDLING - Read incoming characters (RRDY)
    // 3. TRANSMIT HANDLING - Send next buffered character (TRDY)
}
```

**Key Features:**
- TX interrupt enabled dynamically (only when buffer has data)
- TX interrupt disabled automatically when buffer empties
- Errors cleared properly by reading RXDATA or writing STATUS

## API Functions

### RS232 UART Functions (User Interface)

#### `int uart_putchar(char c)`
Queue a character for transmission (non-blocking).
- **Returns:** 1 if queued, 0 if buffer full
- **Use for:** Normal output

#### `int uart_putchar_blocking(char c, uint32_t timeout_ms)`
Queue a character with timeout wait (blocking).
- **Returns:** 1 if sent, 0 if timeout
- **Use for:** Critical output that must succeed

#### `void uart_puts(const char *str)`
Send a null-terminated string with automatic CRLF conversion.
- Uses `uart_putchar()` internally
- Automatically converts `\n` to `\r\n` for proper terminal display
- **Use for:** Text messages

#### `void uart_put_int(int num)`
Send a signed integer as ASCII.
- Converts number to string internally
- **Use for:** Numeric output

#### `void uart_flush(void)`
Wait for all buffered data to be transmitted.
- Blocks until TX buffer empty
- **Use before:** Sleep, reset, or critical sections

### JTAG UART Functions (Debug Channel)

#### `void jtag_putchar(char c)`
Send character to JTAG UART (non-blocking, may drop if full).

#### `void jtag_puts(const char *str)`
Send string to JTAG UART.

#### `void jtag_put_int(int num)`
Send integer to JTAG UART.

**Monitor debug output:**
```bash
nios2-terminal
# or
# Quartus Prime -> Tools -> System Console
```

## Initialization Sequence

```c
int main()
{
    // 1. Initialize TX buffer
    tx_head = 0;
    tx_tail = 0;

    // 2. Register UART ISR
    alt_ic_isr_register(UART_0_IRQ_INTERRUPT_CONTROLLER_ID,
                        UART_0_IRQ,
                        uart_isr,
                        NULL,
                        0x0);

    // 3. Clear any pending status
    IOWR_ALTERA_AVALON_UART_STATUS(UART_0_BASE, 0);

    // 4. Enable RX interrupts (TX enabled dynamically)
    IOWR_ALTERA_AVALON_UART_CONTROL(UART_0_BASE,
                                     ALTERA_AVALON_UART_CONTROL_RRDY_MSK);

    // System is now ready for UART communication
}
```

## Usage Examples

### Example 1: Send User Messages
```c
uart_puts("System initialized\n");
uart_puts("Temperature: ");
uart_put_int(temperature);
uart_puts(" degrees\n");
```

### Example 2: Send Debug Messages
```c
jtag_puts("DEBUG: Entering calibration mode\n");
jtag_puts("DEBUG: ADC value = ");
jtag_put_int(adc_reading);
jtag_puts("\n");
```

### Example 3: Check Buffer Status
```c
// Check if buffer has space before sending large data
if (uart_putchar(data) == 0) {
    // Buffer full - wait or use blocking version
    uart_putchar_blocking(data, 100); // 100ms timeout
}
```

### Example 4: Ensure Data Sent Before Critical Operation
```c
uart_puts("Resetting system...\n");
uart_flush(); // Wait for message to be sent
// Now safe to reset
```

## Communication Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     NIOS II Processor                       │
│                                                             │
│  ┌──────────────────┐         ┌──────────────────┐        │
│  │   Application    │         │   Application    │        │
│  │   (User Code)    │         │   (User Code)    │        │
│  └────────┬─────────┘         └────────┬─────────┘        │
│           │                             │                   │
│           │ uart_puts()                 │ jtag_puts()      │
│           ▼                             ▼                   │
│  ┌──────────────────┐         ┌──────────────────┐        │
│  │  256-byte TX     │         │  JTAG UART       │        │
│  │  Circular Buffer │         │  Direct Write    │        │
│  └────────┬─────────┘         └────────┬─────────┘        │
│           │                             │                   │
│           │ ISR triggers                │ Direct           │
│           ▼                             ▼                   │
│  ┌──────────────────┐         ┌──────────────────┐        │
│  │   UART_0 (TX)    │         │  JTAG_UART_0     │        │
│  │   IRQ-driven     │         │  Non-blocking    │        │
│  └────────┬─────────┘         └────────┬─────────┘        │
└───────────┼──────────────────────────────┼─────────────────┘
            │                              │
            ▼                              ▼
   ┌────────────────┐           ┌────────────────┐
   │  RS232 UART    │           │  USB Blaster   │
   │  115200 8N1    │           │  JTAG          │
   └────────┬───────┘           └────────┬───────┘
            │                            │
            ▼                            ▼
   ┌────────────────┐           ┌────────────────┐
   │  Terminal      │           │ nios2-terminal │
   │  (PuTTY, etc)  │           │ System Console │
   └────────────────┘           └────────────────┘
```

## Testing Checklist

### Hardware Tests
- [ ] Verify UART TX/RX pins connected to RS232 transceiver
- [ ] Check RS232 transceiver power supply
- [ ] Verify TX/RX signal levels (3.3V ↔ RS232 voltage levels)
- [ ] Test with loopback (TX → RX) if possible

### Software Tests
- [ ] Verify startup banner appears on RS232 terminal
- [ ] Test command input (S, R, T commands)
- [ ] Verify echo works correctly
- [ ] Check debug messages on JTAG terminal
- [ ] Monitor error counters (should be zero)
- [ ] Test with high-speed data transmission

### Terminal Settings (RS232)
```
Baud Rate: 115200
Data Bits: 8
Parity:    None
Stop Bits: 1
Flow Ctrl: None
```

**Recommended terminals:**
- Windows: PuTTY, TeraTerm
- Linux: minicom, screen
- Cross-platform: CoolTerm

## Troubleshooting

### Problem: No output on RS232 terminal
**Solutions:**
1. Check pin assignments in `.qsf` file
2. Verify RS232 transceiver connections
3. Confirm terminal settings (115200 8N1)
4. Check TX pin toggling with oscilloscope
5. Verify UART_0_BASE address in `system.h`

### Problem: Garbage characters received
**Solutions:**
1. Verify baud rate matches (115200)
2. Check clock frequency (should be 120 MHz)
3. Ensure proper RS232 voltage levels
4. Check for electrical noise on TX/RX lines

### Problem: Characters missing or dropped
**Solutions:**
1. Check `uart_overrun_errors` counter
2. Increase RX processing speed
3. Verify interrupts are enabled
4. Check for ISR conflicts

### Problem: High error counts
**Check:**
- `uart_parity_errors`: Electrical noise or wrong parity setting
- `uart_frame_errors`: Baud rate mismatch or timing issues
- `uart_overrun_errors`: RX processing too slow

## Performance Characteristics

### Transmission Throughput
- **Theoretical max:** 115200 bps ≈ 14.4 KB/s
- **Practical with overhead:** ~11-12 KB/s
- **Buffered mode:** Allows bursts up to 256 bytes

### Latency
- **Character to buffer:** ~1-5 µs (immediate)
- **Buffer to wire:** Depends on queue depth
- **End-to-end:** Typically < 1ms for short messages

### CPU Efficiency
- **TX overhead:** Minimal (interrupt-driven)
- **RX overhead:** ~10-20 µs per character
- **ISR execution:** ~5-10 µs per interrupt

## Best Practices

1. **Always use UART for user interaction**, JTAG for debug
2. **Call `uart_flush()` before critical operations** (reset, sleep)
3. **Monitor error counters** in JTAG debug output
4. **Use blocking mode for critical messages** that must succeed
5. **Avoid printf()** for UART (use lightweight uart_puts/uart_put_int)
6. **Keep ISR fast** - don't do heavy processing in uart_isr()
7. **Test with long messages** to verify buffer doesn't overflow

## Advanced: Customizing Buffer Size

The TX buffer size can be easily customized to match your application's needs.

### How to Change Buffer Size

Edit the `TX_BUFFER_SIZE` definition in `hello_world.c` (line 79):

```c
#define TX_BUFFER_SIZE 512  // Current size

// Examples:
// #define TX_BUFFER_SIZE 256   // Smaller (256 bytes)
// #define TX_BUFFER_SIZE 1024  // Larger (1 KB)
// #define TX_BUFFER_SIZE 2048  // Even larger (2 KB)
```

### Choosing the Right Size

| Buffer Size | RAM Usage | Best For | Notes |
|-------------|-----------|----------|-------|
| 256 bytes   | 256 B     | Standard applications | Good default |
| 512 bytes   | 512 B     | Moderate text output | **Current setting** |
| 1024 bytes  | 1 KB      | High-frequency logging | Recommended for data streaming |
| 2048 bytes  | 2 KB      | Heavy burst transmission | Maximum practical size |

**Recommendation:** Use power-of-2 sizes (256, 512, 1024, 2048) for optimal compiler optimization of modulo operations.

### Memory Check

Your system has **102,400 bytes (100 KB)** of on-chip memory available. Current allocations:
- Code/data sections: ~varies
- TX buffer: 512 bytes
- Stack: ~1-2 KB
- Heap: remainder

You have plenty of room to increase the buffer size if needed.

### When to Increase Buffer Size

Consider increasing if you experience:
- Frequent `uart_putchar()` failures (returns 0)
- Choppy output during burst transmissions
- Need to queue large amounts of data quickly
- High-frequency logging requirements

### When to Decrease Buffer Size

Consider decreasing if you need:
- Maximum RAM for other data structures
- Minimal memory footprint
- Low output volume application

## References

- Altera Avalon UART Documentation
- Nios II Software Developer's Handbook
- Embedded Interrupt Programming Guide
