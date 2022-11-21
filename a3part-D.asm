;
; a3part-D.asm
;
; Part D of assignment #3
;
;
; Student name:
; Student ID:
; Date of completed work:
;
; **********************************
; Code provided for Assignment #3
;
; Author: Mike Zastre (2022-Nov-05)
;
; This skeleton of an assembly-language program is provided to help you 
; begin with the programming tasks for A#3. As with A#2 and A#1, there are
; "DO NOT TOUCH" sections. You are *not* to modify the lines within these
; sections. The only exceptions are for specific changes announced on
; Brightspace or in written permission from the course instruction.
; *** Unapproved changes could result in incorrect code execution
; during assignment evaluation, along with an assignment grade of zero. ***
;


; =============================================
; ==== BEGINNING OF "DO NOT TOUCH" SECTION ====
; =============================================
;
; In this "DO NOT TOUCH" section are:
; 
; (1) assembler direction setting up the interrupt-vector table
;
; (2) "includes" for the LCD display
;
; (3) some definitions of constants that may be used later in
;     the program
;
; (4) code for initial setup of the Analog-to-Digital Converter
;     (in the same manner in which it was set up for Lab #4)
;
; (5) Code for setting up three timers (timers 1, 3, and 4).
;
; After all this initial code, your own solutions's code may start
;

.cseg
.org 0
	jmp reset

; Actual .org details for this an other interrupt vectors can be
; obtained from main ATmega2560 data sheet
;
.org 0x22
	jmp timer1

; This included for completeness. Because timer3 is used to
; drive updates of the LCD display, and because LCD routines
; *cannot* be called from within an interrupt handler, we
; will need to use a polling loop for timer3.
;
; .org 0x40
;	jmp timer3

.org 0x54
	jmp timer4

.include "m2560def.inc"
.include "lcd.asm"

.cseg
#define CLOCK 16.0e6
#define DELAY1 0.01
#define DELAY3 0.1
#define DELAY4 0.5

#define BUTTON_RIGHT_MASK 0b00000001	
#define BUTTON_UP_MASK    0b00000010
#define BUTTON_DOWN_MASK  0b00000100
#define BUTTON_LEFT_MASK  0b00001000

#define BUTTON_RIGHT_ADC  0x052   ;was 0x032
#define BUTTON_UP_ADC     0x0b0   ; was 0x0c3
#define BUTTON_DOWN_ADC   0x160   ; was 0x17c
#define BUTTON_LEFT_ADC   0x22b
#define BUTTON_SELECT_ADC 0x316

.equ PRESCALE_DIV=1024   ; w.r.t. clock, CS[2:0] = 0b101

; TIMER1 is a 16-bit timer. If the Output Compare value is
; larger than what can be stored in 16 bits, then either
; the PRESCALE needs to be larger, or the DELAY has to be
; shorter, or both.
.equ TOP1=int(0.5+(CLOCK/PRESCALE_DIV*DELAY1))
.if TOP1>65535
.error "TOP1 is out of range"
.endif

; TIMER3 is a 16-bit timer. If the Output Compare value is
; larger than what can be stored in 16 bits, then either
; the PRESCALE needs to be larger, or the DELAY has to be
; shorter, or both.
.equ TOP3=int(0.5+(CLOCK/PRESCALE_DIV*DELAY3))
.if TOP3>65535
.error "TOP3 is out of range"
.endif

; TIMER4 is a 16-bit timer. If the Output Compare value is
; larger than what can be stored in 16 bits, then either
; the PRESCALE needs to be larger, or the DELAY has to be
; shorter, or both.
.equ TOP4=int(0.5+(CLOCK/PRESCALE_DIV*DELAY4))
.if TOP4>65535
.error "TOP4 is out of range"
.endif

reset:
; ***************************************************
; **** BEGINNING OF FIRST "STUDENT CODE" SECTION ****
; ***************************************************
.def tmp = r20


ldi tmp, low(RAMEND)
out SPL, tmp
ldi tmp, high(RAMEND)
out SPH , tmp

call lcd_init
ldi r25, 'a'
ldi r16, 0x87 
sts ADCSRA, r16

ldi r16, ' '
sts TOP_LINE_CONTENT, r16

ldi r17, 16

ldi ZH, high(TOP_LINE_CONTENT)
ldi ZL, low(TOP_LINE_CONTENT)

load_TOP_LINE_CONTENT:
		st Z+, r16
		dec r17
		brne load_TOP_LINE_CONTENT

ldi r16, 0
sts CURRENT_CHAR_INDEX, r16

;ldi XH, high(TOP_LINE_CONTENT)
;ldi XL, low(TOP_LINE_CONTENT)

;ldi ZH, high(TOP_LINE_CONTENT)
;ldi ZL, low(TOP_LINE_CONTENT)

;load_CURRENT_CHARSET_INDEX:
	
; Anything that needs initialization before interrupts
; start must be placed here.

; ***************************************************
; ******* END OF FIRST "STUDENT CODE" SECTION *******
; ***************************************************

; =============================================
; ====  START OF "DO NOT TOUCH" SECTION    ====
; =============================================

	; initialize the ADC converter (which is needed
	; to read buttons on shield). Note that we'll
	; use the interrupt handler for timer 1 to
	; read the buttons (i.e., every 10 ms)
	;
	ldi temp, (1 << ADEN) | (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0)
	sts ADCSRA, temp
	ldi temp, (1 << REFS0)
	sts ADMUX, r16

	; Timer 1 is for sampling the buttons at 10 ms intervals.
	; We will use an interrupt handler for this timer.
	ldi r17, high(TOP1)
	ldi r16, low(TOP1)
	sts OCR1AH, r17
	sts OCR1AL, r16
	clr r16
	sts TCCR1A, r16
	ldi r16, (1 << WGM12) | (1 << CS12) | (1 << CS10)
	sts TCCR1B, r16
	ldi r16, (1 << OCIE1A)
	sts TIMSK1, r16

	; Timer 3 is for updating the LCD display. We are
	; *not* able to call LCD routines from within an 
	; interrupt handler, so this timer must be used
	; in a polling loop.
	ldi r17, high(TOP3)
	ldi r16, low(TOP3)
	sts OCR3AH, r17
	sts OCR3AL, r16
	clr r16
	sts TCCR3A, r16
	ldi r16, (1 << WGM32) | (1 << CS32) | (1 << CS30)
	sts TCCR3B, r16
	; Notice that the code for enabling the Timer 3
	; interrupt is missing at this point.

	; Timer 4 is for updating the contents to be displayed
	; on the top line of the LCD.
	ldi r17, high(TOP4)
	ldi r16, low(TOP4)
	sts OCR4AH, r17
	sts OCR4AL, r16
	clr r16
	sts TCCR4A, r16
	ldi r16, (1 << WGM42) | (1 << CS42) | (1 << CS40)
	sts TCCR4B, r16
	ldi r16, (1 << OCIE4A)
	sts TIMSK4, r16

	sei

; =============================================
; ====    END OF "DO NOT TOUCH" SECTION    ====
; =============================================

; ****************************************************
; **** BEGINNING OF SECOND "STUDENT CODE" SECTION ****
; ****************************************************

start:
	rjmp timer3
stop:
	rjmp stop


timer1:
check_button:
	push r23
	push r16
	push r17
	push r19
	push XH
	push XL
	push ZL
	push ZH	
	
	lds r16, SREG
	push r16
	//to:do save sreg

	ldi r17, 0x01
	lds r16, ADCSRA
	ori r16, 0x40
	sts ADCSRA, r16
wait:
	lds r16, ADCSRA
	andi r16, 0x40
	brne wait

		; read the value, use XH:XL to store the 10-bit result
	lds XL, ADCL
	lds XH, ADCH
	
	ldi r19, 0
	clr r23


right:
	ldi ZL, low(BUTTON_RIGHT_ADC) 
	ldi ZH, high(BUTTON_RIGHT_ADC)
	cp XL, ZL
	cpc XH, ZH
	brsh up		
	ldi r19, 0b00000001
	rjmp select
up:	
	ldi ZL, low(BUTTON_UP_ADC) 
	ldi ZH, high(BUTTON_UP_ADC)	
	cp XL, ZL
	cpc XH, ZH
	brsh down		
	ldi r19, 0b00000010
	rjmp select

down:
	ldi ZL, low(BUTTON_DOWN_ADC ) 
	ldi ZH, high(BUTTON_DOWN_ADC )
	cp XL, ZL
	cpc XH, ZH
	brsh left		
	ldi r19, 0b00000100
	rjmp select

left:	
	ldi r19,  BUTTON_LEFT_MASK
	ldi ZL, low(BUTTON_LEFT_ADC ) 
	ldi ZH, high(BUTTON_LEFT_ADC )
	cp XL, ZL
	cpc XH, ZH
	brsh select		
	ldi r19, 0b00001000
	
select:
	ldi ZL, low(BUTTON_SELECT_ADC) 
	ldi ZH, high(BUTTON_SELECT_ADC)
	cp XL, ZL
	cpc XH, ZH
	brsh skip		
	sts BUTTON_IS_PRESSED, r17
	rjmp skiper
skip:	
	sts BUTTON_IS_PRESSED, r23;is 0 if none are pressed

skiper:
	sts LAST_BUTTON_PRESSED, r19
	pop r16
	sts SREG, r16
	pop ZH
	pop ZL
	pop XL
	pop XH
	pop r19
	pop r17
	pop r16
	pop r23
	reti


;
;
; START OF TIMER 3
;
;


timer3:
	in temp, TIFR3
	sbrs temp, OCF3A
	rjmp timer3

	ldi temp, 1<<OCF3A
	out TIFR3, temp

	rjmp button_press

button_press:
	ldi temp, 1
	ldi r18, 15
	ldi r19, 0

	push temp
	push r18
	rcall lcd_gotoxy
	pop r18
	pop temp
	
	
	lds temp, BUTTON_IS_PRESSED
	
	sbrc temp, 0
	rjmp currently_pressed
	rjmp default_char
	
	
currently_pressed:
	ldi temp, '*'
	push temp
	rcall lcd_putchar
	pop temp
	rjmp check_which_button

check_which_button:
	lds temp, LAST_BUTTON_PRESSED
	sbrc temp, 0
	rjmp right_pressed
	sbrc temp, 1
	rjmp up_pressed
	sbrc temp, 2
	rjmp down_pressed
	sbrc temp, 3
	rjmp left_pressed
	rjmp timer3

right_pressed:
	ldi temp, 1
	ldi r18, 3
	call clear_up
	call clear_down
	call clear_left
	
	push temp
	push r18
	rcall lcd_gotoxy
	pop r18
	pop temp

	ldi temp, 'R'
	push temp
	rcall lcd_putchar
	pop temp
	rjmp timer3
	

up_pressed:
	ldi temp, 1
	ldi r18, 2
	call clear_right
	call clear_down
	call clear_left

	push temp
	push r18
	rcall lcd_gotoxy
	pop r18
	pop temp

	ldi temp, 'U'
	push temp
	rcall lcd_putchar
	pop temp

	ldi temp, 0
	lds r18, CURRENT_CHAR_INDEX

	push temp
	push r18
	rcall lcd_gotoxy
	pop r18
	pop temp

	lds temp, TOP_LINE_CONTENT
	push temp
	rcall lcd_putchar
	pop temp

	rjmp timer3

down_pressed:
	ldi temp, 1
	ldi r18, 1
	call clear_right
	call clear_up
	call clear_left

	push temp
	push r18
	rcall lcd_gotoxy
	pop r18
	pop temp

	ldi temp, 'D'
	push temp
	rcall lcd_putchar
	pop temp

	ldi temp, 0
	lds r18, CURRENT_CHAR_INDEX

	push temp
	push r18
	rcall lcd_gotoxy
	pop r18
	pop temp

	lds temp, TOP_LINE_CONTENT
	push temp
	rcall lcd_putchar
	pop temp

	rjmp timer3


left_pressed:
	ldi temp, 1
	ldi r18, 0
	call clear_right
	call clear_up
	call clear_down

	push temp
	push r18
	rcall lcd_gotoxy
	pop r18
	pop temp

	ldi temp, 'L'
	push temp
	rcall lcd_putchar
	pop temp
	rjmp timer3


default_char:
	ldi temp, '-'
	push temp
	rcall lcd_putchar
	pop temp
	rjmp timer3

clear_right:
	push temp
	push r18

	ldi temp, 1
	ldi r18, 3

	push temp
	push r18
	rcall lcd_gotoxy
	pop r18
	pop temp

	ldi temp, ' '
	push temp
	rcall lcd_putchar
	pop temp
	pop r18
	pop temp

	ret

clear_up:
	push temp
	push r18

	ldi temp, 1
	ldi r18, 2

	push temp
	push r18
	rcall lcd_gotoxy
	pop r18
	pop temp

	ldi temp, ' '
	push temp
	rcall lcd_putchar
	pop temp

	pop r18
	pop temp

	ret
clear_down:
	push temp
	push r18
	ldi temp, 1
	ldi r18, 1

	push temp
	push r18
	rcall lcd_gotoxy
	pop r18
	pop temp

	ldi temp, ' '
	push temp
	rcall lcd_putchar
	pop temp
	pop r18
	pop temp
	ret
	
clear_left:
	push temp
	push r18
	ldi temp, 1
	ldi r18, 0

	push temp
	push r18
	rcall lcd_gotoxy
	pop r18
	pop temp

	ldi temp, ' '
	push temp
	rcall lcd_putchar
	pop temp

	pop r18
	pop temp

	ret
	

; timer3:
;
; Note: There is no "timer3" interrupt handler as you must use
; timer3 in a polling style (i.e. it is used to drive the refreshing
; of the LCD display, but LCD functions cannot be called/used from
; within an interrupt handler).


timer4:
	push r23
	push r16
	push r17
	push r19
	push XH
	push XL
	push ZL
	push ZH	
	push YH
	push YL
	lds r16, SREG
	push r16

	ldi ZH, high(AVAILABLE_CHARSET<<1)
	ldi ZL, low(AVAILABLE_CHARSET<<1)

	ldi r19, ' '
	lds r23, BUTTON_IS_PRESSED
	lds r17, LAST_BUTTON_PRESSED
	lds r16, TOP_LINE_CONTENT
	

button_hold:
	sbrs r23, 0
	rjmp end_t4
	cp r19, r16
	breq set_0
	cpi r17, 0b00000001
	breq go_right
	cpi r17, 0b00001000
	breq go_left
	jmp find_curr
updown_button:
	lds r17, LAST_BUTTON_PRESSED
	sbrs r17, 0b00000010
	jmp case_up // the up button is pressed and is currently pressed use the curr
	sbrs r17, 0b00000100
	jmp before_curr// if the down button pressed go to find the prev number
	rjmp end_t4

set_0: 
	lpm r23, Z
	sts TOP_LINE_CONTENT, r23
	jmp end_t4

go_right:
	lds r23, CURRENT_CHAR_INDEX
	cpi r23, 16
	breq go_to_col_0
	inc r23
	sts CURRENT_CHAR_INDEX, r23
	jmp end_t4
go_to_col_0:
	ldi r23, 0
	sts CURRENT_CHAR_INDEX, r23
	jmp end_t4

go_left:
	lds r23, CURRENT_CHAR_INDEX
	cpi r23, 0 
	breq go_to_col_15
	dec r23
	sts CURRENT_CHAR_INDEX, r23
	jmp end_t4
go_to_col_15:
	ldi r23, 15
	sts CURRENT_CHAR_INDEX, r23
	jmp end_t4


find_curr:
	ldi r17, CURRENT_CHAR_INDEX
	ldi ZH, high(TOP_LINE_CONTENT<<1)
	ldi ZL, low(TOP_LINE_CONTENT<<1)
get_index:
	dec r17
	lpm r16, Z+
	brne get_index

	ldi ZH, high(AVAILABLE_CHARSET<<1)
	ldi ZL, low(AVAILABLE_CHARSET<<1)	lpm r16, Z
	ldi r17, '_'

keep_find:
	lpm r23, Z+
	cp r23, r16
	brne keep_find
	breq store_curr_Z

store_curr_Z:
	lpm r23, Z // stores the curr letter in r23
	jmp updown_button 


before_curr: 
	ldi r19, 15 // number of times we go forward
	ldi r17, '_'

keep_find2:
	lpm r16, Z+
	cp r16, r17
	breq under_score_start
	dec r19
	brne keep_find2
	jmp store_curr_2

under_score_start:
	ldi ZH, high(AVAILABLE_CHARSET<<1)
	ldi ZL, low(AVAILABLE_CHARSET<<1)
	rjmp keep_find2
store_curr_2:
	sts TOP_LINE_CONTENT, r16
	jmp case_down// go to the case down

case_up:
	ldi r17, '_'
	lpm r16, Z+
	cp r16, r17
	breq back_to_zero//check if hypen if is skip
	sts TOP_LINE_CONTENT,r16
	jmp end_t4
back_to_zero:
	ldi ZH, high(AVAILABLE_CHARSET<<1)// just points back to start of charset
	ldi ZL, low(AVAILABLE_CHARSET<<1)
	lpm r16, Z
	sts TOP_LINE_CONTENT,r16

case_down:
	;sts TOP_LINE_CONTENT, r16
	jmp end_t4


end_t4:
	pop r16
	sts SREG, r16
	pop YL
	pop YH
	pop ZH
	pop ZL
	pop XL
	pop XH
	pop r19
	pop r17
	pop r16
	pop r23
	reti



; ****************************************************
; ******* END OF SECOND "STUDENT CODE" SECTION *******
; ****************************************************


; =============================================
; ==== BEGINNING OF "DO NOT TOUCH" SECTION ====
; =============================================

; r17:r16 -- word 1
; r19:r18 -- word 2
; word 1 < word 2? return -1 in r25
; word 1 > word 2? return 1 in r25
; word 1 == word 2? return 0 in r25
;
compare_words:
	; if high bytes are different, look at lower bytes
	cp r17, r19
	breq compare_words_lower_byte

	; since high bytes are different, use these to
	; determine result
	;
	; if C is set from previous cp, it means r17 < r19
	; 
	; preload r25 with 1 with the assume r17 > r19
	ldi r25, 1
	brcs compare_words_is_less_than
	rjmp compare_words_exit

compare_words_is_less_than:
	ldi r25, -1
	rjmp compare_words_exit

compare_words_lower_byte:
	clr r25
	cp r16, r18
	breq compare_words_exit

	ldi r25, 1
	brcs compare_words_is_less_than  ; re-use what we already wrote...

compare_words_exit:
	ret

.cseg
AVAILABLE_CHARSET: .db "0123456789abcdef_", 0


.dseg

BUTTON_IS_PRESSED: .byte 1			; updated by timer1 interrupt, used by LCD update loop
LAST_BUTTON_PRESSED: .byte 1        ; updated by timer1 interrupt, used by LCD update loop

TOP_LINE_CONTENT: .byte 16			; updated by timer4 interrupt, used by LCD update loop
CURRENT_CHARSET_INDEX: .byte 16		; updated by timer4 interrupt, used by LCD update loop
CURRENT_CHAR_INDEX: .byte 1			; ; updated by timer4 interrupt, used by LCD update loop


; =============================================
; ======= END OF "DO NOT TOUCH" SECTION =======
; =============================================


; ***************************************************
; **** BEGINNING OF THIRD "STUDENT CODE" SECTION ****
; ***************************************************

.dseg
TEST: .byte 1

; If you should need additional memory for storage of state,
; then place it within the section. However, the items here
; must not be simply a way to replace or ignore the memory
; locations provided up above.


; ***************************************************
; ******* END OF THIRD "STUDENT CODE" SECTION *******
; ***************************************************
