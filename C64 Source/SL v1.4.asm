//-----------------------------------------------------------------------
//	SPARKLE V1.4
//	Inspired by Lft's Spindle and Krill's Loader
//	C64 Code
//	Tested on 1541-II, 1571, 1541 Ultimate-II+, and THCM's SX-64
//-----------------------------------------------------------------------
//	Memory Layout
//
//	0180	021b	Loader
//	01d6	01dc	BitTab
//	01e0	01f0	IRQ Installer
//	021b	02e0	Depacker
//	02e1	02fb	Fallback IRQ
//	0300	03ff	Buffer
//
//-----------------------------------------------------------------------
//
//	Loader Call:		jsr $0180	Parameterless
//	IRQ Installer:		jsr $01e0	X/A = Subroutine Vector Lo/Hi
//					jsr $01e6	Without changing Subroutine Vector
//	Fallback IRQ:		    $02e1
//
//-----------------------------------------------------------------------

//Constants:
.const	Sp		=<$ff+$52	//#$51 - Spartan Stepping constant
.const	InvSp		=Sp^$ff	//#$ae

.const	ZP		=$02		//$02/$03
.const	Bits		=$04

.const	busy		=$f8		//DO NOT CHANGE IT TO #$FF!!!
.const	ready		=$08		//AO=1, CO=0, DO=0 on C64
.const	drivebusy	=$12		//AA=1, CO=0, DO=1 on Drive

.const	Buffer	=$0300

.const	Listen	=$ed0c
.const	ListenSA	=$edb9
.const	Unlisten	=$edfe
.const	SetFLP	=$fe00
.const	SetFN		=$fdf9
.const	Open		=$ffc0

*=$0801	"Basic"		//Prg starts @ $0820, this gives the user
BasicUpstart(Start) 		//plenty of space to modify the basic start line

*=$0810	"Installer"

Start:	lda	#$ff		//Check IEC bus for multiple drives
		sta	DriveCt+1
		ldx	#$04
		lda	#$08
		sta	$ba

DriveLoop:	lda	#$00		//Clear Error Status
		sta	$90
		lda	$ba
		jsr	Listen
		lda	#$6f
		jsr	ListenSA
		lda	$90		//No error: $00, Error: $80
		bmi	SkipWarn	//check next drive # if not present

		lda	$ba		//Drive present
		sta	DriveNo+1	//This will be the active drive if there is only one drive on the bus
		jsr	Unlisten
		inc	DriveCt+1
		beq	SkipWarn	//Skip warning if only one drive present

		lda	$d018		//More than one drive present, show warning
		bmi	Start		//Warning is already on, start bus check again

		lda	#$3c		//Clear screen RAM
		sta	$0288
		jsr	$e544

		ldx	#<WEnd-Warning-1
TxtLoop:	lda	Warning,x	//Copy warning
		sta	$3db9,x
		dex
		bpl	TxtLoop

		lda	#$f5		//Screen RAM: $3c00
		sta	$d018
		bmi	Start		//Warning turned on, start bus check again

SkipWarn:	inc	$ba
		dex
		bne	DriveLoop

		//Here, DriveCt can only be $ff or $00

		lda	#$15		//Restore Screen RAM to $0400
		sta	$d018
		lda	#$04
		sta	$0288

DriveCt:	lda	#$00
		beq	ChkDone	//One drive only, continue

		ldx	#<NDWEnd-NDW-1
NDLoop:	lda	NDW,x		//No drive, show message and finish
		jsr	$ffd2
		dex
		bpl	NDLoop
		rts

//----------------------------

ChkDone:	ldx	#<Cmd
		ldy	#>Cmd
		lda	#CmdEnd-Cmd
		jsr	SetFN		//Filename = drive install code in command buffer

		lda	#$0f
		tay
DriveNo:	ldx	#$00
		jsr	SetFLP	//Logical parameters
		jsr	Open		//Open vector

		sei
		lda	#$3c		// 0  0  1  1  1  1  0  0
		sta	$dd02		//DI|CI|DO|CO|AO|RS|VC|VC
		ldx	#$00		//Clear the lines
		stx	$dd00

		lda	#$35
		sta	$01

LCopyLoop:	lda	LoaderCode,x
		sta	$0180,x
		lda	LoaderCode+$80,x
		sta	$0200,x
		lda	LoaderCode+$100,x
		sta	$0280,x
		inx
		bpl	LCopyLoop
		
		ldx	#$7f
		txs			//Loader starts @ $180, so reduce stack to $100-$17f

		lda	#<NMI		//Install NMI vector
		sta	$fffa
		lda	#>NMI
		sta	$fffb

		lda	#busy		//=#$f8
		bit	$dd00		//Wait for "drive busy" signal	
		bmi	*-3
		sta	$dd00		//lock bus

		//First loader call

		lda	#>$10ad	//#>PrgStart-1	(Hi Byte)
		pha
		lda	#<$10ad	//#<PrgStart-1	(Lo Byte)
		pha
		jmp	Load		//Load first Bundle, it may overwrite installer, so we use an alternative approach here

//-----------------------------------------------------------------------------------

Warning:
     //0123456789012345678901234567890123456789
.text	 "sparkle supports only one active drive "
.text	"pls turn everything else off on the bus!"
WEnd:
NDW:
.byte	$4e,$49,$41,$47,$41,$20,$44,$41,$4f,$4c,$20,$44
.byte	$4e,$41,$20,$4e,$4f,$20,$45,$56,$49,$52,$44,$20,$52,$55,$4f,$59
.byte	$20,$4e,$52,$55,$54,$20,$45,$53,$41,$45,$4c,$50
NDWEnd:

//-----------------------------------------------------------------------------------

Cmd:
//Load all 5 drive code blocks into buffers 0-4 at $300-$7ff on drive in one command!

.byte	'M','-','E',$05,$02	//-0204

		ldx	#$08		//-0206
		lda	#$12		//-0208	Sector
		tay			//-0209	Track
		sec			//-020a	Set Track and Sector number for buffers 04..00
		sty	$06,x		//-020c	Track = 18
		sta	$07,x		//-020e	Sectors 18,14,10,06,02
		sbc	#$04		//-0210	Interleave=4
		dex			//-0211
		dex			//-0212
		bpl	*-8		//-0214
		lda	#$04		//-0216	Load 5 blocks to buffers 04,03..00
		sta	$f9		//-0218	Buffer Pointer
		jsr	$d586		//-021b	Read Block into Buffer in Buffer Pointer 
		dec	$f9		//-021d	Decrease Buffer Pointer
		bpl	*-5		//-021f
					//		Maximize buffer utilization by preparing registers for Drive Code
		sei			//-0220
		lda	#$7a		//-0222	Set these $1800 bits to OUT
		ldy	#drivebusy	//-0224	CO=0, DO=1, AA=1
		jmp	$0300		//-0227	Execute Drive Code, X=#$00 after loading all 5 blocks (last buffer No=0) 
CmdEnd:

//----------------------------
//	C64 RESIDENT CODE
//	$0180-$02fb
//----------------------------

LoaderCode:

*=LoaderCode	"Loader"

.pseudopc $0180	{

Load:		lda	#$00
LastX:	ldx	#$00
		bne	StoreBits	//If LastX<>#$00, depack new Bundle from buffer, otherwise, load next block
RcvBlock:	lda	#$35		//ROM=off, I/O=on
		sta	$01
		ldy	#ready	//Y=#$08, X=#$00
		sty	$dd00		//Clear CO and DO to signal Ready-To-Receive
		bit	$dd00		//Wait for Ready-To-Send from Drive
		bvs	*-3		//$dd00=#$4x - drive is busy, $0x - drive is ready	00,01
		stx	$dd00		//Release ATN, V=0 - will use it in loop below		02-05
		dex			//Prepare X=#$ff for transfer					06,07
		jsr	Wait12	//Waste a few more cycles... (drive needs 16 cycles)	08-19

//-------------------------------------
//	    72-BYCLE RECEIVE LOOP
//		 Saves 15 bytes
//  Adds 2x10 cycles to the load time
//		  of one block
// (no detectable difference in speed)
//-------------------------------------

RcvLoop:
Read1:	lda	$dd00		//4		W1-W2 = 18 cycles on drive			20-23
		sty	$dd00		//4	8	Y=#$08 -> ATN=1
		lsr			//2	10
		lsr			//2	12
		inx			//2	14
		nop			//2	16
		ldy	#$00		//2	(18)

Read2:	ora	$dd00		//4		W2-W3 = 16 cycles
		sty	$dd00		//4	8	Y=#$00 -> ATN=0
		lsr			//2	10
		lsr			//2	12
SpComp:	cpx	#Sp		//2	14	Will be changed to #$ff in Spartan Step Delay
		beq	ChgJmp	//2/3	16/17 whith branch -----------|
		ldy	#$08		//2	(18/28)	ATN=1			|
					//						|
Read3:	ora	$dd00		//4		W3-W4 = 17 cycles		|
		sty	$dd00		//4	8	Y=#$08 -> ATN=1		|
		lsr			//2	10					|
		lsr			//2	12					|
		sta	LastBits+1	//4	16					|
		lda	#$c0		//2	(18)					|
					//						|
Read4:	and	$dd00		//4		W4-W1 = 16 cycles		|
		sta	$dd00		//4	8	A=#$X0 -> ATN=0		|
LastBits:	ora	#$00		//2	10					|
		sta	Buffer,x	//5	15					|
JmpRcv:	bvc	RcvLoop	//3	(18)					|
					//						|
//----------------------------						|
					//						|
ChgJmp:	ldy	#<SpSDelay-<ChgJmp	//2	19	<-----------|
		sty	JmpRcv+1			//4	23
		bne	Read3-2			//3	26	Branch always

//----------------------------
//		BITTAB
//----------------------------

//Literal Length BitTab values (tab entries 4/6/7) are corrected 
//so that the offset is always #$6d (= default offset of tab entry 7)

BitTab:		//$01d4							BitTab:		A after rol:
.byte	%10000001	//1 - Read 2nd bit					10000001	->	0000001x		go to 2/3

.byte	%00000000	//2 - Literal, no more bits (returns 1)		00000000	->	N/A			total: 2 bits
.byte	%10000010	//3 - Read 3rd bit					10000010	->	0000010x		go to 4/5 

.byte	%01100101	//4 - Literal - 4-5th bits (returns 2-5)		01100101	->	100101xx		total: 5 bits
.byte	%10000011	//5 - Read 4th bit					10000011	->	0000011x		go to 6/7

.byte	%00110011	//6 - Literal - 5-7th bits (returns 6-13)		00110011	->	10011xxx		total: 7 bits
.byte	%00001101	//7 - Literal - 5-9th bits (returns 14-45)	00001101	->	101xxxxx		total: 9 bits

.text	"OMG"

//----------------------------
//		IRQ INSTALLER
//		Call:	jsr $01e0
//		X/A=Player Lo/Hi
//----------------------------

InstallIRQ:	stx	IRQSub+1	//Installs a subroutine vector
		sta	IRQSub+2
		lda	#<IRQ		//Installs Fallback IRQ vector
		sta	$fffe
		lda	#>IRQ
		sta	$ffff
Wait12:		
Done:		rts

//----------------------------

StoreBits:	sta	Bits

//----------------------------
//		LONG MATCH
//----------------------------

LongMatch:	clc			//C=0 NEEDED HERE for both branches!!! ALSO NEEDED FOR NEXT BUNDLE JUMP IF LastX<>#$00
		bne	NextFile	//A=#$3f - Next File in block (#$fc) - Also used as a trampoline for LastX jump (both need C=0)
		dex			//A=#$3e - Long Match (#$f8), read next byte for Match Length (#$3e-#$fe)
		lda	Buffer,x	//If A=#$00 then this Bundle is done, rest of the data in buffer is the beginning of the next Bundle
		bne	MidConv	//Otherwise, converge with mid match (A=#$3e-#$fe here if branch taken)

//----------------------------
//		END OF BUNDLE
//----------------------------

		stx	LastX+1	//Save last X position in buffer for next Bundle depacking
		lda	Bits		//Store Bits for next Bundle in block
		sta	Load+1
		lda	#$35		//ROM=off, I/O=on
		sta	$01
		rts			//Bundle finished

//----------------------------
//		SPARTAN STEP DELAY
//----------------------------

SpSDelay:	lda	#<RcvLoop-<ChgJmp	//2	20	Restore Receive loop
		sta	JmpRcv+1		//4	24
		txa				//2	26
		eor	#InvSp		//2	28	Invert byte counter
		sta	SpComp+1		//4	32	SpComp+1=(#$51 <-> #$ff)
		bmi	RcvLoop		//3	(35) (Drive loop takes 33 cycles)

//----------------------------------

		lda	#busy		//=#$f8
		sta	$dd00		//Bus lock

//------------------------------------------------------------
//		BLOCK STRUCTURE FOR DEPACKER
//------------------------------------------------------------
//		$01	  - #$00 (end of block) (vs. block count on drive side)
//		$00	  - First Bitstream byte
//		$ff	  - Dest Address Lo
//		($fe	  - IO Flag)
//		$fe/$fd - Dest Address Hi
//		$fd/$fc - Bytestream backwards with Bitstream interleaved (unpacked blocks are forward)
//------------------------------------------------------------

Depack:	ldx	#$00		
		lda	Buffer,x	//First bitstream value
		sec			//Token Bit, this keeps bitstream buffer<>#$00 until all 8 bits read
		rol			//Move Compression Bit to C here
		sta	Bits		//Store rest on ZP for faster processing
					//Only blocks occupied by a single file can be uncompressed

NextFile:	dex			//Entry point for next file in block, C must be 0 here for subsequent files	
		lda	Buffer,x	//Lo Byte of Dest Address
		sta	ZP

		ldy	#$35		//Default value for $01, I/O=on
		dex
		lda	Buffer,x	//Hi Byte vs IO Flag=#$00
		bne	SkipIO
		dey			//Y=#$34, turn I/O off
		dex
		lda	Buffer,x	//This version can also load to zeropage!!!

SkipIO:	sta	ZP+1		//Hi Byte of Dest Address
		sty	$01		//Update $01
		dex

		lda	#%10000001	//Prepare value for first BitCheck		
		bcc	BitCheck	//Evaluate Compression Bit in C here

//----------------------------
//		UNPACKED
//----------------------------

		txa			//Uncompressed block is stored forward, not reversed
		tay			//I.e. address bytes point at beginning of uncompressed block[-1], not at end

UnPkdLoop:	lda	Buffer,y
		sta	(ZP),y	//(ZP)=Address-1
		dey			//Y=Max->#$01, #$00 not included
		bne	UnPkdLoop

//----------------------------
//		END OF BLOCK
//----------------------------

NextBlock:	ldx	#$00		//X=$00 needed to load next block
		jmp	RcvBlock

//----------------------------
//		MID MATCH
//----------------------------

MidMatch:	lda	Buffer,x	//C=0
		beq	NextBlock	//Match byte=#$00 -> end of block, load next block
		lsr
		lsr
		cmp	#$3e		//= (Long Match Tag/4)
		bcs	LongMatch	//Long Match/EOF (C=1) vs. Mid Match (C=0)

MidConv:	tay			//Match Length=#$01-#$3d (mid) vs. #$3e-#$fe (long)
		eor	#$ff
		adc	ZP		//C=0 here
		sta	ZP

		dex
		lda	Buffer,x	//Match Offset=$00-$ff+(C=1)=$01-$100

		bcs	ShortConv+1	//Converge with short match skipping SEC instruction
		dec	ZP+1
		bcc	ShortConv	//Converge with short match

//----------------------------
//		LONG LITERALS
//----------------------------

LongLit:	lda	Buffer,x	//Literal lengths 45-250
		dex
		bcs	StoreLit	//Skip adding offset here

//----------------------------
//		BITCHECK
//----------------------------

NextByte:	ldy	Buffer,x
		sty	Bits
		dex
BitCheck:	rol	Bits
		beq	NextByte	//If Bits=#$00 then token bit is in C, fetch next bitstream byte from buffer

		rol
		bcc	BitCheck
		beq	Match		//A=#$00, C=1 (BEQ before BMI because there are 40-100% more match sequences than literals)
		bmi	Literal	//A>=#$80, C=1

		clc
		tay			//Y=%10-%11, or %100-%111 here  
		lda	BitTab-1,y
		bne	BitCheck	//If A=#$00 - this is LitLen=#$01, otherwise go to BitCheck

//----------------------------
//		LITERALS
//----------------------------

		lda	#$93		//Literal length 1: #$93+#$6e+(C=0)=#$01 and C=1 after this addition
		bcc	AddOffset

Literal:	cmp	#$bf		//Literal lengths 2-44
		bcs	LongLit

AddOffset:	adc	#$6e		//Offset is the same for all 4 LitLen here
StoreLit:	sta	SubX+1	//Literal length, C=1 here ALWAYS
		tay
		eor	#$ff		//ZP=ZP+(A^#$FF)+(C=1) = ZP=ZP-A (e.g. A=#$0e -> ZP=ZP-0e)
		adc	ZP
		sta	ZP
		bcs	*+4
		dec	ZP+1

		txa
SubX:		axs	#$00		//X=X-1-Literal (e.g. Lit=#$00 ->	X=A-1-0)
		stx	LitCopy+1

LitCopy:	lda	Buffer,y
		sta	(ZP),y
		dey
		bne	LitCopy	//Literal sequence is ALWAYS followed by a match sequence

//----------------------------
//		SHORT MATCH
//----------------------------

Match:	lda	Buffer,x	//C=1 from BitCheck, C=0 from Literals
		anc	#$03		//Also clears C=0, needed after BitCheck
		beq	MidMatch	//C=0

ShortMatch:	tay			//Short Match Length=#$01-#$03
		eor	#$ff
		adc	ZP
		sta	ZP
		bcs	*+4
		dec	ZP+1

		lda	Buffer,x	//Short Match Offset=($00-$3f)+1=$01-$40
		lsr
		lsr
ShortConv:	sec
		adc	ZP
		sta	MatchCopy+1	//MatchCopy+1=ZP+(Buffer)+(C=1)
		lda	ZP+1
		adc	#$00
		sta	MatchCopy+2	//C=0 after this
		iny			//Y+=1 for bne to work
MatchCopy:	lda	$10ad,y	//Y=#$02-#$04 (short) vs #$02-#$3e (mid) vs #$3f-#$ff (long)
		sta	(ZP),y	//Y=#$00 is never used here - it is used as the End of Stream flag 
		dey
		bne	MatchCopy

		dex

		lda	#%10000000	//Read 1 bit (match vs literal sequence)
		bcc	BitCheck	//Branch ALWAYS

//----------------------------
//		FALLBACK IRQ
//----------------------------

IRQ:		pha			//$02de
		txa
		pha
		tya
		pha
		lda	$01
		pha
		lda	#$35
		sta	$01
IRQSub:	jsr	Done		//Music player or IRQ subroutine, installer @ $01e0
		inc	$d019
		pla
		sta	$01
		pla
		tay
		pla
		tax
		pla
NMI:		rti

//----------------------------
EndLoader:
}