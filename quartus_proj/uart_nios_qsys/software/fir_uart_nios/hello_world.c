/*
 * PIO Toggle Timer Example
 *
 * This example toggles PIO output periodically over time.
 * It runs on the Nios II processor and requires a PIO device
 * in your system's hardware.
 *
 */

#include <stdint.h>
#include "system.h"
#include "altera_avalon_pio_regs.h"
//#include "altera_avalon_mm_bridge.h"

// Simple delay function
void delay(volatile uint32_t count)
{
	while (count--)
	{
		// Just burn cycles
		asm volatile ("nop");
	}
}

int main()
{
	uint8_t pio_state = 0;

	while (1)
	{
		// Toggle PIO output bit 0
		pio_state ^= 0x01;
		IOWR_ALTERA_AVALON_PIO_DATA(PIO_0_BASE, pio_state);

		static volatile uint32_t counter = 0;
		counter++;
		
		// Delay (adjust count for desired toggle rate)
		IOWR_32DIRECT(MM_BRIDGE_0_BASE, 0x0, (counter & 0xFFFF));
		delay(1000000);

	}

	return 0;
}
