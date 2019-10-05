;
; AssignmentAssembly.asm
;
; Created: 20/09/2019 11:32:22
; Author : Daniel
;
.def zero_reg=r20
.def sreg_temp=r11
.def IS_HIGH=r18
.def GOT_DISTANCE=r19
.def temp=r21
.def pulse_time_low=r16
.def pulse_time_high=r17
.def distance=r12
.def div_result=r25

; Replace with your application code
.ORG 0x00
   rjmp start ; Reset interrupt
.ORG 0x04
   RJMP int1_int_start       ; Addr $04

start:
	;Initialize stack pointer
	LDI temp, high(RAMEND)
	OUT SPH, temp
	LDI temp, low(RAMEND)
	OUT SPL, temp
	
	;Initalize GPIO registers for use
	;TEMP to test ultrasonic 
	LDI temp, 0x01
	OUT DDRC, temp
	LDI temp, 0xFF
	OUT DDRB, temp
	CLR zero_reg
	;

	LDI temp, 0xF7
	OUT DDRD, temp
	LDI temp, 0x00
	OUT PORTB, temp
	OUT PORTC, temp
	RJMP setup_lcd

setup_lcd:
	RJMP setup_interrupts

setup_interrupts:
	;Enable INT1 interrupt
	LDI temp, 0x80
	OUT GICR, temp
	;Set INT1 to trigger on any logical change
	LDI temp, 0x04
	OUT MCUCR, temp
	;Enable global interrupts
	SEI
	RJMP main_loop

main_loop:
	RCALL query_sensors
	RJMP delay

delay:
    ldi  r18, 31
    ldi  r19, 113
    ldi  r20, 31
L1: dec  r20
    brne L1
    dec  r19
    brne L1
    dec  r18
    brne L1
    nop
	rjmp main_loop

query_sensors:
	;Start high pulse
	LDI temp, 0x01
	OUT PORTC, temp
	;10 us delay
	LDI  temp, 0x28
L2: DEC  temp
    BRNE L2
	;Continue by setting output to low
	LDI temp, 0x00
	OUT PORTC, temp
	LDI GOT_DISTANCE, 0x00
	;Save a clock cycle by reusing the fact that got_distance is 0x00
	;OUT PORTC, GOT_DISTANCE 
;Wait until ultrasonic sensor has finished its echo pulse
wait_until_done:
	CPI GOT_DISTANCE, 0x00
	BREQ wait_until_done
	;LDI pulse_time_low, 0x80
	;LDI pulse_time_high, 0x03

	;Make sure old records are gone
	;CLR pulse_time_low
	;CLR pulse_time_high
	;Record the distance into register
	IN temp, SREG
	CLI
	IN pulse_time_low, TCNT1L
	IN pulse_time_high, TCNT1H	

	OUT TCNT1H, zero_reg
	OUT TCNT1L, zero_reg
	OUT SREG, temp
	;Reset the clock
	;OUT PORTB, pulse_time_low

	CLR div_result
	CLR distance

	LDI temp, 0x01


check_div_done:
	;Check if less than 57
	CPI pulse_time_low, 0x57
	BRLO check_high
	;Not done yet
	RJMP calculate_distance

check_high:
	CPI pulse_time_high, 0x00
	;go to display
	BREQ display_distance

calculate_distance:
	SUBI pulse_time_low, 0x57
	SBCI pulse_time_high, 0x00
	CLC
	ADD distance, temp
	RJMP check_div_done

display_distance:
	OUT PORTB, distance
	RET

;Int1 routine
int1_int_start:
	IN sreg_temp,SREG
	PUSH temp
	CPI IS_HIGH,0x01
	BRNE INT1_NOT_HIGH

INT1_HIGH:
	;Turn off counter/timer
	OUT TCCR1B,zero_reg

	;Got the distance now
	LDI GOT_DISTANCE, 0x01
	;Pulse now low
	LDI IS_HIGH,0x00
	RJMP END_INT1

INT1_NOT_HIGH:
	IN temp, TCCR1B
	;Load timer with prescale factor of 8
	ORI temp,0x02 
	;Start timer
	OUT TCCR1B,temp
	;Echo pulse now high
	LDI IS_HIGH,0x01

END_INT1:
	POP temp
	OUT SREG,sreg_temp
	RETI