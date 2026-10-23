; vim: set filetype=asm:

; Set RAMEND addr
.equ RAMEND, 0x08FF
; Set SFR I/O addr
.equ SPL, 0x3D
.equ SPH, 0x3E
; Set SFR Data addr
.equ UCSR0A, 0xC0 ; 7:0 -> RXC0, TXC0, UDRE0, FE0, DOR0, UPE0, U2X0, MPCM0
.equ UCSR0B, 0xC1 ; 7:0 -> RXCIE0, TXCIE0, UDRIE0, RXEN0, TXEN0, UCSZ02, RXB80, TXB80
.equ UCSR0C, 0xC2 ; 7:0 -> UMSEL01, UMSEL00, UPM01, UPM00, USBS0, UCSZ01, UCSZ00, UCPOL0
.equ UBRR0L, 0xC4
.equ UBRR0H, 0xC5
.equ UDR0, 0xC6

; Set baud rate to 38400 @ 8MHz clock, UART double speed mode disabled.
; (Testing accuracy for internal calibrated RC oscillator)
.macro BAUDSET
  .byte 0, 12
.endm

.section .text
.global _start
.org 0x0000

  jmp _start ; 0x0000 RESET

.org 0x0068 ; Start of user code section
;-------------------------------------------------------------------------------
_start:
  ; Stack Pointer init
  ldi r16, lo8(RAMEND) ; 0xFF
  out SPL, r16
  ldi r16, hi8(RAMEND) ; 0x08
  out SPH, r16
;-------------------------------------------------------------------------------

