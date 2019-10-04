;
; AssignmentAssembly.asm
;
; Created: 20/09/2019 11:32:22
; Author : Daniel
;
.def IS_HIGH=r16
.def GOT_DISTANCE=r17
.def temp=r18
.def count_low=r19
.def count_high=r20

; Replace with your application code
reset:
   rjmp start ; Reset interrupt
   reti      ; Addr $01
   reti      ; Addr $02
   reti      ; Addr $03
   reti      ; Addr $04
   reti      ; Addr $05
   reti      ; Addr $06        Use 'rjmp myVector'
   reti      ; Addr $07        to define a interrupt vector
   reti      ; Addr $08
   reti      ; Addr $09
   reti      ; Addr $0A
   reti      ; Addr $0B        This is just an example
   reti      ; Addr $0C        Not all MCUs have the same
   reti      ; Addr $0D        number of interrupt vectors
   reti      ; Addr $0E
   reti      ; Addr $0F
   reti      ; Addr $10

;Int1 routine
int1_int_start:
	CPI IS_HIGH, 0x01
	BREQ int1_stop_timer
	RJMP int1_start_timer

int1_stop_timer:
	;Stop Timer
	LDI temp, 0x00
	OUT TCCR1B, temp
	;Mark the the next change to expect is a high pulse
	LDI IS_HIGH, 0x00
	;Mark that the distance can now be calculated
	LDI GOT_DISTANCE, 0x01
	RJMP int1_int_end

int1_start_timer:
	;Start timer with an 8 prescale factor (8 clocks = 1 count)	
	LDI temp, (1 << CS11)
	;Mark that the next change should be a high to low change
	LDI IS_HIGH, 0x01
	RJMP int1_int_end

int1_int_end:
	RETI

start:
	;Initalize GPIO registers for use
    LDI temp, 0x01
	OUT DDRB, temp
	OUT DDRC, temp
	LDI temp, 0xF7
	OUT DDRD, temp
	LDI temp, 0x00
	OUT PORTB, temp
	OUT PORTC, temp
	
	;Initialize stack pointer
	LDI temp, high(RAMEND)
	OUT SPH, temp
	LDI temp, low(RAMEND)
	OUT SPL, temp
	RJMP setup_lcd

setup_lcd:
	RJMP setup_interrupts

setup_interrupts:
	;Enable INT1 interrupt
	LDI temp, (1 << INT1)
	OUT GICR, temp
	;Set INT1 to trigger on any logical change
	LDI temp, (1 << ISC10)
	OUT MCUCR, temp
	;Enable global interrupts
	SEI
	RJMP main_loop

main_loop:
	RJMP query_sensors

query_sensors:
	;Start high pulse
	LDI temp, 0x01
	OUT PORTB, temp
	;10 us delay
	ldi  temp, 40
L1: dec  temp
    brne L1
	;Continue by setting output to low
	LDI GOT_DISTANCE, 0x00
	;Save a clock cycle by reusing the fact that got_distance is 0x00
	OUT PORTB, GOT_DISTANCE 
;Wait until ultrasonic sensor has finished its echo pulse
wait_until_done:
	CPI GOT_DISTANCE, 0
	BREQ wait_until_done

	
	
	
