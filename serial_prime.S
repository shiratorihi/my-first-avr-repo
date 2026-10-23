; vim: set filetype=asm:

; Set RAMEND addr
.equ RAMEND, 0x08FF
; Set SFR I/O addr
.equ SPL, 0x3D
.equ SPH, 0x3E
.equ SREG, 0x3F
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
; Set tx buffer size, must be power of 2, max 256
.equ TXBUFSIZE, 32
.equ TXBUFMASK, TXBUFSIZE - 1

; Set string and its size
.equ HELLOWORLDSIZE, 13
.macro HELLOWORLD
  .string "Hello world!"
.endm

.section .bss
tx_buf: .space TXBUFSIZE
tx_buf_head: .space 1
tx_buf_tail: .space 1
hello_world: .space HELLOWORLDSIZE

.section .text
.global _start
.org 0x0000

  rjmp _start ; RESET

.org 0x004C

  rjmp _usart_udre_isr ; USART_UDRE

.org 0x0068 ; Start of user code section
;-------------------------------------------------------------------------------
_start:
  ; Stack Pointer init
  ldi r16, lo8(RAMEND) ; 0xFF
  out SPL, r16
  ldi r16, hi8(RAMEND) ; 0x08
  out SPH, r16

  rcall hello_world_init

  rcall uart_init
end_loop:
  rjmp end_loop
;-------------------------------------------------------------------------------

hello_world_init:
  ; Load string from flash to sram
  ldi ZH, hi8(hello_world_flash)
  ldi ZL, lo8(hello_world_flash)
  ldi XH, hi8(hello_world)
  ldi XL, lo8(hello_world)
  ldi r17, HELLOWORLDSIZE
hello_world_init_loop:
  lpm r16, Z+
  st X+, r16
  dec r17
  brne hello_world_init_loop
  ret

uart_init:
  ; Set baudrate
  ldi r16, hi8(BAUDSET)
  ldi r17, lo8(BAUDSET)
  sts UBRR0H, r16
  sts UBRR0L, r17
  ; Keep all other UART options default
  ; Set tx buffer length to 0
  ldi r16, 0
  sts tx_buf_head, r16
  sts tx_buf_tail, r16
  ; Set TX pin output
  sbi DDRD, 1 ; TX(PD1)
  ; Enable transmitter
  ldi r16, 1 << 3 ; TXEN0
  sts UCSR0B, r16
  ret

_usart_udre_isr:
  push r16
  push r17
  push XH
  push XL
  in r16, SREG
  push r16
  lds r16, tx_buf_head
  lds r17, tx_buf_tail
  cp r16, r17
  brne keep_transmit
  ; Clear UDRIE0 if tx_buf is empty
  lds r16, UCSR0B
  cbr r16, 1 << 5 ; UDRIE0
  sts UCSR0B, r16
  rjmp usart_udre_end
keep_transmit:
  ldi r16, 0
  ldi XH, hi8(tx_buf)
  ldi XL, lo8(tx_buf)
  add XL, r17
  adc XH, r16
  ld r16, X
  sts UDR0, r16
  inc r17
  andi r17, TXBUFMASK
  sts tx_buf_tail, r17
usart_udre_end:
  pop r16
  out SREG, r16
  pop XL
  pop XH
  pop r17
  pop r16
  reti

hello_world_flash:
  HELLOWORLD
