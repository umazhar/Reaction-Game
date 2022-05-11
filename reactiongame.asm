; ----------------------------------------------------------- ;
; ELEC 291 - 2021 WT2 
; Colin Pereira - 39875828
; Mohamed Salah - 18987292
; Umair Mazhar - 20333308
; ----------------------------------------------------------- ;

$NOLIST
$MODLP51
$LIST

CLK           EQU 22118400 ; Microcontroller system crystal frequency in Hz
TIMER0_RATE0  EQU ((2048*2)+100)
TIMER0_RATE1  EQU ((2048*2)-100)
TIMER0_RELOAD0 EQU ((65536-(CLK/TIMER0_RATE0)))
TIMER0_RELOAD1 EQU ((65536-(CLK/TIMER0_RATE1)))
SOUND_OUT EQU P1.2
RandomSeed	  EQU P4.5

org 0000H
   ljmp MyProgram

org 0x010B
	ljmp Timer0_ISR

cseg
; These 'equ' must match the hardware wiring
LCD_RS equ P3.2
;LCD_RW equ PX.X ; Not used in this code, connect the pin to GND
LCD_E  equ P3.3
LCD_D4 equ P3.4
LCD_D5 equ P3.5
LCD_D6 equ P3.6
LCD_D7 equ P3.7

$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$include(math32.inc);

DSEG at 0x30
Period_A: ds 2
Period_B: ds 2
x:		  ds 4
y:		  ds 4
bcd:	  ds 5
P1_points:  ds 1
P2_points:  ds 1
Seed:     ds 4

BSEG
mf:		  dbit 1

CSEG
;                      1234567890123456    <- This helps determine the location of the counter
Player1Message:     db 'Player1:        ', 0
Player2Message:     db 'Player2:        ', 0
EmptyScreen1:       db '                ', 0
Player1_Wins:       db ' player1 wins   ', 0
player2wins:        db ' player2 wins   ', 0  

; When using a 22.1184MHz crystal in fast mode
; one cycle takes 1.0/22.1184MHz = 45.21123 ns
; (tuned manually to get as close to 1s as possible)
Wait1s:
    mov R2, #176
X3: mov R1, #250
X2: mov R0, #166
X1: djnz R0, X1 ; 3 cycles->3*45.21123ns*166=22.51519us
    djnz R1, X2 ; 22.51519us*250=5.629ms
    djnz R2, X3 ; 5.629ms*176=1.0s (approximately)
    ret

;Initializes timer/counter 2 as a 16-bit timer
InitTimer2:
	mov T2CON, #0b_0000_0000 ; Stop timer/counter.  Set as timer (clock input is pin 22.1184MHz).
	; Set the reload value on overflow to zero (just in case is not zero)
	mov RCAP2H, #0
	mov RCAP2L, #0
    ret
    
InitTimer0:
	mov a, TMOD
	anl a, #0xf0 ; 11110000 Clear the bits for timer 0
	orl a, #0x01 ; 00000001 Configure timer 0 as 16-timer
	mov TMOD, a
	mov TH0, #high(TIMER0_RELOAD1)
	mov TL0, #low(TIMER0_RELOAD1)
	; Set autoreload value
	mov RH0, #high(TIMER0_RELOAD1)
	mov RL0, #low(TIMER0_RELOAD1)
	; Enable the timer and interrupts
    setb ET0  ; Enable timer 0 interrupt
    setb TR0  ; Start timer 0
	ret
	
Timer0_ISR:
	cpl SOUND_OUT ; Connect speaker to P2.2!
	reti

; ----------------------------------------------------------- ;
; Random seed generator
; ----------------------------------------------------------- ;
Random:
; Seed = 214013*seed + 2531011
	mov x+0, Seed+0
	mov x+1, Seed+1
	mov x+2, Seed+2
	mov x+3, Seed+3
	Load_y(214013)
	lcall mul32
	Load_y(2531011)
	lcall add32
	mov Seed+0, x+0
	mov Seed+1, x+1
	mov Seed+2, x+2
	mov Seed+3, x+3
	ret
	
Wait_Random:
	Wait_Milli_Seconds(Seed+0)
	Wait_Milli_Seconds(Seed+1)
	Wait_Milli_Seconds(Seed+2)
	Wait_Milli_Seconds(Seed+3)
	ret

HexToBcd:
	clr a
    mov R0, #0  ;Set BCD result to 00000000 
    mov R1, #0
    mov R2, #0
    mov R3, #16 ;Loop counter.

hex2bcd_loop:
    mov a, TL2 ;Shift TH0-TL0 left through carry
    rlc a
    mov TL2, a
    
    mov a, TH2
    rlc a
    mov TH2, a
      
	; Perform bcd + bcd + carry
	; using BCD numbers
	mov a, R0
	addc a, R0
	da a
	mov R0, a
	
	mov a, R1
	addc a, R1
	da a
	mov R1, a
	
	mov a, R2
	addc a, R2
	da a
	mov R2, a
	
	djnz R3, hex2bcd_loop
	ret

; Dumps the 5-digit packed BCD number in R2-R1-R0 into the LCD
DisplayBCD_LCD:
	; 5th digit:
    mov a, R2
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 4th digit:
    mov a, R1
    swap a
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 3rd digit:
    mov a, R1
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 2nd digit:
    mov a, R0
    swap a
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 1st digit:
    mov a, R0
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
    
    ret
    
;------------------------------
display_Player1Points_sc:
	ljmp display_Player1Points
;-----------------------------

;---------------------------------;
; Player 1 subroutines            ;
;---------------------------------;
Check_Player1:
	mov x+0, Period_A+0
	mov x+1, Period_A+1
	mov x+2, #0
	mov x+3, #0
	
	load_y(115)
	lcall x_gt_y
	
	jb mf, Player1_PointCounter ;if mf is enabled A is pressed
	jnb mf, display_Player1Points_sc
	
Player1_PointCounter:
	mov a, P1_points
	cjne a, #0x04, P1_points_add
	mov a, #0x00
	mov P1_points, a
	sjmp Player1_Wins
	
Player1_Wins:
	Set_Cursor(1, 1)
	Send_Constant_String(#Player1_Wins)
    Set_Cursor(2, 1)
    Send_Constant_String(#EmptyScreen1)
	ljmp Stop

P1_points_add:
    mov a, P1_points
    add a, #0x01
    da a
    mov P1_points, a
    mov mf, #0x00
	clr TR0
    ljmp display_Player1Points

;---------------------------------;
; Player 2 subroutines            ;
;---------------------------------;

Check_Player2:
	mov x+0, Period_B+0
	mov x+1, Period_B+1
	mov x+2, #0
	mov x+3, #0
	
	load_y(110)
	lcall x_gt_y
	
	jb mf, Player2_PointCounter ;if mf is high A is pressed
	ljmp display_Player2Points
	
Player2_PointCounter:
	mov a, P2_points
	cjne a, #0x04, Player2_PointAdd
	mov a, #0x00
	mov P2_points, a
	sjmp ShowPlayer2Win
	
ShowPlayer2Win:
	Set_Cursor(1, 1)
	Send_Constant_String(#player2wins)
    Set_Cursor(2, 1)
    Send_Constant_String(#EmptyScreen1)
	ljmp Stop

Player2_PointAdd:
    mov a, P2_points
    add a, #0x01
    da a
    mov P2_points, a
    da a
    mov mf, #0x00
    ljmp display_Player2Points
	
; Stop here and loop
Stop:
	clr TR0
	sjmp Stop

;---------------------------------;
; Hardware initialization         ;
;---------------------------------;
Initialize_All:
    lcall InitTimer2
	lcall InitTimer0
    lcall LCD_4BIT ; Initialize LCD
	mov P1_points, #0x00
	mov P2_points, #0x00
	ret
	
;---------------------------------;
; Main program loop               ;
;---------------------------------;
MyProgram:
    ; Initialize the hardware:
    mov SP, #7FH
    lcall Initialize_All    
    setb EA
    ; Make sure the two input pins are configure for input
    setb P2.0 ; Pin is used as input
    setb P2.1 ; Pin is used as input

	Set_Cursor(1, 1)
    Send_Constant_String(#Player1Message)
	Set_Cursor(2, 1)
    Send_Constant_String(#Player2Message)

;---------------------------------;
; Random Seed Setup               ;
;---------------------------------;
SetupRandom:
	setb TR0
	jnb RandomSeed, $
	mov Seed+0, TH0
	mov Seed+1, #0x01
	mov Seed+2, #0x87
	mov Seed+3, TL0
	clr TR0

;---------------------------------;
; frequency subroutines           ;
;---------------------------------;
Pick_frequency:
	lcall Random
	mov x+0, Seed+0
	mov x+1, Seed+1
	mov x+2, Seed+2
	mov x+3, Seed+3
	Load_y(2147483648)
    ;comparing frequency
	lcall x_lt_y
	jb mf, Frequency2 ;mf = 1, goes to frequency 2
	ljmp Frequency1

Frequency2: 
	clr TR0
	lcall Wait_Random
	lcall Wait_Random
	lcall Wait_Random
	
	mov RH0, #high(TIMER0_RELOAD0)
	mov RL0, #low(TIMER0_RELOAD0)
	setb TR0

	lcall Wait1s
	
    ljmp Player1_capacitor ; After beeping goes to counter to check 

;-----------------------------------;
; A and B plate period measurements ;
;-----------------------------------;
Player1_capacitor:
    ; Measure the period applied to pin P2.0
    clr TR2 ; Stop counter 2
    mov TL2, #0
    mov TH2, #0
    jb P2.0, $
    jnb P2.0, $
    setb TR2 ; Start counter 0
    jb P2.0, $
    jnb P2.0, $
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.0 for later use
    mov Period_A+0, TL2
    mov Period_A+1, TH2
    ljmp Check_Player1

    
Player2_Capacitor:
    ; Measure the period applied to pin P2.1
    clr TR2 ; Stop counter 2
    mov TL2, #0
    mov TH2, #0
    jb P2.1, $
    jnb P2.1, $
    setb TR2 ; Start counter 0
    jb P2.1, $
    jnb P2.1, $
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.1 for later use
    mov Period_B+0, TL2
    mov Period_B+1, TH2
    ljmp Check_Player2

;---------------------------------;
; Displaying pointa           ;
;---------------------------------;
	
display_Player1Points:
    Set_Cursor(1, 14)     ; the place in the LCD where we want the BCD counter value
	Display_BCD(P1_points)
    ljmp Player2_Capacitor ; check Player2_Capacitor

display_Player2Points:
	Set_Cursor(2,14)
	Display_BCD(P2_points)
	ljmp Pick_frequency
end