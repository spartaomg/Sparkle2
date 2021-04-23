//TAB=6
//----------------------------------------------------------------------
//	SPARKLE 2
//	Inspired by Lft's Spindle and Krill's Loader
//	C64 Code
//	Tested on 1541-II, 1571, 1541 Ultimate-II+, Oceanic, and THCM's SX-64
//----------------------------------------------------------------------
//	Memory Layout
//
//	0160	02d1	Loader + Depacker
//	02d2	02e5	IRQ Installer
//	02e6	02ff	Fallback IRQ
//	0300	03ff	Buffer
//
//-----------------------------------------------------------------------
//
//	Functions & Addresses
//
//	Sparkle_SendCmd		=$160	Requests a bundle (A=#$00-#$7f) and prefetches its first sector, or
//						Requests a new disk (A=$80 + disk index) without loading its first bundle, or
//						Resets drive (A=$ff)
//	Sparkle_LoadA		=$184	Index-based loader call (A=$00-$7f), or
//						Requests a new disk & loads first bundle (A=$80 + disk index)
//	Sparkle_LoadFetched	=$187	Loads prefetched bundle, use only after Sparkle_SendCmd (A=bundle index)
//	Sparkle_LoadNext		=$1fc	Sequential loader call, parameterless, loads next bundle in sequence
//	Sparkle_InstallIRQ	=$2d2	Installs fallback IRQ (A=raster line, X/Y=subroutine/music player vector high/low bytes)
//	Sparkle_RestoreIRQ	=$2d8	Restores fallback IRQ without changing subroutine vector (A=raster line)
//	Sparkle_IRQ			=$2e6	Fallback IRQ vector
//	Sparkle_IRQ_JSR		=$2f4	Fallback IRQ subroutine/music player JSR instruction
//	Sparkle_IRQ_RTI		=$2ff	Fallback IRQ RTI instruction, used as NMI vector
//	Sparkle_Save		=$302	Hi-score File Saver (A=$01-$0f, high byte of file size)
//						Only if Hi-score File is included on disk
//
//-----------------------------------------------------------------------

//Constants
.const	Sp		=<$ff+$52	//#$51 - Spartan Stepping constant
.const	InvSp		=Sp^$ff	//#$ae

.const	busy		=$f8		//DO NOT CHANGE IT TO #$FF!!!
.const	ready		=$08		//AO=1, CO=0, DO=0 on C64 -> $1800=#90
.const	sendbyte	=$18		//AO-1, CO=1, DO=0 on C64 -> $1800=$94
.const	drivebusy	=$12		//AA=1, CO=0, DO=1 on Drive

.const	Buffer	=$0300

.const	LDA_ABSY	=$b9
.const	ORA_ABSY	=$19
.const	AND_ABSY	=$39
.const	NTSC_CLRATN	=$c0
.const	NTSC_DD00_1	=$dd00-ready
.const	NTSC_DD00_2	=$dd00-NTSC_CLRATN

//ZP Usage
.const	ZP		=$02		//$02/$03
.const	Bits		=$04
.const	DriveNo	=$fb
.const	DriveCt	=$fc

//Kernal functions
.const	Listen	=$ed0c
.const	ListenSA	=$edb9
.const	Unlisten	=$edfe
.const	SetFLP	=$fe00
.const	SetFN		=$fdf9
.const	Open		=$ffc0


*=$0801	"Basic"			//Prg starts @ $0810
BasicUpstart(Start)

*=$0810	"Installer"

//----------------------------------
//Check IEC bus for multiple drives
//----------------------------------

Start:	lda	#$ff
		sta	DriveCt
		ldx	#$04
		lda	#$08
		sta	$ba

DriveLoop:	lda	$ba
		jsr	Listen
		lda	#$6f
		jsr	ListenSA		//Return value of A=#$17 (drive present) vs #$c7 (drive not present)
		bmi	SkipWarn		//check next drive # if not present

		lda	$ba			//Drive present
		sta	DriveNo		//This will be the active drive if there is only one drive on the bus
		jsr	Unlisten
		inc	DriveCt
		beq	SkipWarn		//Skip warning if only one drive present

		lda	$d018			//More than one drive present, show warning
		bmi	Start			//Warning is already on, start bus check again

		ldy	#$03
		ldx	#$00
		lda	#$20
ClrScrn:	sta	$3c00,x		//Clear screen RAM @ $3c00
		inx				//JSR $e544 does not work properly on old Kernal ROM versions
		bne	ClrScrn
		inc	ClrScrn+2
		dey
		bpl	ClrScrn

		ldx	#<WEnd-Warning-1
TxtLoop:	lda	Warning,x		//Copy warning
		sta	$3db9,x
		lda	$286			//Foreground color
		sta	$d9b9,x		//Needed for old Kernal ROMs
		dex
		bpl	TxtLoop

		lda	#$f5			//Screen RAM: $3c00
		sta	$d018
		bmi	Start			//Warning turned on, start bus check again

SkipWarn:	inc	$ba
		dex
		bne	DriveLoop

		//Here, DriveCt can only be $ff or $00

		lda	#$15			//Restore Screen RAM to $0400
		sta	$d018

		lda	DriveCt
		beq	ChkDone		//One drive only, continue

		ldx	#<NDWEnd-NDW
NDLoop:	lda	NDW-1,x		//No drive, show message and finish
		jsr	$ffd2
		dex
		bne	NDLoop
		stx	$0801			//Delete basic line to force reload
		stx	$0802
		rts

//----------------------------------
//		Install Drive Code
//----------------------------------

ChkDone:	ldx	#<Cmd
		ldy	#>Cmd
		lda	#CmdEnd-Cmd
		jsr	SetFN			//Filename = drive install code in command buffer

		lda	#$0f
		tay
		ldx	DriveNo
		jsr	SetFLP		//Logical parameters
		jsr	Open			//Open vector

		sei

		lda	#$35
		sta	$01

		ldx	#$5f
		txs				//Loader starts @ $160, so reduce stack to $100-$15f

		lda	#$3c			// 0  0  1  1  1  1  0  0
		sta	$dd02			//DI|CI|DO|CO|AO|RS|VC|VC
		ldx	#$00			//Clear the lines
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
		
NextLine:	lda	$d012			//Based on J0x's solution for NTSC detection from CodeBase64.org
SameLine:	cmp	$d012
		beq	SameLine
		bmi	NextLine
		cmp	#$20
		bcs	SkipNTSC

		lda	#<NTSC_DD00_2
		sta	Read2+1
		lda	#>NTSC_DD00_1	//= >NTSC_DD00_2
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

		lda	#>$10ad		//#>PrgStart-1	(Hi Byte)
		pha
		lda	#<$10ad		//#<PrgStart-1	(Lo Byte)
		pha				//Load first Bundle, it may overwrite installer, so we use an alternative approach here
		jmp	Sparkle_LoadFetched

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
//Load all 5 drive code blocks into buffers 0-4 at $300-$7ff on drive

.byte	'M','-','E',$05,$02	//-0204	Command buffer: $0200-$0228

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
					//		7 bytes free here
CmdEnd:

//----------------------------
//	C64 RESIDENT CODE
//	$0160-$02ff
//----------------------------

LoaderCode:

*=LoaderCode	"Loader"

.pseudopc $0160	{

Sparkle_SendCmd:
		sta	Bits		//Store Bundle Number on ZP
		jsr	Set01		//$dd00=#$3b, $1800=#$95, Bus Lock, A=#$35
SS_Send:	ldx	#sendbyte	//CO=1, AO=1 => C64 is ready to send a byte, X=#$18
		stx	$dd00		//Signal to Drive that we want to send Bundle Index
		bit	$dd00		//$dd00=#$9b, $1800=#$94
		bmi	*-3		//Wait for Drive response ($1800->00 => $dd00=#$1b, $1800=#$85)

		anc	#$31		//Drive is ready to receive byte, A=#$31, C=0

					//Sending bits via AO, flipping CO to signal new bit
BitSLoop:	adc	#$e7		//2	A=#$31+#$e7=#$18 and C=1 after addition in first pass, C=0 in all other passes
		sax	$dd00		//4	subsequent passes: A&X=#$00/#$08/#$10/#$18 and C=0
		and	#$10		//2	Clear AO
		eor	#$10		//2	A=#$18 in first pass (CO=1, AO=1) reads #$85 on $1800 - no change, first pass falls through
		ror	Bits		//5	C=1 in first pass, C=0 in all other passes before ROR
		bne	BitSLoop	//3
					//18 cycles/bit - drive loop needs 17 cycles/bit (should work for both PAL and NTSC)

BusLock:	lda	#busy		//2	Worst case, last bit is read by the drive on the first cycle of LDA
		sta	$dd00		//4	Bus lock (A=#$f8), changes in $dd02 will not affect $dd00

		rts			//6

Sparkle_LoadA:
		jsr	Sparkle_SendCmd
Sparkle_LoadFetched:
		jsr	Set01		//17
		ldx	#$00		//2
		ldy	#ready	//2	Y=#$08, X=#$00
		sty	$dd00		//4	Clear CO and DO to signal Ready-To-Receive
		bit	$dd00		//Wait for Drive
		bvs	*-3		//$dd00=#$cx - drive is busy, $0x - drive is ready	00,01	(BMI would also work)
		stx	$dd00		//Release ATN							02-05
		dex			//									06,07
		jsr	Set01		//Waste a few cycles... (drive takes 16 cycles)		08-24 minimum needed here is 8 cycles

//-------------------------------------
//
//	    72-BYCLE RECEIVE LOOP
//
//-------------------------------------

RcvLoop:
Read1:	lda	$dd00		//4		W1-W2 = 18 cycles					25-28
		sty	$dd00		//4	8	Y=#$08 -> ATN=1
		lsr			//2	10
		lsr			//2	12
		inx			//2	14
		nop			//2	16
		ldy	#$c0		//2	(18)

Read2:	ora	$dd00		//4		W2-W3 = 16 cycles
		sty	$dd00		//4	8	Y=#$C0 -> ATN=0
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
//		LONG MATCH
//----------------------------

LongMatch:	clc
		bne	NextFile	//A=#$3f - Next file in block (#$fc)
		dex			//A=#$3e - Long Match (#$f8), read next byte for Match Length (#$3e-#$fe)
		lda	Buffer,x	//If A=#$00 then Bundle is done, rest of the block in buffer is the beginning of the next Bundle
		bne	MidConv	//Otherwise, converge with mid match (A=#$3e-#$fe here if branch taken)

//----------------------------
//		END OF BUNDLE
//----------------------------

		dex
		stx	Buffer+$ff	//Save last X position in buffer for next Bundle depacking
Set01:	lda	#$35
		sta	$01		//Restore $01
Done:		rts

//----------------------------
//		END OF BLOCK
//----------------------------

NextBlock:	beq	Sparkle_LoadFetched	//Trampoline

//----------------------------
//		SPARTAN STEP DELAY
//----------------------------

SpSDelay:	lda	#<RcvLoop-<ChgJmp	//20	Restore Receive loop
		sta	JmpRcv+1		//24
		txa				//26
		eor	#InvSp		//28	Invert byte counter
		sta	SpComp+1		//32	SpComp+1=(#$2a <-> #$ff)
		bmi	RcvLoop		//(35) (Drive loop takes 33 cycles)

//----------------------------------

		jsr	BusLock

//------------------------------------------------------------
//		BLOCK STRUCTURE FOR DEPACKER
//------------------------------------------------------------
//		$00	  - First Bitstream byte -> will be changed to #$00 (end of block)
//			    This way we are actually storing 257 bytes worth of info in 256 bytes
//		$ff	  - Dest Address Lo
//		($fe	  - IO Flag)
//		$fe/$fd - Dest Address Hi
//		$fd/$fc - Bytestream backwards with Bitstream interleaved
//		...
//		$01	  - Last data byte vs #$00 if block count on drive side
//------------------------------------------------------------

Sparkle_LoadNext:	
		ldx	#$ff		//Entry point for next bundle in block
		stx	MidLitSeq+1	//Reset MidLitSeq 
		inx
		
		lda	Buffer	//Retrieve first bitstream value
		stx	Buffer	//And replace it with #$00 (EndofBlock marker)
		bne	StoreBits	//If 0 then we need to find first byte of new bundle in buffer
		ldx	Buffer+$ff	//=Last X pos in buffer
		lda	Buffer,x
StoreBits:	sta	Bits		//Store bitstream value on ZP for faster processing

NextFile:	dex			//Entry point for next file in block
		lda	Buffer,x	//Lo Byte of Dest Address
		sta	ZP

		ldy	#$35		//Default value for $01, IO=on
		dex
		lda	Buffer,x	//Hi Byte vs IO Flag=#$00
		bne	SkipIO
		dey			//Y=#$34, turn IO off
		dex
		lda	Buffer,x	//This version can also load to zeropage

SkipIO:	sta	ZP+1		//Hi Byte of Dest Address
		sty	$01		//Update $01

		dex

		ldy	#$00		//Needed for Literals

		jmp	LitCheck	//Always start with literals

//----------------------------
//		MID MATCH
//----------------------------

MidMatch:	lda	Buffer,x	//C=0
		beq	NextBlock	//Match byte=#$00 -> end of block, load next block
		cmp	#$f8		//Long Match Tag
		bcs	LongMatch	//Long Match/EOF (C=1) vs. Mid Match (C=0)
		lsr
		alr	#$fe		//Faster for Long Matches, same for Mid Matches

MidConv:	tay			//Match Length=#$01-#$3d (mid) vs. #$3e-#$fe (long)
		eor	#$ff
		adc	ZP		//C=0 here
		sta	ZP

		dex
		lda	Buffer,x	//Match Offset=$00-$ff+(C=1)=$01-$100

		bcs	ShortConv+1	//Skip SEC
		dec	ZP+1
		bcc	ShortConv	//Converge with short match

//----------------------------
//		LITERALS
//----------------------------

NextBit:	lda	Buffer,x	//C=1, Z=1, Bits=#$00, token bit in C, update Bits
		rol
		sta	Bits
LongLit:
		dex			//Saves 1 byte and adds 2 cycles per LongLit sequence, C=0 for LongLit
		bcs	MidLitSeq	//C=1, we have more than 1 literals, LongLit (C=0) falls through

ShortLit:	tya			//Y=00, C=0
MidLit:	iny			//Y+Lit-1, C=0
		sty	SubX+1	//Y+Lit, C=0
		eor	#$ff		//ZP+=(A^#$FF)+(C=1) => ZP-=A
		adc	ZP
		sta	ZP
		bcs	*+4
		dec	ZP+1

		txa
SubX:		axs	#$00		//X=A-1-Literal (e.g. Lit=#$00 -> X=A-1-0)
		stx	LitCopy+1

LitCopy:	lda	Buffer,y
		sta	(ZP),y
		dey
		bne	LitCopy	//Literal sequence is ALWAYS followed by a match sequence

//----------------------------
//		SHORT MATCH
//----------------------------

Match:	lda	Buffer,x
		anc	#$03		//also clears C
		beq	MidMatch

ShortMatch:	tay			//Short Match Length=#$01-#$03 (corresponds to a match length of 2-4)
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
		dex			//DEX needs to be after ShortConv
		iny			//Y+=1 for bne to work (cannot be #$ff and #$00)
MatchCopy:	lda	$10ad,y	//Y=#$02-#$04 (short) vs #$02-#$3e (mid) vs #$3f-#$ff (long) after INY (cannot be #$00 and #$01)
		sta	(ZP),y	//Y=#$00 is never used here - it is used as the End of Stream flag
		dey
		bne	MatchCopy

//----------------------------
//		BITCHECK		//Y=#$00 here
//----------------------------

BitCheck:	asl	Bits		//C=0 here
		bcc	LitCheck	//C=0 -> literals
		bne	Match		//C=1, Z=0, this is a match (bits: 1)

//----------------------------

		lda	Buffer,x	//C=1, Z=1, Bits=#$00, token bit in C, update Bits
		dex
		rol
		sta	Bits
		bcs	Match

//----------------------------

LitCheck:	asl	Bits		//C=1, for first check in block, C=0 for any other cases
		bcc	ShortLit	//C=0, we have 1 literal (bits: 00)
		beq	NextBit	//C=1, Z=1, this is the token bit in C (Bits=#$00), get next bit stream byte

//----------------------------
//		LITERALS 2-16
//----------------------------

MidLitSeq:	ldy	#$f8		//Literal lenghts 2-16 (bits: 01|xxxx)
		bpl	SkipML	//C=1 here
		lda	Buffer,x	//Y>#$7f -> fetch new MidLit value
		tay
		dex
		lsr			//0xxxx...
		lsr			//00xxxx..
		alr	#$3c		//000xxxx0	C=0, N=0 after this -> 
SkipML:	arr	#$1e		//0000xxxx vs 1000xxxx	C=0, N=0 vs N=1 after this, depending on the branch taken
		sta	MidLitSeq+1	//ARR swaps C with the MSB of A (C <-> N)
		tya
		and	#$0f
		tay
		bne	MidLit

//----------------------------
//		LITERALS 17-251
//----------------------------

		ldy	Buffer,x	//Literal lengths 17-251 (bits: 11|0000|xxxxxxxx)
		bcc	LongLit	//ALWAYS, C=0, we have 17-251 literals (could use BNE)

//----------------------------
//		IRQ INSTALLER
//		X/Y=Player Hi/Lo
//		A=Raster line
//----------------------------

Sparkle_InstallIRQ:	
		sty	Sparkle_IRQ_JSR+1	//Installs a subroutine vector
		stx	Sparkle_IRQ_JSR+2
Sparkle_RestoreIRQ:	
		sta	$d012			//Sets raster for IRQ
		lda	#<Sparkle_IRQ	//Installs Fallback IRQ vector
		sta	$fffe
		lda	#>Sparkle_IRQ
		sta	$ffff
		rts

//----------------------------
//		FALLBACK IRQ
//----------------------------

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
		jsr	Done		//Music player or IRQ subroutine

		pla
		sta	$01
		pla
		tay
		pla
		tax
		pla
Sparkle_IRQ_RTI:
		rti

//----------------------------

EndLoader:

.print "SendCmd:		" + toHexString(Sparkle_SendCmd)
.print "LoadA:		" + toHexString(Sparkle_LoadA)
.print "LoadFetched:		" + toHexString(Sparkle_LoadFetched)
.print "LoadNext:		" + toHexString(Sparkle_LoadNext)
.print "IRQ Installer:	" + toHexString(Sparkle_InstallIRQ)
.print "IRQ Restore:		" + toHexString(Sparkle_RestoreIRQ)
.print "Fallback IRQ:		" + toHexString(Sparkle_IRQ)
.print "IRQ_JSR:		" + toHexString(Sparkle_IRQ_JSR)
.print "IRQ_RTI:		" + toHexString(Sparkle_IRQ_RTI)
.print "Loader End:		" + toHexString(EndLoader-1)
}