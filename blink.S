#include <avr/io.h>

.section .text
.global _start
.org 0x0000

    jmp _start          ; 0x0000 RESET

.org 0x0068
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

