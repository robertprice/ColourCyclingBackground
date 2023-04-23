;------------------------------
; Colour cycle a background image
; Robert Price - 24/4/2023
;
;---------- Includes ----------
            INCDIR      "include"
            INCLUDE     "hw.i"
            INCLUDE     "funcdef.i"
            INCLUDE     "exec/exec_lib.i"
            INCLUDE 	"graphics/gfxbase.i"
            INCLUDE     "graphics/graphics_lib.i"
            INCLUDE     "hardware/cia.i"
;---------- Const ----------

CIAA        EQU $bfe001

FADEDELAY	EQU	10

			SECTION logo,DATA_C

screen:		INCBIN	"trippy320x256x8.raw"			; 320x256 three bit plane image

            SECTION Code,CODE,CHIP

init:
            movem.l     d0-a6,-(sp)
            move.l      4.w,a6							; execbase
            moveq.l		#0,d0

            move.l      #gfxname,a1						; get the name of the graphics library
            jsr         _LVOOldOpenLibrary(a6)
            move.l      d0,a1
            move.l		gb_copinit(a1),d4				; save the current copper list so we can restore it later.
            move.l      d4,CopperSave
            jsr         _LVOCloseLibrary(a6)

            lea         CUSTOM,a6                      ; Load the address of the custom registers indo a6

            move.w      INTENAR(a6),INTENARSave        ; Save original interupts
            move.w      DMACONR(a6),DMACONSave         ; Save DMACON
            move.w      #$138,d0                       ; wait for eoframe
            bsr.w       WaitRaster                     
            move.w      #$7fff,INTENA(a6)              ; disable interupts
														; Set INTREQ twice due to A4000 bug.
            move.w      #$7fff,INTREQ(a6)              ; disable all bits in INTREQ
            move.w      #$7fff,INTREQ(a6)              ; disable all bits in INTREQ

			; SET & BLTPRI & DMAEN & BPLEN & COPEN & BLTEN & SPREN bits
            move.w      #%1000011111100000,DMACON(a6)

; setup bitplane1 in the copper list to point to the first bitplane.
			move.l	#screen,d0
			move.w	d0,copBp1P+6						; set the low word
			swap	d0
			move.w	d0,copBp1P+2						; set the high word

; setup bitplane2 in the copper list to point to the second bitplane.
			move.l	#screen+((320*256)/8),d0
			move.w	d0,copBp2P+6						; set the low word
			swap	d0
			move.w	d0,copBp2P+2						; set the high word

; setup bitplane3 in the copper list to point to the third bitplane.
			move.l	#screen+(((320*256)/8)*2),d0
			move.w	d0,copBp3P+6						; set the low word
			swap	d0
			move.w	d0,copBp3P+2						; set the high word


; install our copper list
            move.l      #myCopperList,COP1LC(a6)
            move.w      #0,COPJMP1(a6)
******************************************************************

			moveq.l		#FADEDELAY,d2							; set a delay, this is the number of vblanks between each fade operation.
mainloop:

; Wait for vertical blank
            move.w      #$0c,d0                       	;No buffering, so wait until raster
            bsr.w       WaitRaster                    	;is below the Display Window.

			subq.l		#1,d2							; delay countdown
			bne.s		.skipFade						; if not zero, skip the fade

; colour cycle by copying the last colour to d0, then copying the other colours down one level
; finally restoring d0 to the first colour in the copper list.
.fadeThis
			move.w		(copColours+26),d0	
			move.w		(copColours+22),(copColours+26)
			move.w		(copColours+18),(copColours+22)
			move.w		(copColours+14),(copColours+18)
			move.w		(copColours+10),(copColours+14)
			move.w		(copColours+6),(copColours+10)
			move.w		(copColours+2),(copColours+6)
			move.w		d0,(copColours+2)

.fadeCompleted:
			moveq.l		#FADEDELAY,d2				; reset the delay countdown
.skipFade:

; check if the left mouse button has been pressed
; if it hasn't, loop back.
checkmouse:
            btst        #CIAB_GAMEPORT0,CIAA+ciapra
            bne       	mainloop

exit:
            move.w      #$7fff,DMACON(a6)              ; disable all bits in DMACON
            or.w        #$8200,(DMACONSave)            ; Bit mask inversion for activation
            move.w      (DMACONSave),DMACON(a6)        ; Restore values
            move.l      (CopperSave),COP1LC(a6)        ; Restore values
            or          #$c000,(INTENARSave)
            move        (INTENARSave),INTENA(a6)       ; interrupts reactivation
            movem.l     (sp)+,d0-a6
            moveq.l     #0,d0                          ; Return code 0 tells the OS we exited with errors.
            rts                                        ; End

;-------------------------
; Wait for a scanline
; d0 - the scanline to wait for
; trashes d1
WaitRaster:
            move.l      CUSTOM+VPOSR,d1
            lsr.l       #1,d1
            lsr.w       #7,d1
            cmp.w       d0,d1
            bne.s       WaitRaster                     ;wait until it matches (eq)
            rts

******************************************************************
gfxname:
              GRAFNAME                                   ; inserts the graphics library name

              EVEN

DMACONSave:   dc.w        1
CopperSave:   dc.l        1
INTENARSave:  dc.w        1


			EVEN

; This is the copper list.
myCopperList:
    dc.w	$1fc,$0				; slow fetch for AGA compatibility
    dc.w	BPLCON0,$0200			; wait for screen start

; setup the screen so we can have our 320x256 bitplane
	dc.w	DIWSTRT,$2c81
	dc.w	DIWSTOP,$2cc1
	dc.w	DDFSTRT,$38
	dc.w	DDFSTOP,$d0
	dc.w	BPL1MOD,$0
	dc.w	BPL2MOD,$0

copBp1P:
	dc.w	BPL1PTH,0			; high word of bitplane1
	dc.w	BPL1PTL,0			; low word of bitplane1
copBp2P:
	dc.w	BPL2PTH,0			; high word of bitplane2
	dc.w	BPL2PTL,0			; low word of bitplane2
copBp3P:
	dc.w	BPL3PTH,0			; high word of bitplane3
	dc.w	BPL3PTL,0			; low word of bitplane3
	dc.w	BPLCON0,$3200		; turn on bitplanes 1, 2, and 3

    dc.w	COLOR01,$fff		; color01 is reserved for text (not implemented yet)		
copColours
    dc.w	COLOR00,$00f		; the colours we are going to cycle
    dc.w	COLOR02,$00d			
    dc.w	COLOR03,$00b		
    dc.w	COLOR04,$009		
    dc.w	COLOR05,$006		
    dc.w	COLOR06,$003		
    dc.w	COLOR07,$0		


.copperEnd:
    dc.w	$d707,COPPER_HALT
    dc.w	COLOR00,$000

    dc.l	COPPER_HALT					; impossible position, so Copper halts.
