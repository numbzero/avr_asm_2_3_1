.include "m32def.inc"

; Utilizînd Timer/Counter0, generati impulsuri la iesirea OC0
; cu perioada 50 µS si durata 25% cît la întrarea INT1 = "0",
; si durata impulsurilor 75% - cît INT1 = "1"
; -----------------------------------------------------------
; OC0 		- PWM
; INT1 (0)	- 25%
; INT1 (1) 	- 75%
; F_CPU 	- 16MHz
; F_PWM		- 20KHz
;-------------------
; Machine Cycles (MC) = F_CPU / F_PWM
; MC = 800
; Timer/Counter0 - MAX = 255
; Prescaler - 8
; Timer Cycles*	= MC / Prescaler = 100
; OCR0,T_ON  	= 24 (25%)
; OCR0,T_OFF 	= 74 (25%)
; OCR0,T_ON  	= 74 (75%)
; OCR0,T_OFF 	= 24 (75%)

.def T_ON 	= R20
.def T_OFF 	= R21
.def STATE	= R22

.cseg			; code segment
.org 0x0000	
	rjmp RESET

.org INT1addr		; External Interrupt Request 1
	rjmp EXT_INT_1

.org OC0addr		; Timer/Counter0 Compare Match
	rjmp TC0_CTC




EXT_INT_1:
	in R17, SREG	; store state of SREG
	sbis PIND, 3	; skip next instruction if PD3 is 1 --
	rjmp CHANGE_I	; if PD3 is 0 jump to --------        |
	ldi T_ON, 0x4a	; <---------------------------|------/
	ldi T_OFF, 0x18	;                             |   
	rjmp END	; -----\                      |
CHANGE_I:		; <--------------------------/
	ldi T_ON, 0x18	;       |
	ldi T_OFF, 0x4a	;       |
END:			; <----/
	out SREG, R17 	; restore state of SREG
	reti		; return from interrupt




TC0_CTC:
	in R17, SREG	; store state of SREG
	
	cpi STATE, 0x01 ; compare state with 1
	breq CHANGE_T 	; branch if equal to 1 ----
	out OCR0, T_OFF	;			   |
	rjmp END_T	;---			   |
CHANGE_T: 		;   |  	   <--------------/
	out OCR0, T_ON	;   |
END_T:			;<-/
	com STATE		

	out SREG, R17	; restore state of sreg
	reti		; return from interrupt




RESET:
	; stack setup, we need it for interrupts
	ldi R16, LOW(RAMEND)
	out SPL, R16
	ldi R16, HIGH(RAMEND)
	out SPH, R16

	; pins setup
	clr R16
	out DDRD, R16
	sbi DDRB, 3		; set PB3 to output

	cli 			; disable interrupts

	; external interrupt 1 setup
	ldi R16, (1 << INT1)
	out GICR, R16
	; any logical change on INT1 generates an interrupt request
	ldi R16, (0 << ISC11) | (1 << ISC10) 
	out MCUCR, R16

	; timer/counter 0 setup
	; ctc mode
	; prescaler - 8
	; OC0 - toggle on compare match
	;------------------------------------
	;
	;        |-----------CTC-----------|   |Toogle OC0 on comp. match|   |-------------clk_i/o / 8-------------|
	ldi R16, (1 << WGM01) | (0 << WGM00) | (0 << COM01) | (1 << COM00) | (0 << CS02) | (1 << CS01) | (0 << CS00)
	out TCCR0, R16
	ldi R16, (1 << OCIE0)
	out TIMSK, R16		; enable timer/counter0 compare mathc  interrupt

	clr R16
	out TCNT0, R16	; TCNT0 = 0x00 
	
	ldi T_ON, 0x18	; T_ON 	= 0x18
	ldi T_OFF, 0x4a	; T_OFF = 0x4a
	out OCR0, T_ON	; OCR0 	= 0x0c	

	ldi STATE, 0x01	; STATE = 0x01
	
	sei		; enable interrupts

MAIN:
	rjmp MAIN
