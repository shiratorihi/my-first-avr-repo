#include <avr/io.h>

.section .text
.global _start
.org 0x0000

    jmp _start          ; 0x0000 RESET
    reti                ; 0x0002 INT0
    reti                ; 0x0004 INT1
    reti                ; 0x0006 PCINT0
    reti                ; 0x0008 PCINT1
    reti                ; 0x000A PCINT2
    reti                ; 0x000C WDT
    reti                ; 0x000E TIMER2_COMPA
    reti                ; 0x0010 TIMER2_COMPB
    reti                ; 0x0012 TIMER2_OVF
    reti                ; 0x0014 TIMER1_CAPT
    reti                ; 0x0016 TIMER1_COMPA
    reti                ; 0x0018 TIMER1_COMPB
    reti                ; 0x001A TIMER1_OVF
    reti                ; 0x001C TIMER0_COMPA
    reti                ; 0x001E TIMER0_COMPB
    reti                ; 0x0020 TIMER0_OVF
    reti                ; 0x0022 SPI_STC
    reti                ; 0x0024 USART_RX
    reti                ; 0x0026 USART_UDRE
    reti                ; 0x0028 USART_TX
    reti                ; 0x002A ADC
    reti                ; 0x002C EE_READY
    reti                ; 0x002E ANALOG_COMP
    reti                ; 0x0030 TWI
    reti                ; 0x0032 SPM_READY

_start:
    ; Stack Pointer init
    ldi r16, lo8(RAMEND)
    out _SFR_IO_ADDR(SPL), r16
    ldi r16, hi8(RAMEND)
    out _SFR_IO_ADDR(SPH), r16

    ; Set PB5 to output
    sbi _SFR_IO_ADDR(DDRB), PB5

main_loop:
    ; Flip PB5
    sbi _SFR_IO_ADDR(PINB), PB5
    rcall delay
    rjmp main_loop

; ?ms delay at 16MHz
delay:
    ldi r18, 0x04
outer:
    ldi r17, 0xFF
mid:
    ldi r16, 0xFF
inner:
    dec r16
    brne inner
    dec r17
    brne mid
    dec r18
    brne outer
    ret

