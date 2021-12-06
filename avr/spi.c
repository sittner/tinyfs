#include "spi.h"
#include "mmc.h"

#include <avr/io.h>

/* defines for customisation of sd/mmc port access */
#if defined(__AVR_ATmega8__) || \
    defined(__AVR_ATmega48__) || \
    defined(__AVR_ATmega48P__) || \
    defined(__AVR_ATmega88__) || \
    defined(__AVR_ATmega88P__) || \
    defined(__AVR_ATmega168__) || \
    defined(__AVR_ATmega168P__) || \
    defined(__AVR_ATmega328P__)
    #define configure_pin_mosi() DDRB |= (1 << DDB3)
    #define configure_pin_sck() DDRB |= (1 << DDB5)
    #define configure_pin_ss() DDRB |= (1 << DDB2)
    #define configure_pin_miso() DDRB &= ~(1 << DDB4)

    #define select_card() PORTB &= ~(1 << PORTB2)
    #define deselect_card() PORTB |= (1 << PORTB2)
#elif defined(__AVR_ATmega16__) || \
      defined(__AVR_ATmega32__)
    #define configure_pin_mosi() DDRB |= (1 << DDB5)
    #define configure_pin_sck() DDRB |= (1 << DDB7)
    #define configure_pin_ss() DDRB |= (1 << DDB4)
    #define configure_pin_miso() DDRB &= ~(1 << DDB6)

    #define select_card() PORTB &= ~(1 << PORTB4)
    #define deselect_card() PORTB |= (1 << PORTB4)
#elif defined(__AVR_ATmega64__) || \
      defined(__AVR_ATmega128__) || \
      defined(__AVR_ATmega169__)
    #define configure_pin_mosi() DDRB |= (1 << DDB2)
    #define configure_pin_sck() DDRB |= (1 << DDB1)
    #define configure_pin_ss() DDRB |= (1 << DDB0)
    #define configure_pin_miso() DDRB &= ~(1 << DDB3)

    #define select_card() PORTB &= ~(1 << PORTB0)
    #define deselect_card() PORTB |= (1 << PORTB0)
#else
    #error "no sd/mmc pin mapping available!"
#endif

void spi_init(void) {
  // enable outputs for MOSI, SCK, SS, input for MISO
  configure_pin_mosi();
  configure_pin_sck();
  configure_pin_ss();
  configure_pin_miso();

  deselect_card();

  SPCR = (0 << SPIE) | // SPI Interrupt Enable
         (1 << SPE)  | // SPI Enable
         (0 << DORD) | // Data Order: MSB first
         (1 << MSTR) | // Master mode
         (0 << CPOL) | // Clock Polarity: SCK low when idle
         (0 << CPHA) | // Clock Phase: sample on rising SCK edge
         (0 << SPR1) | // Clock Frequency: f_OSC / 4
         (0 << SPR0);

  SPSR &= ~(1 << SPI2X); // No doubled clock frequency
}

void spi_select_drive(void) {
  select_card();
}

void spi_deselect_drive(void) {
  deselect_card();
}

uint8_t spi_transfer_byte(uint8_t b) {
  SPDR = b;
  while (!(SPSR & (1 << SPIF)));
  SPSR &= ~(1 << SPIF);
  return SPDR;
}

void spi_read_block(uint8_t *data, uint16_t len) {
  for (; len > 0; len--, data++) {
    SPDR = 0xff;
    while (!(SPSR & (1 << SPIF)));
    SPSR &= ~(1 << SPIF);
    *data = SPDR;
  }
}

void spi_write_block(const uint8_t *data, uint16_t len) {
  for (; len > 0; len--, data++) {
    SPDR = *data;
    while (!(SPSR & (1 << SPIF)));
    SPSR &= ~(1 << SPIF);
  }
}

