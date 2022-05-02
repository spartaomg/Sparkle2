//TAB=8
//----------------------------------------------------------------------
//	SPARKLE
//	Inspired by Lft, Bitbreaker, and Krill
//	C64 Code
//	Tested on 1541, 1541-II, 1571, the 1541 Ultimate series, and Oceanic drvies
//----------------------------------------------------------------------
//	Version history
//
//	v12	- separate checksum verification loop in drive code
//
//	v13	- checksum verification integrated in transfer loop in drive code
//
//	v14	- new, tighter receive loop, tabs eliminated
//
//	v15	- loads all 3 drive code blocks in one command
//		  needs 3 blocks (stack, code, buffer)
//
//	v16	- LZ compression/decompression
//		- new memory layout
//		  loader code		0100-017f
//		  reset/base irq	0200-023f
//		  decompression		023f-02ff
//		  buffer		0300-03ff
//
//	v17	- LZ+RLE compression/decompression
//		- checksum verification during motor spin up
//
//	v18	- new 126-cycle GCR decoding loop (Sparkle 1)
//
//	v19	- drive reset detection
//
//	v20	- tighter drive transfer loop
//
//	v21	- 4 blocks loaded with code in command buffer
//
//	v22	- improved, 125-cycle GCR decoding loop (Sparkle 1)
//
//	v23	- new code in command buffer, loads 5 blocks in one command
//
//	v24	- introducing Spartan Stepping
//	
//	v25	- new LZ compression/decompression
//		  handles match lengths up to 255 bytes
//		  handles uncompressed blocks as well
//		  handles multiple files in one block
//		- updated Spartan Step code
//		- alternative 72-cycle receive loop
//		  saves 15 bytes but adds 20 cycles to the load time of one block 
//		  no detectable difference in loading speed
//		- new memory layout, takes 0180-03ff ($280 bytes) in 1 block
//		  stack		0100-0180 (0100-0180)
//		  loader code	0180-01ef (0180-01e0 with alternative receive loop)
//		  decompression	01ef-02d9 (01e0-02ca)
//		  reset		02d9-02e5 (02ca-02d6)
//		  base irq		02e5-02ff (02d6-02f0)
//		  buffer		0300-03ff
//		- improved drive reset detection
//
//	v26	- most compact and feature-packed version (5 bytes left free!!!)
//		  same memory footprint ($180-$3ff)
//		  uses the alternative short receive loop
//		- both drive and C64 reset handled
//		  loader returns Z=1 if load is complete, Z=0 if drive has been reset
//		- bus lock - user can write anything to $dd02 between loader calls
//		- added Base IRQ music player install code
//		- functions:
//		  Loader Call:		jsr $0180
//		  IRQ Installer:	jsr $01d0	X/A = Player Vector Lo/Hi
//		  Alt Loader Call:	jmp $01f0	X/A = (Return Address-1) Lo/Hi
//		  Fallback IRQ:		    $02e2
//
//	v27	- back-to-back LZ compression: no half-blocks left unused
//		  the last block of a Bundle also contains the beginning of the next Bundle
//		  buffer needs to be left untouched between loader calls
//		  saves 10 blocks on the standard test disk
//		  results in speed improvements across all CPU loads
//		- updated drive reset detection
//		  loader returns with Z=0 if job is complete or Z=1 if drive has been reset
//		- now supports loading to zero page
//		- alternative loader call removed
//		- simplified uncompressed file copy
//		  only last block on disk is partial, so unpacked block length detection has been removed 
//		- functions:
//		  Loader Call:		jsr $0180
//		  IRQ Installer:	jsr $02d0	X/A = Subroutine Vector Lo/Hi
//		  Fallback IRQ:		    $02e1
//
//	v28	- new communication code with bus lock feature 
//		  inverts ATN check to allow bus lock
//		  no drive reset detection currently
//		- code rearranged:
//		  Loader Call:		jsr $0180
//		  IRQ Installer:	jsr $01e0	X/A = Subroutine Vector Lo/Hi
//					jsr $01e6	without changing subroutine vector
//		  Fallback IRQ:		    $02de
//		- final, v1.0 release code!
//
//	v29	- bug fix
//		  IO was not turned back on after a file was loaded under IO - fixed
//		  Fallback IRQ:		$02e1
//		- load start optimized
//		  saved 4 bytes and a few cycles
//		  X and Y swapped in transfer loop
//
//	v30	- depacker optimization
//		  saves approx 10000 cycles on the load of a full disk side
//		- Fallback IRQ:		$02dd
//
//	v31	- depacker optimization
//		  new block structure
//		  bit check on ZP saving approx 80000 cycles on the load time of a full disk side
//		  new long literal sequence handling, may save a few bytes on compression, faster depacking
//		- warning if more than one active drive is on the bus
//		  also warns if drive is turned off before demo started
//		- Fallback IRQ:		$02e1
//		- released with Sparkle V1.4
//
//	v32	- new depacker
//		  simplified bitstream for much faster literal sequence processing
//		  bittab eliminated
//		  compression is about 0.3%-0.5% less effective
//		  decompression is about 20% faster
//		  saves approximately 2700 cycles on the decompression of a single block (1792800 cycles per disk side)
//		  uses same block structure
//		- IRQ Installer:	jsr $01d5	X/A = Subroutine Vector Lo/Hi
//					jsr $01db	without changing subroutine vector
//		- FallBack IRQ:		    $02e5
//		- jsr $e544 eliminated in installer (does not work properly on machines with old Kernal ROM versions)
//		- released with Sparkle V1.5
//
//	v33	- major update with random file access
//		  new memory layout: $0160 - $03ff
//		  Send Command:		$0160
//		  LoadA			$0184
//		  Load Fetched:		$0187
//		  Load Next:		$01fc
//		  IRQ Installer:	$02d2	Y/X = subroutine vector Lo/Hi, A = $d012
//		  Fallback IRQ:	$02e6
//		- IRQ installer also sets $d012
//		- separate SendCmd function to allow drive reset
//		- released with Sparkle 2
//
//--------------------------------------------------------------

.const	DriveNo		=$fb
.const	DriveCt		=$fc

.const	Sp		=<$ff+$52	//#$51 - Spartan Stepping constant
.const	InvSp		=Sp^$ff		//#$ae

.const	ZP		=$02		//$02/$03
.const	Bits		=$04

.const	busy		=$f8		//DO NOT CHANGE IT TO #$FF!!!
.const	ready		=$08		//AO=1, CO=0, DO=0 on C64 -> $1800=#90
.const	sendbyte	=$18		//AO-1, CO=1, DO=0 on C64 -> $1800=$94
.const	drivebusy	=$12		//AA=1, CO=0, DO=1 on Drive

.const	Buffer		=$0300

.const	Listen		=$ed0c
.const	ListenSA	=$edb9
.const	Unlisten	=$edfe
.const	SetFLP		=$fe00
.const	SetFN		=$fdf9
.const	Open		=$ffc0

.const	LDA_ABSY	=$b9
.const	ORA_ABSY	=$19
.const	AND_ABSY	=$39
.const	NTSC_CLRATN	=$c0
.const	NTSC_DD00_1	=$dd00-ready
.const	NTSC_DD00_2	=$dd00-NTSC_CLRATN

//C64
//Write	 0  0  X  X  X  0  0  0
//Read	 X  X  0  0  0  1  X  X
//dd00	80 40 20 10 08 04 02 01		Value after C64 reset:   #$97 = 10010111 (DI=1 CI=0 DO=0 CO=1 AO=0)
//	DI|CI|DO|CO|AO|RS|VICII		Value after drive reset: #$c3	= 11000011 (DI=1 CI=1 DO=0 CO=0 AO=0)

//Drive
//1800	80 40 20 10 08 04 02 01		Value after C64 reset:   #$04 = 00000100 (D0=0 CO=0 DI=0 CI=1 AI=0 AA=0)
//	AI|DN|DN|AA|CO|CI|DO|DI		Value after drive reset: #$00 = 00000000 (D0=0 CO=0 DI=0 CI=0 AI=0 AA=0)

*=$0801	"Basic"				//Prg starts @ $0810
BasicUpstart(Start)

*=$0810	"Installer"

Start:		lda	#$ff		//Check IEC bus for multiple drives
		sta	DriveCt
		ldx	#$04
		lda	#$08
		sta	$ba

DriveLoop:	lda	$ba
		jsr	Listen
		lda	#$6f
		jsr	ListenSA	//Return value of A=#$17 (drive present) vs #$c7 (drive not present)
		bmi	SkipWarn	//check next drive # if not present

		lda	$ba		//Drive present
		sta	DriveNo		//This will be the active drive if there is only one drive on the bus
		jsr	Unlisten
		inc	DriveCt
		beq	SkipWarn	//Skip warning if only one drive present

		lda	$d018		//More than one drive present, show warning
		bmi	Start		//Warning is already on, start bus check again

		ldy	#$03
		ldx	#$00
		lda	#$20
ClrScrn:	sta	$3c00,x		//Clear screen RAM @ $3c00
		inx			//JSR $e544 does not work properly on old Kernal ROM versions
		bne	ClrScrn
		inc	ClrScrn+2
		dey
		bpl	ClrScrn

		ldx	#<WEnd-Warning-1
TxtLoop:	lda	Warning,x	//Copy warning
		sta	$3db9,x
		lda	$286		//Foreground color
		sta	$d9b9,x		//Needed for old Kernal ROMs
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

		lda	DriveCt
		beq	ChkDone		//One drive only, continue

		ldx	#<NDWEnd-NDW
NDLoop:		lda	NDW-1,x		//No drive, show message and finish
		jsr	$ffd2
		dex
		bne	NDLoop
		stx	$0801		//Delete basic line to force reload
		stx	$0802
		rts

//----------------------------

ChkDone:	ldx	#<Cmd
		ldy	#>Cmd
		lda	#CmdEnd-Cmd
		jsr	SetFN		//Filename = drive install code in command buffer

		lda	#$0f
		tay
		ldx	DriveNo
		jsr	SetFLP		//Logical parameters
		jsr	Open		//Open vector

		sei

		lda	#$35
		sta	$01

		ldx	#$5f
		txs			//Loader starts @ $160, so reduce stack to $100-$15f

		lda	#$3c		// 0  0  1  1  1  1  0  0
		sta	$dd02		//DI|CI|DO|CO|AO|RS|VC|VC
		ldx	#$00		//Clear the lines
		stx	$dd00

LCopyLoop:	lda	LoaderCode,x
		sta	$0160,x
		lda	LoaderCode+$a0,x
		sta	$0200,x
		inx
		bne	LCopyLoop

//----------------------------------
//		NTSC fix
//----------------------------------
		
NextLine:	lda	$d012		//Based on J0x's solution for NTSC detection from CodeBase64.org
SameLine:	cmp	$d012
		beq	SameLine
		bmi	NextLine
		cmp	#$20
		bcs	SkipNTSC

		lda	#<NTSC_DD00_2
		sta	Read2+1
		lda	#>NTSC_DD00_1	//=NTSC_DD00_2
		sta	Read2+2
		ldx	#$02
NTSCLoop:	sta	Read1,x
		sta	Read3,x
		sta	Read4,x
		lda	#<NTSC_DD00_1
		dex
		bne	NTSCLoop
		lda	#LDA_ABSY
		sta	Read1
		lda	#ORA_ABSY
		sta	Read2
		sta	Read3
		lda	#AND_ABSY
		sta	Read4

SkipNTSC:
//----------------------------------

		lda	#<Sparkle_IRQ_RTI	//Install NMI vector
		sta	$fffa
		lda	#>Sparkle_IRQ_RTI
		sta	$fffb

		lda	#busy			//=#$f8
		bit	$dd00			//Wait for "drive busy" signal (DI=0 CI=1 dd00=#$4b)
		bmi	*-3
		sta	$dd00			//lock bus

		//First loader call, returns with I=1

		lda	#>$10ad			//#>PrgStart-1	(Hi Byte)
		pha
		lda	#<$10ad			//#<PrgStart-1	(Lo Byte)
		pha
		jmp	Sparkle_LoadFetched	//Load first Bundle

//-----------------------------------------------------------------------------------

Warning:
       //0123456789012345678901234567890123456789
.text	 "sparkle supports only one active drive "
.text	"pls turn everything else off on the bus!"
WEnd:
NDW:
      //0123456789012345678901234567890123456789
//.text	"please turn your drive on and load again"
.byte	$4e,$49,$41,$47,$41,$20,$44,$41,$4f,$4c,$20,$44
.byte	$4e,$41,$20,$4e,$4f,$20,$45,$56,$49,$52,$44,$20,$52,$55,$4f,$59
.byte	$20,$4e,$52,$55,$54,$20,$45,$53,$41,$45,$4c,$50
//.text	"niaga daol dna no evird ruoy nrut esaelp"
NDWEnd:

//-----------------------------------------------------------------------------------

Cmd:
//Load all 5 drive code blocks into buffers 0-4 at $300-$7ff on drive in one command!

.byte	'M','-','E',$05,$02		//-0204	Command buffer: $0200-$0228

		ldx	#$08		//-0206
		lda	#$12		//-0208	Track 18
		ldy	#$0f		//-020a	Sectors 15,14,13,12,11
		sta	$06,x		//-020c
		sty	$07,x		//-020e
		dey			//-020f
		dex			//-0210
		dex			//-0211
		bpl	*-7		//-0213
		lda	#$04		//-0215	Load 5 blocks to buffers 04,03..00
		sta	$f9		//-0217	Buffer Pointer
		jsr	$d586		//-021a	Read Block into Buffer in Buffer Pointer 
		dec	$f9		//-021c	Decrease Buffer Pointer
		bpl	*-5		//-021e
		jmp	$0700		//-0221	Execute Drive Code, X=#$00 after loading all 5 blocks (last buffer No=0) 
					//	7 bytes free here
CmdEnd:

//------------------------------
//	C64 RESIDENT CODE
//	$0160-$02ff
//------------------------------

LoaderCode:

*=LoaderCode	"Loader"

.pseudopc $0160	{

Sparkle_SendCmd:
		sta	Bits		//Store Bundle Number on ZP
		jsr	Set01		//$dd00=#$3b, $1800=#$95, A=#$35
SS_Send:	ldx	#sendbyte	//CO=1, AO=1 => C64 is ready to send a byte, X=#$18
		stx	$dd00		//Signal to Drive that we want to send Bundle Index
		bit	$dd00		//$dd00=#$9b, $1800=#$94
		bmi	*-3		//Wait for Drive response ($1800->00 => $dd00=#$1b, $1800=#$85)

		anc	#$31		//Drive is ready to receive byte, A=#$31, C=0 - NOT NEEDED!!!

					//Sending bits via AO, flipping CO to signal new bit
BitSLoop:	adc	#$e7		//2	A=#$31+#$e7=#$18 and C=1 after addition in first pass, C=0 in all other passes
		sax	$dd00		//4	subsequent passes: A&X=#$00/#$08/#$10/#$18 and C=0
		and	#$10		//2	Clear AO
		eor	#$10		//2	A=#$18 in first pass (CO=1, AO=1) reads #$85 on $1800 - no change, first pass falls through
		ror	Bits		//5	C=1 in first pass, C=0 in all other passes before ROR
		bne	BitSLoop	//3
					//18 cycles/bit - drive loop needs 17 cycles/bit (should work for both PAL and NTSC)

BusLock:	lda	#busy		//2	(A=#$f8) worst case, last bit is read by the drive on the first cycle of LDA
		sta	$dd00		//4	Bus lock

		rts			//6

Sparkle_LoadA:
		jsr	Sparkle_SendCmd
Sparkle_LoadFetched:
		jsr	Set01		//17
		ldx	#$00		//2
		ldy	#ready		//2	Y=#$08, X=#$00
		sty	$dd00		//4	Clear CO and DO to signal Ready-To-Receive
		bit	$dd00		//Wait for Drive
		bvs	*-3		//$dd00=#$cx - drive is busy, $0x - drive is ready	00,01	(BMI would also work)
		stx	$dd00		//Release ATN						02-05
		dex			//							06,07
		jsr	Set01		//Waste a few cycles... (drive takes 16 cycles)		08-24 minimum needed here is 8 cycles

//--------------------------------------
//
//		RECEIVE LOOP
//
//--------------------------------------

RcvLoop:
Read1:		lda	$dd00		//4		W1-W2 = 18 cycles			25-28
		sty	$dd00		//4	8	Y=#$08 -> ATN=1
		lsr			//2	10
		lsr			//2	12
		inx			//2	14
		nop			//2	16
		ldy	#$c0		//2	(18)

Read2:		ora	$dd00		//4		W2-W3 = 16 cycles
		sty	$dd00		//4	8	Y=#$C0 -> ATN=0
		lsr			//2	10
		lsr			//2	12
SpComp:		cpx	#Sp		//2	14	Will be changed to #$ff in Spartan Step Delay
		beq	ChgJmp		//2/3	16/17 with branch --------------|
		ldy	#$08		//2	(18/28)	ATN=1			|
					//					|
Read3:		ora	$dd00		//4		W3-W4 = 17 cycles	|
		sty	$dd00		//4	8	Y=#$08 -> ATN=1		|
		lsr			//2	10				|
		lsr			//2	12				| C=1 here
		sta	LastBits+1	//4	16				|
		lda	#$c0		//2	(18)				|
					//					|
Read4:		and	$dd00		//4		W4-W1 = 16 cycles	|
		sta	$dd00		//4	8	A=#$X0 -> ATN=0		|
LastBits:	ora	#$00		//2	10				|
		sta	Buffer,x	//5	15				|
JmpRcv:		bvc	RcvLoop		//3	(18)				|
					//					|
//------------------------------						|
					//					|
ChgJmp:		ldy	#<SpSDelay-<ChgJmp	//2	19	<---------------|
		sty	JmpRcv+1	//4	23
		bne	Read3-2		//3	26	Branch always

//------------------------------
//		LONG MATCH
//------------------------------

LongMatch:	bne	NextFile	//A=#$fc - Next File in Bundle
		clc			//C=0
		dex			//A=#$f8 - Long Match, read next byte for Match Length (#$3e-#$fe)
		lda	Buffer,x	//If A=#$00 then this Bundle is done, rest of the block in buffer is the beginning of the next Bundle
		bne	MidConv		//Otherwise, converge with mid match (A=#$3e-#$fe here if branch taken)

//------------------------------
//		END OF BUNDLE
//------------------------------

		dex			//8
		stx	Buffer+$ff	//12
Set01:		lda	#$35		//14
		sta	$01		//17
Done:		rts			//23

//------------------------------
//		END OF BLOCK
//------------------------------

NextBlock:	beq	Sparkle_LoadFetched	//Trampoline

//------------------------------
//		SPARTAN STEP DELAY
//------------------------------

SpSDelay:	lda	#<RcvLoop-<ChgJmp	//2	20	Restore Receive loop
		sta	JmpRcv+1		//4	24
		txa				//2	26
		eor	#InvSp			//2	28	Invert byte counter
		sta	SpComp+1		//4	32	SpComp+1=(#$2a <-> #$ff)
		bmi	RcvLoop			//3	(35) (Drive loop takes 33 cycles)

		jsr	BusLock		//This requires $01 = #$35+

//------------------------------------------------------------
//		BLOCK STRUCTURE FOR DEPACKER
//------------------------------------------------------------
//		$00	- First Bitstream byte -> will be changed to #$00 (end of block)
//		$01	- last data byte vs #$00 (block count on drive side)
//		$ff	- Dest Address Lo
//		($fe	- IO Flag)
//		$fe/$fd	- Dest Address Hi
//		$fd/$fc	- Bytestream backwards with Bitstream interleaved
//------------------------------------------------------------

Sparkle_LoadNext:
		ldx	#$ff		//Entry point for next bundle in block
		stx	MidLitSeq+1

		inx
GetBits:	lda	Buffer,x	//First bitstream value
		bne	StoreBits
		ldx	Buffer+$ff	//=LastX
		bne	GetBits
StoreBits:	sta	Bits		//Store it on ZP for faster processing

NextFile:	dex			//Entry point for next file in block, C must be 0 here for subsequent files	
		lda	Buffer,x	//Lo Byte of Dest Address
		sta	ZP

		ldy	#$35		//Default value for $01, IO=on
		dex
		lda	Buffer,x	//Hi Byte vs IO Flag=#$00
		bne	SkipIO
		dey			//Y=#$34, turn IO off
		dex
		lda	Buffer,x	//This version can also load to zeropage!!!

SkipIO:		sta	ZP+1		//Hi Byte of Dest Address
		sty	$01		//Update $01

		dex

		ldy	#$00		//Needed for Literals
		sty	Buffer		//This will also be the EndofBlock Tag

		beq	LitCheck	//Always

//------------------------------
//		MID MATCH
//------------------------------

MidMatch:	lda	Buffer,x	//C=0
		beq	NextBlock	//Match byte=#$00 -> end of block, load next block
		cmp	#$f8		//Long Match Tag
		bcs	LongMatch	//Long Match/EOF (C=1) vs. Mid Match (C=0)
		lsr
		lsr			//Two least significant bits are always 0 here, ALR is not needed...

MidConv:	tay			//Match Length=#$01-#$3d (mid) vs. #$3e-#$fe (long)
		eor	#$ff
		adc	ZP		//C=0 here
		sta	ZP
		dex
		lda	Buffer,x	//Match Offset=$00-$ff+(C=1)=$01-$100

		bcs	ShortConvNoSec	//Skip SEC
		dec	ZP+1
		bcc	ShortConv	//Converge with short match

//------------------------------
//		LITERALS
//------------------------------

NextBit:	lda	Buffer,x	//C=1, Z=1, Bits=#$00, token bit in C, update Bits
		rol
		sta	Bits
LongLit:
		dex			//Saves 1 byte and adds 2 cycles per LongLit sequence, C=0 for LongLit
		bcs	MidLitSeq	//C=1, we have more than 1 literal, LongLit (C=0) falls through

ShortLit:	tya			//Y=00, C=0
MidLit:		iny			//Y+Lit-1, C=0
		sty	SubX+1		//Y+Lit, C=0
		eor	#$ff		//ZP=ZP+(A^#$FF)+(C=1) = ZP=ZP-A (e.g. A=#$0e -> ZP=ZP-0e)
		adc	ZP
		sta	ZP

		bcc	ShortLitHi	//This saves 1 cycle per literal sequence

ShortLCont:	txa
SubX:		axs	#$00		//X=X-1-Literal (e.g. Lit=#$00 -> X=A-1-0)
		stx	LitCopy+1

LitCopy:	lda	Buffer,y
		sta	(ZP),y
		dey
		bne	LitCopy		//Literal sequence is ALWAYS followed by a match sequence

//------------------------------
//		SHORT MATCH
//------------------------------

Match:		lda	Buffer,x
		anc	#$03		//also clears C=0
		beq	MidMatch	//C=0

ShortMatch:	tay			//Short Match Length=#$01-#$03 (corresponds to a match length of 2-4)
		eor	#$ff
		adc	ZP		//Subtracting #$02-#$04
		sta	ZP
		bcc	ShortMatchHi	//This saves 1 cycles per short match

ShortMCont:	lda	Buffer,x	//Short Match Offset=($00-$3f)+1=$01-$40
		lsr
		lsr
ShortConv:	sec
ShortConvNoSec:	adc	ZP
		sta	MatchCopy+1	//MatchCopy+1=ZP+(Buffer)+(C=1)
		lda	ZP+1
		adc	#$00
		sta	MatchCopy+2	//C=0 after this
		dex			//DEX needs to be after ShortConv
		iny			//Y+=1 for bne to work (cannot be #$ff and #$00)
MatchCopy:	lda	$10ad,y		//Y=#$02-#$04 (short) vs #$03-#$3e (mid) vs #$3f-#$ff (long) after INY (cannot be #$00 and #$01)
		sta	(ZP),y		//Y=#$00 is never used here 
		dey
		bne	MatchCopy

//------------------------------
//		BITCHECK		//Y=#$00 here
//------------------------------

BitCheck:	asl	Bits		//C=0 here
		bcc	LitCheck	//C=0, literals must be done first as matches after literals do not need a seletor bit
		bne	Match		//C=1, Z=0, match (bits: 1)

//------------------------------

		lda	Buffer,x	//C=1, Z=1 => Bits=#$00, token bit in C, update Bits
		dex
		rol
		sta	Bits
		bcs	Match		//C=1, match

//------------------------------

LitCheck:	asl	Bits
		bcc	ShortLit	//C=0, we have 1 literal (bits: 10)
		beq	NextBit		//C=1, Z=1, this is the token bit in C (bits=11), get next bit stream byte

//------------------------------
//		LITERALS 2-16
//------------------------------
		
MidLitSeq:	ldy	#$f8
		bpl	SkipML		//C=1 here
		ldy	Buffer,x	//6 cycles and 5 bytes less here
		tya
		dex
		alr	#$f0		//0xxxx000
		lsr			//00xxxx00
		lsr			//000xxxx0
SkipML:		ror			//0000xxxx vs 1xxxxxxx depending on branch taken
		sta	MidLitSeq+1
		tya			//4 cycles and 3 bytes more here, saving 2 cycles and 2 bytes overall per midlit byte
		anc	#$0f		//C=0
		tay
		bne	MidLit		//33+20=53

//------------------------------
//		LITERALS 17-251
//------------------------------

		ldy	Buffer,x	//Literal lengths 17-251 (Bits: 11|0000|xxxxxxxx)
		bcc	LongLit		//ALWAYS, C=0, we have 17-251 literals

//------------------------------

ShortLitHi:	dec	ZP+1
		bcc	ShortLCont

//------------------------------

ShortMatchHi:	dec	ZP+1		//Use the 2 freed bytes to save 1 cycle per short match
		bcc	ShortMCont

//------------------------------
//		IRQ INSTALLER
//		Call:	jsr $02d2
//		X/Y=Player Hi/Lo
//		A=Raster
//------------------------------

Sparkle_InstallIRQ:
		sty	Sparkle_IRQ_JSR+1	//Installs a subroutine vector
		stx	Sparkle_IRQ_JSR+2
Sparkle_RestoreIRQ:
		sta	$d012			//Sets raster for IRQ
		lda	#<Sparkle_IRQ		//Installs Fallback IRQ vector
		sta	$fffe
		lda	#>Sparkle_IRQ
		sta	$ffff
		rts

//------------------------------
//		FALLBACK IRQ
//		Address: $02e6
//------------------------------

Sparkle_IRQ:
		pha
		txa
		pha
		tya
		pha
		lda	$01
		pha

		jsr	Set01

		inc	$d019

Sparkle_IRQ_JSR:
		jsr	Done		//Music player or IRQ subroutine, installer @ $02d1

		pla
		sta	$01
		pla
		tay
		pla
		tax
		pla
Sparkle_IRQ_RTI:
		rti

//------------------------------

//.text "<OMG>"

EndLoader:

.var myFile = createFile("Sparkle.inc")
.eval myFile.writeln("//--------------------------------")
.eval myFile.writeln("//	Sparkle loader labels	")
.eval myFile.writeln("//	KickAss format		")
.eval myFile.writeln("//--------------------------------")
.eval myFile.writeln("#importonce")
.eval myFile.writeln("")
.eval myFile.writeln(".label Sparkle_SendCmd		=$" + toHexString(Sparkle_SendCmd) + "	//Requests a bundle (A=#$00-#$7f) and prefetches its first sector, or")
.eval myFile.writeln("					//Requests a new disk (A=#$80-#$fe [#$80 + disk index]) without loading its first bundle, or")
.eval myFile.writeln("					//Resets drive (A=#$ff)")
.eval myFile.writeln(".label Sparkle_LoadA		=$" + toHexString(Sparkle_LoadA) + "	//Index-based loader call (A=#$00-#$7f), or")
.eval myFile.writeln("					//Requests a new disk & loads first bundle (A=#$80-#$fe [#$80 + disk index])")
.eval myFile.writeln(".label Sparkle_LoadFetched	=$" + toHexString(Sparkle_LoadFetched) + "	//Loads prefetched bundle, use only after Sparkle_SendCmd (A=bundle index)")
.eval myFile.writeln(".label Sparkle_LoadNext		=$" + toHexString(Sparkle_LoadNext) + "	//Sequential loader call, parameterless, loads next bundle in sequence")
.eval myFile.writeln(".label Sparkle_InstallIRQ	=$" + toHexString(Sparkle_InstallIRQ) + "	//Installs fallback IRQ (A=raster line, X/Y=subroutine/music player vector high/low bytes)") 
.eval myFile.writeln(".label Sparkle_RestoreIRQ	=$" + toHexString(Sparkle_RestoreIRQ) + "	//Restores fallback IRQ without changing subroutine vector (A=raster line)")
.eval myFile.writeln(".label Sparkle_IRQ		=$" + toHexString(Sparkle_IRQ) + "	//Fallback IRQ vector")
.eval myFile.writeln(".label Sparkle_IRQ_JSR		=$" + toHexString(Sparkle_IRQ_JSR) + "	//Fallback IRQ subroutine/music player JSR instruction")
.eval myFile.writeln(".label Sparkle_IRQ_RTI		=$" + toHexString(Sparkle_IRQ_RTI) + "	//Fallback IRQ RTI instruction, used as NMI vector")
.eval myFile.writeln(".label Sparkle_Save		=$302	//Hi-score file saver (A=#$01-#$0f, high byte of file size, A=#$00 to abort), only if hi-score file is included on disk")

.print "Sparkle_SendCmd:	" + toHexString(Sparkle_SendCmd)
.print "Sparkle_LoadA:	" + toHexString(Sparkle_LoadA)
.print "Sparkle_LoadFetched:	" + toHexString(Sparkle_LoadFetched)
.print "Sparkle_LoadNext:	" + toHexString(Sparkle_LoadNext)
.print "Sparkle_InstallIRQ:	" + toHexString(Sparkle_InstallIRQ)
.print "Sparkle_RestoreIRQ:	" + toHexString(Sparkle_RestoreIRQ)
.print "Sparkle_IRQ:		" + toHexString(Sparkle_IRQ)
.print "Sparkle_IRQ_JSR:	" + toHexString(Sparkle_IRQ_JSR)
.print "Sparkle_IRQ_RTI:	" + toHexString(Sparkle_IRQ_RTI)
.print "Loader End:		" + toHexString(EndLoader-1)
}