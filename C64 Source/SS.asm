//TAB=8
//----------------------------
//	Sparkle 2
//	Hi-Score File Saver
//	C64 CODE
//----------------------------
//	Version history
//
//	v1.0 	- initial version
//		  tested on real hardware
//		  high score file size: $0100-$0f00
//
//	v1.1	- added support for loading/saving under the I/O space
//		- escape without saving
//		  calling the function with X=0 will allow to return without saving
//
//	v1.2	- simplified Send function in C64 code
//		  relying on Sparkle_SendCmd
//
//	v1.3	- adjusting drive code to new Tab8 layout and trailing 0 check 
//
//	v1.4	- adjusting code to ATNA-based transfer
//
//	v1.5	- adapting drive code to Sparkle 2.1 drive code 
//
//----------------------------
//	BLOCK STRUCTURE
//
//		00 01 02 03 04		...			F9 FA FB FC FD FE FF
//First block:	00 BC [DATA: $F7 bytes]				F6 00 AH 00 AL 81 FE
//Other block:	81 [DATA: $FA bytes]				F9 00 AH 00 AL

//First block end:00 FF*F8 [DATA: max $F7 bytes]		F5 00 AH 00 AL 81 FE
//Other block end:81 FF*F8 [DATA: max $F9 bytes]		F7 00 AH 00 AL
//*FF = new block count (converts to 00 on the drive), will be overwritten to 00 by the drive = End Sequence (00 F8)

//----------------------------

{
#import "SL.sym"			//Import labels from SL.asm

.const	SupportIO	=cmdLineVars.get("io").asBoolean()

.const	ZP		=$02
.const	Bits		=$04

.const	sendbyte	=$18		//AO-1, CO=1, DO=0 on C64 -> $1800=$94
.const	c64busy		=$f8		//DO NOT CHANGE IT TO #$FF!!!

.var	FirstLit	=$f7		//First block's literal count
.var	NextLit		=$fa		//All other blocks' literal count

.if (SupportIO == true) {
.eval	FirstLit	-=1
.eval	NextLit		-=1
}

.const	EoB		=$f8		//End of Bundle flag
.const	NextBCt		=$7f		//Next block count - $00 EOR-transformed

*=$2900	"C64 Save Code"

.pseudopc $0300 {

ByteCnt:
.byte	$00,$77				//First 2 bytes of block - 00 and block count, will be overwritten by Byte counter

SLSaveStart:
//----------------------------------------
//		Init
//----------------------------------------

		cmp	#$00		//Max. value determined by default hi-score file in script
		bcc	*+4		//Abort saving if file size is outside range
		lda	#$00
		sta	ByteCnt+1	//HiByte of total bytes to be sent, ByteCnt = #$00 by default
		tax			//This way the function can be called with A (like the other loader functions)
		lda	ByteConv,x	//Block count EOR-transformed
		sta	BlockCnt+1
		lda	#$00
		sta	AdLo
		txa
		clc
		adc	#$00
		sta	AdHi
		jsr	Set01
		bne	StartSend	//Branch always, first we send the block count, if 0, nothing to be saved, job done
SendNextBlock:

//----------------------------------------
//		Send Block Header
//----------------------------------------

HdrCtr:		ldy	#BHdrEnd-BlockHdr-1
HdrLoop:	lda	BlockHdr,y
		jsr	Send
		dey
		bpl	HdrLoop

//----------------------------------------
//		Update Address and Byte Counter
//----------------------------------------

		lda	AdLo		//AdLo and AdHi are part of the Block Header
		clc			//Only update them once the Block Header is sent!!!
		sbc	LitCnt
		sta	AdLo
		sta	ZP
		lda	AdHi
		sbc	#$00
		sta	AdHi
		sta	ZP+1

		lda	ByteCnt
		clc			//ByteCnt-=(BlockHdr+1)
		sbc	LitCnt
		sta	ByteCnt
		bcs	*+5
		dec	ByteCnt+1

//----------------------------------------
//		Send Literals
//----------------------------------------

		ldy	LitCnt
		iny
LitLoop:
.if (SupportIO==true)	{
		dec	$01				
		}			//To allow saving data from under the I/O space
		lda	(ZP),y
.if (SupportIO==true)	{
		inc	$01				
		}			//Restore $01 to #$35 for transfer
		jsr	Send
		dey
		bne	LitLoop

//----------------------------------------
//		Send Trailing Zeros
//----------------------------------------

		lda	HdrCtr+1	//#$07 vs #$05
		cmp	#<BHdrLong-BlockHdr-1
		bne	SkipZeros	//#$05? - this is needed - in the case of the first block, addition's result is #$fe
		sec			//+1 C=1 anyway?, SEC not needed here???
		adc	LitCnt		//=LitCnt-1
		eor	#$ff
		beq	SkipZeros
		tay
		dey
		lda	#<EoB
		bne	*+4
ZeroLoop:	lda	#$00
		jsr	Send
		dey
		bne	ZeroLoop
		lda	#<NextBCt	//Closing byte = block count = $00 EOR-transformed
		jsr	Send
SkipZeros:	lda	#BHdrLong-BlockHdr-1
		sta	HdrCtr+1

//----------------------------------------
//		Send BlockCnt, Update LitCnt
//----------------------------------------

		lda	LitCnt
		cmp	#<FirstLit	//First block? (sending #$f8 literals)
		bne	SkipBCnt
BlockCnt:	lda	#$77		//=#$01 EOR-tranformed, minimum block count
		jsr	Send
		lda	#<NextLit	//update LitCnt
		sta	LitCnt
SkipBCnt:

//----------------------------------------
//		Check Next Block
//----------------------------------------

StartSend:	lda	ByteCnt+1	//If function is called with A=0 then we will return immediately
		bne	ToNext		//Otherwise, block count is sent to signal stat of transfer
		lda	ByteCnt
		beq	Send		//A=#$00, signal transfer complete
		cmp	#<NextLit+1
		bcs	ToNext
		sbc	#$00		//C=0, we are subtracting 1 actually here
		sta	LitCnt		//LitCnt of last block (0-based)
ToNext:		jsr	Send		//A<>#$00, signal next block
		jmp	SendNextBlock

//----------------------------------------
//		Send a byte
//----------------------------------------

Send:		sta	Bits
		lda	#$31
		jmp	SS_Send

ByteConv:
.byte $7f,$77,$7d,$75,$7b,$73,$79,$71,$7e,$76,$7c,$74,$7a,$72,$78,$70
BlockHdr:
LitCnt:
.byte	FirstLit,$00
AdHi:
.byte	$00
IOFlag:
.if (SupportIO == true)	{
.byte $00				//I/O flag
}
AdLo:
.byte	$00,$81
BHdrLong:
.byte $fe,$00				//First byte ($fe) can be anything, the drive code will change it to $fe anyway
BHdrEnd:
}
*=$29f9	"C64 Close Sequence"		//Close Sequence of previous bundle
.pseudopc $03f9 {
.byte $00,$f8,$00,$03,$fb,$01,$fe	//When the plugin is loaded, the depacker will process this sequence
}
}

//----------------------------
//	Sparkle 2
//	Hi-Score File Saver
//	DRIVE CODE
//----------------------------

{
#import "SD.sym"			//Import labels from SD.asm

.const	ChkSum		=DirSector	//Temporary value on ZP for H2STab preparation and GCR loop timing
					//DirSector can be overwritten here

*=$2a00	"Drive Save Code"

.pseudopc $0100	{			//Stack pointer =#$00 at start

Start:		lda	#<SFetchJmp	//Update ReFetch vector, done once
		sta	ReFetch+1	//First 5 bytes will be overwritten with Block Header and Stack
		jmp	RcvCheck	//Let's check if we will receive anything...

//--------------------------------------
//		Find next sector in chain
//--------------------------------------

NextBlock:	ldy	#$02		//Reset BufLoc Hi Byte
		sty	BufLoc+2
		dey			//Find and mark next wanted sector on track, Y=#$01 (=block count)
		ldx	nS		//We only use track 35/40 for this purpose ATM, so no need for track change 
		jsr	Build		//Mark next wanted sector on wanted list
		sty	ChkSum		//Clear Checksum, Y=#$00 here

//--------------------------------------
//		Receive 256 bytes of data
//--------------------------------------

GetByteLoop:	jsr	NewByte		//Receive 1 block from C64, 1 byte at a time

ByteBfr:	sta	$0700		//And save it to buffer, overwriting internal directory
		eor	ChkSum
		sta	ChkSum		//Calculate checksum
		dec	ByteBfr+1
		bne	GetByteLoop

//--------------------------------------
//		Encode data block
//--------------------------------------

		jsr	Encode		//Data Block: $104 bytes (#$07+$100 data bytes+checksum+#$00+#$00) -> $145 GCR-bytes
		jsr	ToggleLED	//Turn LED on

//--------------------------------------
//		Write data block to disk
//--------------------------------------

SFetch:		ldy	#<SHeaderJmp
		jmp	FetchSHeader

//--------------------------------------
		//jmp	(SaveJmp)	//31
SHeader:	cmp	$0103		//35	Header byte #10 (GGGHHHHH) = $55, skipped (cycles 32-63)
		bne	SFetch		//37	We are on Track 35/40 here, so it is ALWAYS Speed Zone 0 (32 cycles per byte)
		jsr	ShufToRaw	//57
					//jsr	ShufToRaw	43
					//ldx	#$09		45
					//axs	#$00		47
					//eor	BitShufTab,x	51
					//rts			57
		cmp	LastS		//60
		bne	SFetch		//62
		tax			//64	First gap byte = $55, skipped (cycles 64-95)
		ldy	#$05		//66
		sty.z	WList,x		//70	Mark off sector on Wanted List
		clv			//72	Optimal CLV timing for all 4 speed zones for 275-312 rpm [70-74]

GapLoop:	bvc	*		//01	Skip an additional six $55 bytes (Header Gap)
		clv			//03	The 1541 ROM code also skips 7 gap bytes, NOT 9!!!
		dey			//05
		bpl	GapLoop		//07

		sty	$1c03		//11	R/W head to output, Y=#$ff
		lda	#$ce		//13
		sta	$1c0c		//15	Peripheral control register to output
		ldx	#$06		//19

SyncLoop:	bvc	*		//01
		clv			//07	Write 6 sync bytes (#$ff)
		sty	$1c01		//05	The 1541 ROM code also writes 6 sync bytes, NOT 5!!!
		dex			//09
		bne	SyncLoop	//11

		ldy	#$bb		//13
		ldx	#$02		//15
		txa			//17
BfrLoop2:	sta	BfrLoop1+2	//21	22
BfrLoop1:	lda	$0200,y		//25	26

		bvc	*		//01	01
		clv			//07
		sta	$1c01		//05
		iny			//09
		bne	BfrLoop1	//11
		lda	#$07		//13
		dex			//15
		bne	BfrLoop2	//18/17

		bvc	*		//01
		jsr	$fe00		//Using ROM function here to save a few bytes...

					//LDA $1c0c	Peripheral control register to input
					//ORA #$e0
					//STA $1c0c
					//LDA #$00
					//STA $1c03	R/W head to input
					//RTS

		jsr	ToggleLED	//Trun LED off - no proper ROM function for this unfortunately...

//--------------------------------------
//		Check for next block
//--------------------------------------

RcvCheck:	jsr	NewByte		//More blocks to write?

		tay
		bne	NextBlock

//--------------------------------------
//		Saving done, restore loader
//--------------------------------------

		stx	DirSector	//Reset DirSector to ensure next index-based load reloads the directory
		lda	#<FetchJmp
		sta	ReFetch+1	//Restore ReFetch vector
		jmp	CheckATN

//--------------------------------------
//		Receive a byte
//--------------------------------------

NewByte:	ldx	#$94		//Make sure C64 is ready to send (%10010100)
		jsr	CheckPort
		lda	#$80		//$dd00=#$9b, $1800=#$94
		ldx	#busy		//=#$10 (AA=1, CO=0, DO=0)
		jsr	RcvByte		//OK to use stack here

		ldx	#$95		//Wait for C64 to signal transfer complete (%10010101)
CheckPort:	cpx	$1800
		bne	*-3
		rts

//--------------------------------------
//		Convert 260 bytes to GCR codes
//--------------------------------------

Encode:		lda	#$bb		//Reset BufLoc Lo Byte
		sta	BufLoc+1

		lax	ZP07		//X = Bitcounter for encoded bytes: #$07
		jsr	GCREncode	//A = First byte of Data Block: #$07

EncodeLoop:	lda	$0700		//256 data bytes
		jsr	GCREncode

		inc	EncodeLoop+1
		bne	EncodeLoop

		lda	ChkSum		//Checksum
		jsr	GCREncode
		jsr	GCREncode	//Two trailing zeros, A=00 here

//--------------------------------------

GCREncode:	pha
		lsr
		lsr
		lsr
		lsr
		jsr	GCRize		//Convert high nibble to 5-bit GCR code first
		pla			//Then low nibble next
		and	#$0f
GCRize:		tay
		lda	$f77f,y		//GCR codes in the drive's ROM
		asl
		asl
		asl			//move 5 GCR bits to the left side of byte
		ldy	#$05		//bitcounter for GCR codes
NextBit:	asl
BufLoc:		rol	$02bb		//NEEDS TO BE RESET AT THE BEGINNING!!!
		dex
		bpl	SkipNext
		ldx	#$07
		inc	BufLoc+1
		bne	SkipNext
		stx	BufLoc+2
SkipNext:	dey
		bne	NextBit
		rts			//A=00 and Y=00 here
}
}