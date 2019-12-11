;---------------------------------------------------------------------------------
; Ross Bollinger
; Professor Alan Ford
; 10 December 2019
; CSC 240
; Final Project
; Description: This program will run a game in which the objective is to stay within the borders of the screen for a certain amount of time.
;			   The player (a spaceship) can move left, right, up, or down. When the player has moved 200 spaces, they win, but if they hit a border,
;			   it's game over.
;---------------------------------------------------------------------------------
; Guide for numbers:
; "01": 0x
;-----------------------------------Directives------------------------------------
; Setting the size of the screen for the GFX library
.equ		OLED_WIDTH = 128
.equ		OLED_HEIGHT = 64
; Creating variables for the sprites listed in the character_map library. Notice that the picture does not have these sprites.
; That's because I created my own using a website called Piskel. Find them at https://www.piskelapp.com/
; There are 8 sprites in total, one ship sprite and one launch fire sprite for each direction.
.equ		ship_U = 0xE0
.equ		ship_R = 0xE1
.equ		ship_D = 0xE2
.equ		ship_L = 0xE3
.equ		fire_U = 0xE4
.equ		fire_R = 0xE5
.equ		fire_D = 0xE6
.equ		fire_L = 0xE7
; Adding in extra characters for in game messages like "YOU WIN!" and "GAME OVER"
.equ		blank = 0x00  ; " "
.equ		char_A = 0x41 ; "A"
.equ		char_E = 0x45 ; "E"
.equ		char_G = 0x47 ; "G"
.equ		char_I = 0x49 ; "I"
.equ		char_M = 0x4D ; "M"
.equ		char_N = 0x4E ; "N"
.equ		char_O = 0x4F ; "O"
.equ		char_R = 0x52 ; "R"
.equ		char_U = 0x55 ; "U"
.equ		char_V = 0x56 ; "V"
.equ		char_W = 0x57 ; "W"
.equ		char_Y = 0x59 ; "Y"
.equ		char_exc_point = 0x21 ; "!"
; Setting variables for the boundaries of the screen. If these are reached, then it's game over
.equ		bound_left = -1
.equ		bound_right = 16
.equ		bound_upper = -1
.equ		bound_lower = 8
; Setting variables for the four different values that are inputted from buttons for directions. I use PC0-3 for these inputs.
.equ		dir_right = 0b00000001 ; PC0 for right
.equ		dir_down = 0b00000010  ; PC1 for down
.equ		dir_left = 0b00000100  ; PC2 for left
.equ		dir_up = 0b00001000    ; PC3 for up

; Giving the registers used later names
.def		y_pos = r19		   ; setting Y position on screen
.def		x_pos = r18		   ; setting X position on screen
.def		sprite = r17		   ; storing the sprite written to screen
.def		workhorse = r29		   ; generic temp register for multiple uses
; These next two are for keeping track of the overall (global) position of the player, 
; so that the x_pos and y_pos registers may be manipulated if necessary
.def		position_count_x = r14     ; for saving the global x position of the player
.def		position_count_y = r13     ; for saving the global y position of the player
.def		state = r28	           ; for telling the program what button was pressed
.def		score_counter = r23        ; for keeping track of how many spaces the player has moved, i.e. the "score"

.cseg
.org		0x0000
	rjmp		setup
.org		0x0005
	rjmp		change_dir ; if an interrupt is triggered by an input from PORT C, jump to the "change_dir" interrupt subroutine
.org		0x0100
.include "lib_delay.asm"
.include "lib_SSD1306_OLED.asm"
.include "lib_GFX.asm"
;-----------------------------------------------------------------------------

;------------------------------------Setup------------------------------------
setup:
	; Initializing and setting up the screen by clearing it and refreshing it
	rcall		OLED_initialize
	rcall		GFX_clear_array
	rcall		GFX_refresh_screen

	; Setting up the PORT C pins as inputs, then setting PC0-3 as capable of causing interrupts on the falling edge
	ldi		workhorse, 0b00000000
	sts		PORTC_DIR, workhorse
	ldi		workhorse, 0b00001011
	sts		PORTC_PIN0CTRL, workhorse
	sts		PORTC_PIN1CTRL, workhorse
	sts		PORTC_PIN2CTRL, workhorse
	sts		PORTC_PIN3CTRL, workhorse

	; Setting various other game related things
	ldi		score_counter, 0		; initializing score counter
	ldi		state, dir_right		; initializing state with the default direction: right
	ldi		workhorse, 0				
	mov		position_count_x, workhorse     ; initializing global x position
	mov		position_count_y, workhorse     ; initializing global y position
	mov		x_pos, position_count_x		; initializing x position for the screen
	mov		y_pos, position_count_y		; initializing y position for the screen
	rcall		GFX_set_array_pos		; function in GFX library that actually sets the position on screen using x_pos and y_pos

	; Enables global interrupts
	sei
;-----------------------------------------------------------------------------

;------------------------------------Loops------------------------------------
; main_loop has 4 jobs:
; 1. Sets the speed at which the sprite moves across the screen (i.e. the delays)
; 2. Checks for whether the sprite has reached the boundaries set in the directives section, 
;    and jumps to the "game_over_reset" subroutine if so.
; 3. Checks if the score has reached 200, and jumps to the game_win_reset subroutine
; 4. Chooses which direction that the sprite will travel based on the state as set by whichever button has altered the state register 
main_loop:
	; 1.
	rcall		delay_10ms
	rcall		delay_10ms
	rcall		delay_10ms
	; 2.
	bound_check:
		mov		x_pos, position_count_x
		mov		y_pos, position_count_y
		cpi		x_pos, bound_left
		breq		game_over
		cpi		x_pos, bound_right
		breq		game_over
		cpi		y_pos, bound_upper
		breq		game_over
		cpi		y_pos, bound_lower
		breq		game_over
		rcall		GFX_set_array_pos
	; 3.
	score_check:
		inc		score_counter
		cpi		score_counter, 200
		breq		game_win
	; 4.
	cpi		state, dir_right
	breq		loop_right
	cpi		state, dir_left
	breq		loop_left
	cpi		state, dir_down
	breq		loop_down
	cpi		state, dir_up
	breq		loop_up
	loop_right:
		rjmp		draw_right
	loop_left:
		rjmp		draw_left
	loop_down:
		rjmp		draw_down
	loop_up:
		rjmp		draw_up
	; Note that both "game_over" and "game_win" clear the character array and set the state to 0.
	; This is to allow for the two subroutines called within them to be interrupted more smoothly.
	game_over:
		rcall		GFX_clear_array
		ldi		state, 0b00000000
		rjmp		game_over_reset
	game_win:
		rcall		GFX_clear_array
		ldi		state, 0b00000000
		rjmp		game_win_reset
;---------------------------------------------------------------------------------

;-----------------------------------Subroutines-----------------------------------
; For drawing the two right-iterated sprites. It draws the ship sprite first, decrements x_pos, then draws the fire sprite.
; After this, it increments the global x position (via position_count_x)
draw_right:
	ldi		sprite, ship_R
	st		X, sprite
	rcall		next_char_R
        ldi		sprite, fire_R
	st		X, sprite
	; the two following instructions are used to update the screen with the sprites, then clear the array so that there are no leftover sprites
	; that fill up the screen.
	rcall		GFX_refresh_screen
	rcall		GFX_clear_array
	inc		position_count_x
	; jump back up to main loop to repeat the bound check, score check, and direction check processes
	rjmp		main_loop

; Draws left-oriented sprites. Only difference is that it increments x_pos after drawing the first sprite in order to draw the second sprite.
; It also decrements the the global x position (via position_count_x)
draw_left:
	ldi		sprite, ship_L
	st		X, sprite
	rcall		next_char_L
    	ldi		sprite, fire_L
	st		X, sprite
	rcall		GFX_refresh_screen
	rcall		GFX_clear_array
	dec			position_count_x
	rjmp		main_loop		

; Draws downward_oriented sprites. It draws the first sprite, increments the y_pos, then draws the second sprite.
; It then increments the global y position (via position_count_y) 
draw_down:
	ldi		sprite, ship_D
	st		X, sprite
	rcall		next_char_D
	ldi		sprite, fire_D
	st		X, sprite
	rcall		GFX_refresh_screen
	rcall		GFX_clear_array
	inc		position_count_y
	rjmp		main_loop

; Draws upward_oriented sprites. Draws first sprite, decrements y_pos, then draws second sprite.
; Moves upward by decrementing the global y position (via position_count_y)
draw_up:
	ldi		sprite, ship_U
	st		X, sprite
	rcall		next_char_U
	ldi		sprite, fire_U
	st		X, sprite
	rcall		GFX_refresh_screen
	rcall		GFX_clear_array
	dec		position_count_y
	rjmp		main_loop
	
; Subroutine for decrementing x_pos to draw the next right-oriented sprite
next_char_R:
	dec		x_pos
	rcall		GFX_set_array_pos
	ret			

; Subroutine for incrementing x_pos to draw the next left-oriented sprite
next_char_L:
	inc		x_pos
	rcall		GFX_set_array_pos
	ret

; Subroutine for incrementing y_pos to draw the next downward-oriented sprite
next_char_D:
	dec		y_pos
	rcall		GFX_set_array_pos
	ret

; Subroutine for decrementing y_pos to draw the next upward-oriented sprite
next_char_U:
	inc		y_pos
	rcall		GFX_set_array_pos
	ret

; Subroutine that clears the screen and writes "GAME  OVER" to it. It is triggered in the main loop if the boundaries are reached.
; It loops until any button is pressed, at which point it jumps to the main loop and starts the movement in the default direction 
game_over_reset:
	; All for writing "GAME  OVER" at the center of the screen
	ldi		x_pos, 3
	ldi		y_pos, 4
	rcall		GFX_set_array_pos
	ldi		sprite, char_G
	st		X+, sprite
	ldi		sprite, char_A
	st		X+, sprite
	ldi		sprite, char_M
	st		X+, sprite
	ldi		sprite, char_E
	st		X+, sprite
	ldi		sprite, blank
	st		X+, sprite
	ldi		sprite, blank
	st		X+, sprite
	ldi		sprite, char_O
	st		X+, sprite
	ldi		sprite, char_V
	st		X+, sprite
	ldi		sprite, char_E
	st		X+, sprite
	ldi		sprite, char_R
	st		X+, sprite
	rcall		GFX_refresh_screen
	cpi		state, 0b00000000
	brne		game_over_end
	rjmp		game_over_reset
	; Triggered when a button is pressed: clears game over screen and resets all position data.
	; It also sets the state register to the default direction.
	game_over_end:
		ldi		score_counter, 0
		ldi		state, dir_right
		rcall		GFX_clear_array
		ldi		workhorse, 0
		mov		position_count_x, workhorse
		mov		position_count_y, workhorse
		rjmp		main_loop

; Subroutine that flashes "YOU WIN!" on the screen until a button is pressed, at which point it resets the game the exact same way
; that "game_over_reset" does. It is triggered when the player has successfully moved 200 spaces without touching the boundaries.
game_win_reset:
	ldi		x_pos, 4
	ldi		y_pos, 4
	rcall		GFX_set_array_pos
	ldi		sprite, char_Y
	st		X+, sprite
	ldi		sprite, char_O
	st		X+, sprite
	ldi		sprite, char_U
	st		X+, sprite
	ldi		sprite, blank
	st		X+, sprite
	ldi		sprite, char_W
	st		X+, sprite
	ldi		sprite, char_I
	st		X+, sprite
	ldi		sprite, char_N
	st		X+, sprite
	ldi		sprite, char_exc_point
	st		X+, sprite
	rcall		GFX_refresh_screen
	rcall		delay_100ms
	rcall		GFX_clear_array
	rcall		GFX_refresh_screen
	rcall		delay_100ms
	cpi		state, 0b00000000
	brne		game_win_end
	rjmp		game_win_reset
	; Does the exact same thing as "game_over_end"
	game_win_end:
		ldi		score_counter, 0
		ldi		state, 0b00000001
		rcall		GFX_clear_array
		ldi		x_pos, 0
		ldi		y_pos, 0
		rcall		GFX_set_array_pos
		ldi		workhorse, 0
		mov		position_count_x, workhorse
		mov		position_count_y, workhorse
		rjmp		main_loop	
;---------------------------------------------------------------------------------

;------------------------------------Interrupt------------------------------------
; Interrupt subroutine that is triggered by the push of any of the four buttons.
; It sets the "state" register to the value that represents whatever PORT C pin had a button press (i.e. 0b00000001 for PC0, etc).
; It then resets all interrupt flags so that further interrupts can be triggered. 
change_dir:
	lds		state, PORTC_INTFLAGS
	ldi		workhorse, 0b00001111
	sts		PORTC_INTFLAGS, workhorse
	reti
;---------------------------------------------------------------------------------
