/*
 * FIR FPGA Control System with Dual Communication Channels
 *
 * This application provides a command-line interface for controlling
 * an FPGA-based FIR filter system using dual communication channels:
 *
 * ===== COMMUNICATION ARCHITECTURE =====
 * 1. RS232 UART (uart_0) - USER INTERFACE
 *    - Purpose: Interactive command console for user
 *    - Config: 115200 baud, 8N1, no flow control
 *    - Features:
 *      * Interrupt-driven RX (command input)
 *      * Buffered TX with interrupt-driven transmission (512 byte circular buffer)
 *      * Error detection (parity, frame, overrun)
 *      * Non-blocking buffered output
 *      * Automatic CRLF conversion (LF -> CRLF) for terminal compatibility
 *    - Functions: uart_putchar(), uart_puts(), uart_put_int(), uart_flush()
 *    - Pin connection: Connect to RS232 transceiver GPIO pins
 *
 * 2. JTAG UART (jtag_uart_0) - DEBUG CHANNEL
 *    - Purpose: System debug messages and diagnostics
 *    - Features: Non-blocking output via JTAG USB Blaster
 *    - Functions: jtag_putchar(), jtag_puts(), jtag_put_int()
 *    - Monitor via: nios2-terminal or Quartus System Console
 *
 * ===== SYSTEM FEATURES =====
 * - FIR filter coefficient management (64 registers)
 * - Periodic PIO toggle with configurable interval
 * - Real-time command processing
 * - UART error monitoring and reporting
 *
 * ===== COMMANDS (via RS232 UART) =====
 * S<addr>$<value> - Set FIR register at address (0-64) with signed 16-bit value
 * R<addr>         - Read FIR register at address (0-64)
 * T<interval>     - Set PIO timer interval in ms (100-5000)
 *
 */

#include <stdint.h>
#include <ctype.h>
#include "system.h"
#include "sys/alt_irq.h"
#include "altera_avalon_pio_regs.h"
#include "altera_avalon_jtag_uart_regs.h"
#include "altera_avalon_timer_regs.h"
#include "altera_avalon_uart_regs.h"

// initial preload array
// 500Hz Blackman LPF coefficients
// Original 60 VHDL entries with 2 zeros added at beginning and 2 at end
const int16_t fir_coefficients[64] = {
    0x0000, 0x0000,  
    0x0000, 0x0001, 0x0005, 0x000C,
    0x0016, 0x0025, 0x0037, 0x004E,
    0x0069, 0x008B, 0x00B2, 0x00E0,
    0x0114, 0x014E, 0x018E, 0x01D3,
    0x021D, 0x026A, 0x02BA, 0x030B,
    0x035B, 0x03AA, 0x03F5, 0x043B,
    0x047B, 0x04B2, 0x04E0, 0x0504,
    0x051C, 0x0528, 0x0528, 0x051C,
    0x0504, 0x04E0, 0x04B2, 0x047B,
    0x043B, 0x03F5, 0x03AA, 0x035B,
    0x030B, 0x02BA, 0x026A, 0x021D,
    0x01D3, 0x018E, 0x014E, 0x0114,
    0x00E0, 0x00B2, 0x008B, 0x0069,
    0x004E, 0x0037, 0x0025, 0x0016,
    0x000C, 0x0005, 0x0001, 0x0000,
    0x0000, 0x0000   
};

// Global variables for interrupt handling
volatile uint32_t timer_tick_count = 0;
volatile uint8_t uart_rx_flag = 0;
volatile char uart_rx_char = 0;

// TX circular buffer for interrupt-driven transmission
// Size can be increased for better burst handling (256, 512, 1024, 2048, etc.)
// Larger buffer = more RAM usage but better handling of output bursts
#define TX_BUFFER_SIZE 512
volatile char tx_buffer[TX_BUFFER_SIZE];
volatile uint16_t tx_head = 0;
volatile uint16_t tx_tail = 0;

// UART error counters for diagnostics
volatile uint32_t uart_parity_errors = 0;
volatile uint32_t uart_frame_errors = 0;
volatile uint32_t uart_overrun_errors = 0;

// Timer Interrupt Service Routine
static void timer_isr(void *context)
{
	// Clear the interrupt by reading the status register
	IOWR_ALTERA_AVALON_TIMER_STATUS(TIMER_0_BASE, 0);

	// Increment tick counter
	timer_tick_count++;
}

// RS232 UART Interrupt Service Routine (RX + TX + Error Handling)
static void uart_isr(void *context)
{
	uint32_t status;
	uint32_t control;

	// Read the status register
	status = IORD_ALTERA_AVALON_UART_STATUS(UART_0_BASE);

	// ===== ERROR HANDLING =====
	// Check for parity error
	if (status & ALTERA_AVALON_UART_STATUS_PE_MSK)
	{
		uart_parity_errors++;
		// Clear by reading RXDATA
		(void)IORD_ALTERA_AVALON_UART_RXDATA(UART_0_BASE);
	}

	// Check for frame error
	if (status & ALTERA_AVALON_UART_STATUS_FE_MSK)
	{
		uart_frame_errors++;
		// Clear by reading RXDATA
		(void)IORD_ALTERA_AVALON_UART_RXDATA(UART_0_BASE);
	}

	// Check for receiver overrun error (data lost)
	if (status & ALTERA_AVALON_UART_STATUS_ROE_MSK)
	{
		uart_overrun_errors++;
		// Clear by writing to status register
	}

	// ===== RECEIVE HANDLING =====
	// Check if receive data is ready (RRDY bit)
	if (status & ALTERA_AVALON_UART_STATUS_RRDY_MSK)
	{
		// Read the received character from RXDATA register
		uart_rx_char = (char)IORD_ALTERA_AVALON_UART_RXDATA(UART_0_BASE);
		uart_rx_flag = 1;
	}

	// ===== TRANSMIT HANDLING (Interrupt-driven) =====
	// Check if transmitter is ready and we have data to send
	if ((status & ALTERA_AVALON_UART_STATUS_TRDY_MSK) && (tx_tail != tx_head))
	{
		// Send next character from buffer
		IOWR_ALTERA_AVALON_UART_TXDATA(UART_0_BASE, tx_buffer[tx_tail]);
		tx_tail = (tx_tail + 1) % TX_BUFFER_SIZE;

		// If buffer is now empty, disable TX interrupt
		if (tx_tail == tx_head)
		{
			control = IORD_ALTERA_AVALON_UART_CONTROL(UART_0_BASE);
			control &= ~ALTERA_AVALON_UART_CONTROL_TRDY_MSK; // Disable TX interrupt
			IOWR_ALTERA_AVALON_UART_CONTROL(UART_0_BASE, control);
		}
	}

	// Clear interrupt status
	IOWR_ALTERA_AVALON_UART_STATUS(UART_0_BASE, 0);
}

// JTAG UART Interrupt Service Routine
static void jtag_uart_isr(void *context)
{
	uint32_t data;

	// Read the data register
	data = IORD_ALTERA_AVALON_JTAG_UART_DATA(JTAG_UART_0_BASE);

	// Check if read data is valid (bit 15)
	if (data & 0x8000)
	{
		uart_rx_char = (char)(data & 0xFF);
		uart_rx_flag = 1;
	}

	// Clear interrupt by reading control register and writing back
	uint32_t control = IORD_ALTERA_AVALON_JTAG_UART_CONTROL(JTAG_UART_0_BASE);
	IOWR_ALTERA_AVALON_JTAG_UART_CONTROL(JTAG_UART_0_BASE, control);
}

// ========== RS232 UART OUTPUT FUNCTIONS (User Interface) ==========
// Interrupt-driven buffered UART output - queues character for transmission
// Returns 1 if character was queued, 0 if buffer is full
int uart_putchar(char c)
{
	uint16_t next_head;
	uint32_t control;

	// Calculate next head position
	next_head = (tx_head + 1) % TX_BUFFER_SIZE;

	// Check if buffer is full
	if (next_head == tx_tail)
	{
		// Buffer full - could implement blocking wait here if needed
		return 0;
	}

	// Add character to buffer
	tx_buffer[tx_head] = c;
	tx_head = next_head;

	// Enable TX interrupt to start transmission
	control = IORD_ALTERA_AVALON_UART_CONTROL(UART_0_BASE);
	control |= ALTERA_AVALON_UART_CONTROL_TRDY_MSK; // Enable TX interrupt
	IOWR_ALTERA_AVALON_UART_CONTROL(UART_0_BASE, control);

	return 1; // Character queued successfully
}

// Blocking version with timeout - waits for buffer space
int uart_putchar_blocking(char c, uint32_t timeout_ms)
{
	uint32_t start_time = timer_tick_count;

	while (!uart_putchar(c))
	{
		// Check timeout
		if ((timer_tick_count - start_time) >= timeout_ms)
		{
			return 0; // Timeout
		}
	}

	return 1; // Success
}

// Wait for all buffered data to be transmitted
void uart_flush(void)
{
	// Wait until TX buffer is empty
	while (tx_head != tx_tail)
	{
		// Busy wait - could yield to other tasks here
	}
}

void uart_puts(const char *str)
{
	while (*str)
	{
		char c = *str++;
		// Auto-convert LF to CRLF for proper terminal display
		if (c == '\n')
		{
			uart_putchar('\r');
		}
		uart_putchar(c);
	}
}

// ========== JTAG UART OUTPUT FUNCTIONS (Debug Messages) ==========
// Direct JTAG UART output for debug messages (non-blocking)
void jtag_putchar(char c)
{
	uint32_t data;

	// Check if space available in write FIFO
	data = IORD_ALTERA_AVALON_JTAG_UART_CONTROL(JTAG_UART_0_BASE);
	if ((data & 0xFFFF) > 0) // WSPACE field indicates free space
	{
		IOWR_ALTERA_AVALON_JTAG_UART_DATA(JTAG_UART_0_BASE, c);
	}
	// If no space, character is silently dropped (non-blocking)
}

void jtag_puts(const char *str)
{
	while (*str)
	{
		jtag_putchar(*str++);
	}
}

void jtag_put_int(int num)
{
	char buffer[12];
	int i = 0;
	int is_negative = 0;

	if (num < 0)
	{
		is_negative = 1;
		num = -num;
	}

	if (num == 0)
	{
		jtag_putchar('0');
		return;
	}

	while (num > 0)
	{
		buffer[i++] = '0' + (num % 10);
		num /= 10;
	}

	if (is_negative)
	{
		jtag_putchar('-');
	}

	while (i > 0)
	{
		jtag_putchar(buffer[--i]);
	}
}

void uart_put_int(int num)
{
	char buffer[12];
	int i = 0;
	int is_negative = 0;

	if (num < 0)
	{
		is_negative = 1;
		num = -num;
	}

	// Handle zero case
	if (num == 0)
	{
		uart_putchar('0');
		return;
	}

	// Convert number to string (reversed)
	while (num > 0)
	{
		buffer[i++] = '0' + (num % 10);
		num /= 10;
	}

	// Print negative sign if needed
	if (is_negative)
	{
		uart_putchar('-');
	}

	// Print digits in correct order
	while (i > 0)
	{
		uart_putchar(buffer[--i]);
	}
}

// Custom function to parse integer from string
int parse_int(const char *str, int *result)
{
	int value = 0;
	int i = 0;
	int digit_found = 0;

	// Skip whitespace
	while (str[i] == ' ' || str[i] == '\t')
		i++;

	// Parse digits
	while (isdigit(str[i]))
	{
		value = value * 10 + (str[i] - '0');
		i++;
		digit_found = 1;
	}

	if (digit_found)
	{
		*result = value;
		return 1; // Success
	}
	return 0; // Failure
}

// Custom function to parse signed integer from string
int parse_signed_int(const char *str, int16_t *result)
{
	int32_t value = 0;
	int i = 0;
	int digit_found = 0;
	int is_negative = 0;

	// Skip whitespace
	while (str[i] == ' ' || str[i] == '\t')
		i++;

	// Check for sign
	if (str[i] == '-')
	{
		is_negative = 1;
		i++;
	}
	else if (str[i] == '+')
	{
		i++;
	}

	// Parse digits
	while (isdigit(str[i]))
	{
		value = value * 10 + (str[i] - '0');
		i++;
		digit_found = 1;
	}

	if (digit_found)
	{
		if (is_negative)
			value = -value;

		// Check if value fits in 16-bit signed range
		if (value >= -32768 && value <= 32767)
		{
			*result = (int16_t)value;
			return 1; // Success
		}
	}
	return 0; // Failure
}


// Process console input for commands using interrupt-driven input
// Commands:
//   S<addr>$<value> - Set register at address (0-64) with signed 16-bit value
//   R<addr>         - Read from register at address (0-64)
//   T<interval>     - Set PIO timer interval
void process_console_input(volatile uint32_t *delay_value)
{
	static char cmd_buffer[32];
	static int buffer_idx = 0;
	char c;
	int addr;
	int16_t value_signed;
	int value;
	uint32_t read_value;
	char *dollar_pos;
	int i;

	// Check if a character was received via interrupt
	if (uart_rx_flag)
	{
		c = uart_rx_char;
		uart_rx_flag = 0; // Clear the flag

		// Handle Enter key
		if (c == '\r' || c == '\n')
		{
			// Echo newline
			uart_puts("\n");

			cmd_buffer[buffer_idx] = '\0';

			// Parse command based on first character
			if (buffer_idx > 0)
			{
				// S<addr>$<value> - Set register command
				if (cmd_buffer[0] == 'S' || cmd_buffer[0] == 's')
				{
					// Find the dollar sign separator
					dollar_pos = NULL;
					for (i = 1; i < buffer_idx; i++)
					{
						if (cmd_buffer[i] == '$')
						{
							dollar_pos = &cmd_buffer[i];
							break;
						}
					}

					if (dollar_pos != NULL)
					{
						// Parse address (between 'S' and '$')
						*dollar_pos = '\0'; // Temporarily null-terminate
						if (parse_int(&cmd_buffer[1], &addr))
						{
							if (addr >= 0 && addr <= 64)
							{
								// Parse signed value (after '$')
								if (parse_signed_int(dollar_pos + 1, &value_signed))
								{
									// Write to MM bridge at calculated address
									IOWR_32DIRECT(MM_BRIDGE_0_BASE, addr * 4, (uint32_t)value_signed);
									uart_puts("Set reg[");
									uart_put_int(addr);
									uart_puts("] = ");
									uart_put_int((int)value_signed);
									uart_puts("\n");
								}
								else
								{
									uart_puts("Invalid value (must be signed 16-bit: -32768 to 32767).\n");
								}
							}
							else
							{
								uart_puts("Address out of range (0-64).\n");
							}
						}
						else
						{
							uart_puts("Invalid address.\n");
						}
					}
					else
					{
						uart_puts("Invalid format. Use S<addr>$<value>\n");
					}
				}
				// R<addr> - Read register command
				else if (cmd_buffer[0] == 'R' || cmd_buffer[0] == 'r')
				{
					if (parse_int(&cmd_buffer[1], &addr))
					{
						if (addr >= 0 && addr <= 64)
						{
							// Read from MM bridge at calculated address
							read_value = IORD_32DIRECT(MM_BRIDGE_0_BASE, addr * 4);
							uart_puts("Read reg[");
							uart_put_int(addr);
							uart_puts("] = ");
							// Cast to int16_t first to get proper sign extension, then to int for display
							uart_put_int((int)(int16_t)read_value);
							uart_puts("\n");
						}
						else
						{
							uart_puts("Address out of range (0-64).\n");
						}
					}
					else
					{
						uart_puts("Invalid address.\n");
					}
				}
				// T<interval> - Set PIO timer interval
				else if (cmd_buffer[0] == 'T' || cmd_buffer[0] == 't')
				{
					if (parse_int(&cmd_buffer[1], &value))
					{
						if (value <= 5000 && value >= 100)
						{
							*delay_value = value;
							uart_puts("Timer interval set to: ");
							uart_put_int(value);
							uart_puts(" ms\n");
						}
						else
						{
							uart_puts("Value out of range (100-5000).\n");
						}
					}
					else
					{
						uart_puts("Invalid integer value.\n");
					}
				}
				else
				{
					uart_puts("Unknown command. Use S<addr>$<value>, R<addr>, or T<interval>\n");
				}
			}

			// Reset buffer
			buffer_idx = 0;
		}
		// Add character to buffer
		else if (buffer_idx < sizeof(cmd_buffer) - 1)
		{
			// Echo the character back to the console
			uart_putchar(c);
			cmd_buffer[buffer_idx++] = c;
		}
	}
}

int main()
{
	uint8_t pio_state = 0;
	volatile uint32_t delay_value = 1000; // Default delay value in ms (1 second)
	uint32_t debug_counter = 0; // Counter for periodic debug messages

	// Register Timer interrupt handler
	alt_ic_isr_register(TIMER_0_IRQ_INTERRUPT_CONTROLLER_ID,
	                    TIMER_0_IRQ,
	                    timer_isr,
	                    NULL,
	                    0x0);

	// ===== JTAG UART INITIALIZATION (Debug Messages) =====
	// Register JTAG UART interrupt handler
	alt_ic_isr_register(JTAG_UART_0_IRQ_INTERRUPT_CONTROLLER_ID,
	                    JTAG_UART_0_IRQ,
	                    jtag_uart_isr,
	                    NULL,
	                    0x0);

	// Enable JTAG UART read interrupts
	uint32_t control = IORD_ALTERA_AVALON_JTAG_UART_CONTROL(JTAG_UART_0_BASE);
	control |= ALTERA_AVALON_JTAG_UART_CONTROL_RE_MSK; // Enable read interrupt
	IOWR_ALTERA_AVALON_JTAG_UART_CONTROL(JTAG_UART_0_BASE, control);

	// Send debug message to JTAG UART
	jtag_puts("\n=== DEBUG: System Starting ===\n");

	// Timer is configured to run continuously with period of 1ms
	// (configured in Qsys as TIMER_0_PERIOD = 1ms)

	// Configure the control register: 
	// - Enable interrupts (ITO bit)
	// - Enable continuous mode (CONT bit)
	// - Start the timer (START bit)
	IOWR_ALTERA_AVALON_TIMER_CONTROL(TIMER_0_BASE, 
		ALTERA_AVALON_TIMER_CONTROL_ITO_MSK |
		ALTERA_AVALON_TIMER_CONTROL_CONT_MSK |
		ALTERA_AVALON_TIMER_CONTROL_START_MSK);

	// ===== RS232 UART INITIALIZATION (User Interface) =====
	// Initialize TX buffer (head = tail = 0, buffer empty)
	tx_head = 0;
	tx_tail = 0;

	// Register UART interrupt handler
	alt_ic_isr_register(
		UART_0_IRQ_INTERRUPT_CONTROLLER_ID,
		UART_0_IRQ,
		uart_isr,
		NULL,
		0x0
	);

	// Clear any pending UART status
	IOWR_ALTERA_AVALON_UART_STATUS(UART_0_BASE, 0);

	// Enable RX interrupts only (TX interrupt enabled dynamically when needed)
	IOWR_ALTERA_AVALON_UART_CONTROL(UART_0_BASE, ALTERA_AVALON_UART_CONTROL_RRDY_MSK);

	// Send debug message to JTAG UART
	jtag_puts("DEBUG: UART initialized - 115200 8N1\n");
	
	// Preload FIR coefficients into MM bridge registers
	jtag_puts("DEBUG: Preloading FIR coefficients...\n");
	for (int i = 0; i < 64; i++)
	{
		IOWR_32DIRECT(MM_BRIDGE_0_BASE, i * 4, (uint32_t)fir_coefficients[i]);
	}
	jtag_puts("DEBUG: FIR coefficients loaded\n");

	// ===== USER INTERFACE via RS232 UART =====
	uart_puts("\n\n*** FIR FPGA Console ***\n");
	uart_puts("RS232 UART: 115200 baud, 8N1\n");
	uart_puts("Commands:\n");
	uart_puts("  S<addr>$<value> - Set register (addr: 0-64, value: signed 16-bit)\n");
	uart_puts("  R<addr>         - Read register (addr: 0-64)\n");
	uart_puts("  T<interval>     - Set timer interval in ms (100-5000)\n");
	uart_puts("\nCurrent timer interval: ");
	uart_put_int((int)delay_value);
	uart_puts(" ms\n");
	uart_puts("Ready> ");

	// Send debug info to JTAG UART
	jtag_puts("DEBUG: System ready, entering main loop\n");

	while (1)
	{
		// Check for console input (processed via UART interrupt)
		process_console_input(&delay_value);

		// Check if enough timer ticks have elapsed
		if (timer_tick_count  >= delay_value)
		{
			timer_tick_count = 0;

			// Toggle PIO output bit 0
			pio_state ^= 0x01;
			IOWR_ALTERA_AVALON_PIO_DATA(PIO_0_BASE, pio_state);

			// Send periodic debug info to JTAG UART (every 10 toggles)
			debug_counter++;
			if (debug_counter >= 10)
			{
				debug_counter = 0;

				// Debug info to JTAG UART only
				jtag_puts("DEBUG: PIO toggling, errors: PE=");
				jtag_put_int(uart_parity_errors);
				jtag_puts(" FE=");
				jtag_put_int(uart_frame_errors);
				jtag_puts(" OE=");
				jtag_put_int(uart_overrun_errors);
				jtag_puts("\n");
			}
		}
	}

	return 0;
}
