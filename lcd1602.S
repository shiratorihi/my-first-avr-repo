; vim: set filetype=asm:

; lcd1602.S by ShiratoriYuuka314
; For use on ATmega328P microcontroller
; Using hardware USART interface as UART serial
; PD0 for RX pin
; PB7:0 as 8-pin parallel IO pins D7:0
; PD7:5 as RS, RW, E control pins
; Running on calibrated internal RC oscillator @ 8MHz
; Internal RC oscillator specifically recalibrated in this program
; This program is completely bare-metal and doesn't need to link standard start file

; Set RAMEND addr
.equ RAMEND, 0x08FF
; Set SFR I/O addr
.equ SPL, 0x3D
.equ SPH, 0x3E
.equ PINB, 0x03
.equ DDRB, 0x04
.equ PORTB, 0x05
.equ PIND, 0x09
.equ DDRD, 0x0A
.equ PORTD, 0x0B
.equ SREG, 0x3F
; Set SFR Data addr
.equ UCSR0A, 0xC0 ; 7:0 -> RXC0, TXC0, UDRE0, FE0, DOR0, UPE0, U2X0, MPCM0
.equ UCSR0B, 0xC1 ; 7:0 -> RXCIE0, TXCIE0, UDRIE0, RXEN0, TXEN0, UCSZ02, RXB80, TXB80
.equ UCSR0C, 0xC2 ; 7:0 -> UMSEL01, UMSEL00, UPM01, UPM00, USBS0, UCSZ01, UCSZ00, UCPOL0
.equ UBRR0L, 0xC4
.equ UBRR0H, 0xC5
.equ UDR0, 0xC6
.equ OSCCAL, 0x66

; Set baudrate to 1M @ 8MHz clock, UART double speed mode enabled
; Calibration for internal calibrated RC oscillator varies on different chips
.equ BAUDSET, 0
.equ CALIBRATION, 0xC0 ; Default value of my chip is 0xC5, calibrated to error margin < ±1%
; Set rx ring buffer size, must be power of 2, max 256
.equ RXBUFSIZE, 16
.equ RXBUFMASK, RXBUFSIZE - 1

; Set pin definition
.equ RS, 7
.equ RW, 6
.equ E, 5

; Set string
.macro TEXT0
  .string "Hello world!"
.endm

; SRAM allocation
.section .bss
rx_buf: .space RXBUFSIZE
rx_buf_head: .space 1
rx_buf_tail: .space 1

input_state: .space 1 ; State machine to handle escape and other data
cursor_state: .space 1 ; State machine to handle cursor setting

.section .text
.global _start
.org 0x0000

  rjmp _start ; RESET

.org 0x0048

  rjmp _usart_rx_isr ; USART_RX

.org 0x0068 ; Start of user code section
;-------------------------------------------------------------------------------
_start:
  ; Stack Pointer init
  ldi r16, lo8(RAMEND) ; 0xFF
  out SPL, r16
  ldi r16, hi8(RAMEND) ; 0x08
  out SPH, r16

  ldi r16, 0xE0 ; Set RS, RW, E to output
  out DDRD, r16

  rcall osc_cal
  rcall var_init
  rcall uart_init

  rcall delay_long ; Enough delay to ensure lcd module ready
  rcall lcd_init
  sei ; Enable interrupt

  ldi ZH, hi8(text0)
  ldi ZL, lo8(text0)
  rcall display_flash

main_loop:
  rcall lcd_print_rx
  rjmp main_loop
;-------------------------------------------------------------------------------

var_init:
  ; Init all variables to their initial value if needed
  ldi r16, 0
  sts input_state, r16 ; Initial state is normal state
  sts cursor_state, r16 ; Initial state is cursor on, blink on

  ret

lcd_init:
  ; Inits lcd module after startup delay
  ldi r16, 0xFF ; Set D7:0 to output
  out DDRB, r16

  ldi r16, 0x00 ; Set RS=0, RW=0, E=0
  out PORTD, r16

  ldi r24, 0x38 ; 8-bit mode, 2 lines, 5x8 font
  rcall lcd_write_cmd

  ldi r24, 0x0F ; Display on, cursor on, blink on
  rcall lcd_write_cmd

  ldi r24, 0x06 ; Cursor increment mode, display shift off
  rcall lcd_write_cmd

  ldi r24, 0x01 ; Clear screen
  rcall lcd_write_cmd
  ret

lcd_wait_busy:
  ; Polling busy flag until lcd not busy
  ldi r16, 0x00 ; Set D7:0 to input
  out DDRB, r16
  cbi PORTD, RS ; RS=0, RW=1 for busy flag read
  sbi PORTD, RW
lcd_wait_busy_loop:
  sbi PORTD, E
  nop
  nop
  nop
  nop ; Wait at least 450 ns, 4 nops are 500 ns @ 8MHz
  in r16, PINB
  cbi PORTD, E
  sbrc r16, 7 ; Check busy flag
  rjmp lcd_wait_busy_loop
  ldi r16, 0xFF ; Restore D7:0 to output
  out DDRB, r16
  ret

lcd_write_cmd:
  ; Load command to write to lcd module to r24 before calling
  rcall lcd_wait_busy
  cbi PORTD, RS ; RS=0, RW=0 for command write
  cbi PORTD, RW
  out PORTB, r24 ; Output data to wait until stable
  sbi PORTD, E
  nop
  nop
  nop
  nop ; Wait at least 450 ns, 4 nops are 500 ns @ 8MHz
  cbi PORTD, E ; Create a falling edge on E for lcd module to latch data
  ret

lcd_write_data:
  ; Load data to write to lcd module to r24 before calling
  rcall lcd_wait_busy
  sbi PORTD, RS ; RS=1, RW=0 for data write
  cbi PORTD, RW
  out PORTB, r24 ; Output data to wait until stable
  sbi PORTD, E
  nop
  nop
  nop
  nop ; Wait at least 450 ns, 4 nops are 500 ns @ 8MHz
  cbi PORTD, E ; Create a falling edge on E for lcd module to latch data
  ret

lcd_print_rx:
  ; Handle one byte of text from rx ring buffer to screen or process
  lds r16, rx_buf_head
  lds r17, rx_buf_tail
  cp r16, r17
  breq lcd_print_rx_end ; Skip if buffer empty
  ldi r16, 0
  ldi XH, hi8(rx_buf)
  ldi XL, lo8(rx_buf)
  add XL, r17
  adc XH, r16
  ld r24, X
  rcall lcd_putchar
  inc r17
  andi r17, RXBUFMASK ; Loopback when overflow
  sts rx_buf_tail, r17 ; Update new tail index value
lcd_print_rx_end:
  ret

osc_cal:
  ; Load new internal RC oscillator calibration value
  ldi r16, CALIBRATION
  sts OSCCAL, r16
  ret

display_flash:
  ; Load text space address of text to display to Z before calling
display_flash_loop:
  lpm r24, Z+
  tst r24
  breq display_flash_end
  rcall lcd_putchar
  rjmp display_flash_loop
display_flash_end:
  ret

uart_init:
  ; Set baudrate
  ldi r16, hi8(BAUDSET)
  ldi r17, lo8(BAUDSET)
  sts UBRR0H, r16
  sts UBRR0L, r17
  ; Enable double transmission speed
  lds r16, UCSR0A
  ori r16, 1 << 1 ; U2X0
  sts UCSR0A, r16
  ; Init rx buffer head and tail index to 0
  ldi r16, 0
  sts rx_buf_head, r16
  sts rx_buf_tail, r16
  ; Keep all other UART options default
  sbi DDRD, 1 ; TX (PD1)
  ; Enable receiver and transmitter
  ldi r16, (1 << 4 | 1 << 3) ; RXEN0, TXEN0
  sts UCSR0B, r16
  lds r16, UCSR0B
  sbr r16, 1 << 7 ; RXCIE0
  sts UCSR0B, r16
  ret

_usart_rx_isr:
  ; Get input from serial shell on PC
  push r22
  push r18
  push r17
  push r16
  in r16, SREG
  push r16
  lds r22, UDR0
  lds r16, rx_buf_head
  lds r17, rx_buf_tail
  mov r18, r16
receive_fillbyte:
  ; Load byte to fill into rx_buf to r22 before branching
  inc r16
  andi r16, RXBUFMASK ; Loopback when overflow
  cp r16, r17
  breq receive_fillbyte_full ; Discard if buffer full
  push YH
  push YL
  ldi YH, hi8(rx_buf)
  ldi YL, lo8(rx_buf)
  add YL, r18
  ldi r18, 0
  adc YH, r18
  st Y, r22 ; Load byte to ring buffer
  sts rx_buf_head, r16 ; Update new head index value
  pop YL
  pop YH
  pop r16
  out SREG, r16
  pop r16
  pop r17
  pop r18
  pop r22
  reti
receive_fillbyte_full:
  pop r16
  out SREG, r16
  pop r16
  pop r17
  pop r18
  pop r22
  reti

lcd_putchar:
  ; Load char to r24 before calling
  ; Maintains a simple state machine to filter special data
  lds r18, input_state
  tst r18
  breq lcd_putchar_0 ; Normal state
  cpi r18, 2
  brlo lcd_putchar_1 ; Got an escape
  brsh lcd_putchar_2 ; In sequence
lcd_putchar_0:
  cpi r24, 0x1B ; Escape
  brne lcd_putchar_print ; Normally print
  ldi r18, 1
  sts input_state, r18 ; Enter got-an-escape state
  ret
lcd_putchar_1:
  cpi r24, '['
  breq got_sequence
  cpi r24, 'O'
  breq got_sequence
  ldi r18, 0
  sts input_state, r18 ; 2-byte escape, go back to normal state
  ret
got_sequence:
  ldi r18, 2
  sts input_state, r18 ; Enter in-sequence state
  ret
lcd_putchar_2:
  cpi r24, 0x40
  brsh sh_than_0x40
  ret
sh_than_0x40:
  cpi r24, 0x7F
  brlo end_sequence
  ret
end_sequence:
  ldi r18, 0
  sts input_state, r18 ; Go back to normal state
  cpi r24, 'A'
  breq got_up
  cpi r24, 'B'
  breq got_down
  cpi r24, 'C'
  breq got_right
  cpi r24, 'D'
  breq got_left
  ret
got_up:
  rcall lcd_up_key
  ret
got_down:
  rcall lcd_down_key
  ret
got_left:
  rcall lcd_left_key
  ret
got_right:
  rcall lcd_right_key
  ret
lcd_putchar_print:
  cpi r24, '\r'
  breq got_cr
  cpi r24, '\n'
  breq got_lf
  cpi r24, 0x7F
  breq got_backspace
  cpi r24, 0x08
  breq got_backspace
  cpi r24, 0x09
  breq got_tab
  rcall lcd_write_data
  ret
got_cr:
  rcall lcd_crlf
  ret
got_lf:
  rcall lcd_crlf
  ret
got_backspace:
  rcall lcd_backspace
  ret
got_tab:
  rcall lcd_tab
  ret

lcd_up_key:
  ret

lcd_down_key:
  ret

lcd_left_key:
  ldi r24, 0x10 ; Move cursor left
  rcall lcd_write_cmd
  ret

lcd_right_key:
  ldi r24, 0x14 ; Move cursor right
  rcall lcd_write_cmd
  ret

lcd_crlf:
  ret

lcd_backspace:
  ldi r24, 0x10 ; Move cursor left
  rcall lcd_write_cmd
  ldi r24, ' ' ; Use blank to override
  rcall lcd_write_data
  ldi r24, 0x10 ; Move cursor left
  rcall lcd_write_cmd
  ret

lcd_tab:
  rcall lcd_change_cursor
  ret

lcd_change_cursor:
  lds r18, cursor_state
  tst r18
  breq lcd_cursor_0 ; Cursor on, blink on state
  cpi r18, 2
  brlo lcd_cursor_1 ; Cursor on, blink off state
  brsh lcd_cursor_2 ; Cursor off state
lcd_cursor_0:
  ldi r24, 0x0E
  rcall lcd_write_cmd
  ldi r18, 1
  sts cursor_state, r18
  ret
lcd_cursor_1:
  ldi r24, 0x0C
  rcall lcd_write_cmd
  ldi r18, 2
  sts cursor_state, r18
  ret
lcd_cursor_2:
  ldi r24, 0x0F
  rcall lcd_write_cmd
  ldi r18, 0
  sts cursor_state, r18
  ret

delay_long:
  ; Simple delay subroutine of ~195,844 cycles or 24.48 ms @ 8MHz
  ldi r16, 255
delay_long_outer:
  ldi r17, 255
delay_long_inner:
  dec r17
  brne delay_long_inner
  dec r16
  brne delay_long_outer
  ret

guard_loop:
  ; Prevent program from running into data area
  rjmp guard_loop

; Flash data area
text0:
  TEXT0
