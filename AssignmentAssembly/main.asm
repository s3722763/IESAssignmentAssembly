;
; AssignmentAssembly.asm
;
; Created: 20/09/2019 11:32:22
; Author : Daniel
;
; Address is 0x27 but shifted 1 Left, with the lower bit being 0 to signify sending
.equ SLA_W=0x4E

.def zero_reg=r20
.def sreg_temp=r11
.def IS_HIGH=r18
.def GOT_DISTANCE=r19
.def temp=r21
.def pulse_time_low=r16
.def pulse_time_high=r17
.def distance=r27
.def div_result=r25
.def twiDataToSend=r26
.def tooSend=r22
.def is_char=r23
.def options=r24
.def result_o=r28
.def result_t=r29
.def result_h=r30

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
	CALL setSendRate
	CALL initLCD
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
	RCALL generateSeperateNums
	RCALL updateLCD
	RCALL wait_100_ms
	;OUT PORTB, distance

	rjmp main_loop

query_sensors:
	;Start high pulse
	LDI temp, 0x01
	OUT PORTB, temp
	;10 us delay
	LDI  temp, 0x28
L7: DEC  temp
    BRNE L7
	;Continue by setting output to low
	LDI temp, 0x00
	OUT PORTB, temp
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
	INC distance
	RJMP check_div_done

display_distance:
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

setSendRate:
	CLR temp
	OUT TWSR, temp
	LDI temp, 0x70
	OUT TWBR, temp
	LDI temp, (1 << TWEN)
	OUT TWCR, temp
	LDI temp, 0xFF
	OUT TWDR, temp
	RET

sendTWI:
	RJMP twiStart

initLCD:
	;Might need to add delay
	CLR is_char
	LDI tooSend, 0x00
	RCALL lcdSend
	RCALL wait_5_ms
	LDI twiDataToSend, 0x03
	RCALL sendNibble
	RCALL wait_5_ms
	;Send the 0x03 again
	LDI twiDataToSend, 0x03
	RCALL sendNibble
	RCALL wait_200_us
	;Bit mode set (4 bit mode)
	LDI twiDataToSend, 0x02
	RCALL sendNibble
	RCALL wait_200_us
	;Function send (1 Line, 8x5 characters)
	LDI tooSend, 0x20
	RCALL lcdSend
	RCALL wait_200_us
	RCALL lcdDisplayReset
	RET

twiStart:
	;LDI temp, 0x01
	;OUT PORTB, temp
	LDI temp, (1 << TWINT) | (1 << TWSTA) | (1 << TWEN)
	OUT TWCR, temp
twiStartWait:
	;LDI temp, 0x02
	;lUT PORTB, temp
	IN temp, TWCR
	;Wait until START sent
	SBRS temp, TWINT
	RJMP twiStartWait

twiAddressSend:
	;LDI temp, 0x03
	;OUT PORTB, temp
	LDI temp, SLA_W
	OUT TWDR, temp
	LDI temp, (1 << TWINT) | (1 << TWEN)
	OUT TWCR, temp
twiAddressSendWait:
	IN temp, TWCR
	SBRS temp, TWINT
	RJMP twiAddressSendWait

twiDataSend:
	;LDI temp, 0x05
	;OUT PORTB, temp
	;Data is in the twiDataToSend
	OUT TWDR, twiDataToSend
	LDI temp, (1 << TWINT) | (1 << TWEN)
	OUT TWCR, temp
twiDataSendWait:
	;LDI temp, 0x06
	;OUT PORTB, temp
	IN temp, TWCR
	SBRS temp, TWINT
	RJMP twiDataSendWait

twiSendStop:
	IN temp, TWSR
	;OUT PORTB, temp
	LDI temp, (1 << TWINT) | (1 << TWEN) | (1 << TWSTO)
	OUT TWCR, temp
	RET


lcdDisplayReset:
	;Display on
	LDI tooSend, 0x0C
	CALL lcdSend
	CALL wait_50_us
	;Clear display
	LDI tooSend, 0x01
	CALL lcdSend
	CALL wait_1_5_ms
	;Turn on Entry mode
	LDI tooSend, 0x06
	CALL lcdSend
	CALL wait_50_us
	RET

lcdSend:
	MOV twiDataToSend, tooSend
	;Upper 4 bits
	ANDI twiDataToSend, 0xF0
	CALL sendNibble
	MOV twiDataToSend, tooSend
	;Shift it left 4 times
	LSL twiDataToSend
	LSL twiDataToSend
	LSL twiDataToSend
	LSL twiDataToSend
	ANDI twiDataToSend, 0xF0
	CALL sendNibble
	RET

sendNibble:
	LDI options, 0x04
	CPI is_char, 0x00
	BREQ sendNibble2
	;Set RS
	ORI options, 0x01

sendNibble2:
	;Set backlight
	ORI options, 0x08
	OR twiDataToSend, options
	CALL sendTWI

	;Turn off the Enable flag
	;11111011
	ANDI twiDataToSend, 0xFB
	CALL sendTWI
	RET

updateLCD:
	LDI is_char, 0x00
	CALL lcdDisplayReset
	ORI result_h, 0x30
	ORI result_t, 0x30
	ORI result_o, 0x30
	LDI is_char, 0x01
	MOV tooSend, result_h
	CALL lcdSend
	CALL wait_5_us
	MOV tooSend, result_t
	CALL lcdSend
	CALL wait_5_us
	MOV tooSend, result_o
	CALL lcdSend
	CALL wait_5_us
	RET

generateSeperateNums:
	CLR result_h
	CLR result_t
	CLR result_o
	RJMP hundred_div

hundred_div:
	;Check if less than 100
	CPI distance, 0x64
	;Less than 100
	BRLO tens_div
	RJMP hundred_calc

hundred_calc:
	SUBI distance, 0x64
	CLC
	INC result_h
	RJMP hundred_div

tens_div:
	;Check if less than 100
	CPI distance, 0x0A
	;Less than 100
	BRLO div_fin
	RJMP tens_calc

tens_calc:
	SUBI distance, 0x0A
	CLC
	INC result_t
	RJMP tens_div

div_fin:
	MOV result_o, distance
	RET

wait_5_ms:
	PUSH r18
	PUSH r19
    ldi  r18, 78
    ldi  r19, 235
L1: dec  r19
    brne L1
    dec  r18
    BRNE L1 
	POP r18
	POP r19
	RET

wait_200_us:
	PUSH r18
	PUSH r19
    ldi  r18, 4
    ldi  r19, 29
L2: dec  r19
    brne L2
    dec  r18
    brne L2
    NOP
	POP r18
	POP r19
	RET

wait_1_5_ms:
	PUSH r18
	PUSH r19
    ldi  r18, 24
    ldi  r19, 95
L3: dec  r19
    brne L3
    dec  r18
    brne L3
	POP r18
	POP r19
	RET

wait_50_us:
	PUSH r18
    ldi  r18, 200
L4: dec  r18
    brne L4
    NOP
	POP r18
	RET

wait_1_us:
	PUSH r18
    ldi  r18, 4
L5: dec  r18
    brne L5
	POP r18
	RET

wait_5_us:
	PUSH r18
	ldi  r18, 20
L8: dec  r18
    brne L8
	POP r18
	RET

wait_100_ms:
	PUSH r18
	PUSH r19
	PUSH r20
	ldi  r18, 13
    ldi  r19, 45
    ldi  r20, 216
L9: dec  r20
    brne L9
    dec  r19
    brne L9
    dec  r18
    brne L9
    NOP
	POP r18
	POP r19
	POP r20
	RET