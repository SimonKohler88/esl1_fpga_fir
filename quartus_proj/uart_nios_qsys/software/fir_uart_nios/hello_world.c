/*
 * PIO Toggle Timer Example
 *
 * This example toggles PIO output periodically over time.
 * It runs on the Nios II processor and requires a PIO device
 * in your system's hardware.
 *
 */

#include <stdint.h>
#include <ctype.h>
#include "system.h"
#include "sys/alt_irq.h"
#include "altera_avalon_pio_regs.h"
#include "altera_avalon_jtag_uart_regs.h"
#include "altera_avalon_timer_regs.h"

// Global variables for interrupt handling
volatile uint32_t timer_tick_count = 0;
volatile uint8_t uart_rx_flag = 0;
volatile char uart_rx_char = 0;

// Timer Interrupt Service Routine
static void timer_isr(void *context)
{
	// Clear the interrupt by reading the status register
	IOWR_ALTERA_AVALON_TIMER_STATUS(TIMER_0_BASE, 0);

	// Increment tick counter
	timer_tick_count++;

	IOWR_ALTERA_AVALON_PIO_DATA(PIO_0_BASE, (uint8_t)timer_tick_count);
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

// Lightweight UART output functions (no printf overhead)
void uart_putchar(char c)
{
	// Wait until there's space in the JTAG UART FIFO
	while ((IORD_ALTERA_AVALON_JTAG_UART_CONTROL(JTAG_UART_0_BASE) & 0xFFFF0000) == 0);
	IOWR_ALTERA_AVALON_JTAG_UART_DATA(JTAG_UART_0_BASE, c);
}

void uart_puts(const char *str)
{
	while (*str)
	{
		uart_putchar(*str++);
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

// Non-blocking delay function - returns 1 when delay period has elapsed
// Only increments counter when increment parameter is 1
int delay_non_blocking(volatile uint32_t *tick_counter, volatile uint32_t delay_ticks, int increment)
{
	if (increment)
	{
		(*tick_counter)++;
	}

	if (*tick_counter >= delay_ticks)
	{
		*tick_counter = 0;
		return 1; // Delay period elapsed
	}
	return 0; // Still waiting
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

// Non-blocking function to check if character is available from JTAG UART
int alt_getchar_nonblocking(char *c)
{
	// Read JTAG UART data register directly
	uint32_t data = IORD_ALTERA_AVALON_JTAG_UART_DATA(JTAG_UART_0_BASE);

	// Check RVALID bit (bit 15) to see if data is valid
	if (data & 0x8000)
	{
		// Extract the character (lower 8 bits)
		*c = (char)(data & 0xFF);
		return 1;
	}
	return 0;
}

// Process console input for 'S<integer>' command using interrupt-driven input
void process_console_input(volatile uint32_t *delay_value)
{
	static char cmd_buffer[16];
	static int buffer_idx = 0;
	char c;
	int value;

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

			// Parse command
			if (buffer_idx > 0 && (cmd_buffer[0] == 'S' || cmd_buffer[0] == 's'))
			{
				// Use custom function to extract integer value after 'S'
				if (parse_int(&cmd_buffer[1], &value))
				{
					if (value <= 5000 && value >= 100)
					{
						*delay_value = value;
						uart_puts("Delay value set to: ");
						uart_put_int(value);
						uart_puts("\n");
					}
					else
					{
						uart_puts("Value out of range (100 - 5000).\n");
					}
				}
				else
				{
					uart_puts("Invalid integer value.\n");
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
	volatile uint32_t last_tick = 0;
	volatile uint32_t counter = 0;

	// Register Timer interrupt handler
	alt_ic_isr_register(TIMER_0_IRQ_INTERRUPT_CONTROLLER_ID,
	                    TIMER_0_IRQ,
	                    timer_isr,
	                    NULL,
	                    0x0);

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

	// Timer is configured to run continuously with period of 1ms
	// (configured in Qsys as TIMER_0_PERIOD = 1ms)

	// Configure and start the timer
	// Set the period (this may already be set by Qsys, but it's good practice)
	// IOWR_ALTERA_AVALON_TIMER_PERIODL(TIMER_0_BASE, (TIMER_0_FREQ / 1000) & 0xFFFF);
	// IOWR_ALTERA_AVALON_TIMER_PERIODH(TIMER_0_BASE, ((TIMER_0_FREQ / 1000) >> 16) & 0xFFFF);

	// Configure the control register: 
	// - Enable interrupts (ITO bit)
	// - Enable continuous mode (CONT bit)
	// - Start the timer (START bit)
	IOWR_ALTERA_AVALON_TIMER_CONTROL(TIMER_0_BASE, 
		ALTERA_AVALON_TIMER_CONTROL_ITO_MSK |
		ALTERA_AVALON_TIMER_CONTROL_CONT_MSK |
		ALTERA_AVALON_TIMER_CONTROL_START_MSK);

	uart_puts("\n*** PIO Toggle Timer with Console Control (Interrupt-driven) ***\n");
	uart_puts("Commands:\n");
	uart_puts("  S<integer> - Set delay value in ms\n");
	uart_puts("Current delay: ");
	uart_put_int((int)delay_value);
	uart_puts(" ms\n\n");

	while (1)
	{
		// Check for console input (processed via UART interrupt)
		process_console_input(&delay_value);

		// Check if enough timer ticks have elapsed
		if ((timer_tick_count - last_tick) >= delay_value)
		{
			last_tick = timer_tick_count;

			// Toggle PIO output bit 0
			//pio_state ^= 0x01;
			//IOWR_ALTERA_AVALON_PIO_DATA(PIO_0_BASE, pio_state);

			counter++;

			// Write counter to MM bridge
			IOWR_32DIRECT(MM_BRIDGE_0_BASE, 0x0, (counter & 0xFFFF));
		}
	}

	return 0;
}
