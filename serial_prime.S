; vim: set filetype=asm:

; Set RAMEND addr
.equ RAMEND, 0x08FF
; Set SFR I/O addr
.equ SPL, 0x3D
.equ SPH, 0x3E
.equ DDRD, 0x0A ; 1:0 -> TX, RX
; Set SFR Data addr
.equ UCSR0A, 0xC0 ; 7:0 -> RXC0, TXC0, UDRE0, FE0, DOR0, UPE0, U2X0, MPCM0
.equ UCSR0B, 0xC1 ; 7:0 -> RXCIE0, TXCIE0, UDRIE0, RXEN0, TXEN0, UCSZ02, RXB80, TXB80
.equ UCSR0C, 0xC2 ; 7:0 -> UMSEL01, UMSEL00, UPM01, UPM00, USBS0, UCSZ01, UCSZ00, UCPOL0
.equ UBRR0L, 0xC4
.equ UBRR0H, 0xC5
.equ UDR0, 0xC6

; Set baudrate to 38400 @ 8MHz clock, UART double speed mode disabled.
; (Testing accuracy for internal calibrated RC oscillator)
.equ BAUDSET, 12

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

  rcall uart_init
;-------------------------------------------------------------------------------

uart_init:
  ; Set baudrate
  ldi r16, hi8(BAUDSET)
  ldi r17, lo8(BAUDSET)
  sts UBRR0H, r16
  sts UBRR0L, r17
  ; Keep all other UART options default
  ; Set TX pin output
  sbi DDRD, 1 ; TX(PD1)
  ; Enable transmitter
  ldi r16, 1 << 3 ; TXEN0
  sts UCSR0B, r16
  ret
