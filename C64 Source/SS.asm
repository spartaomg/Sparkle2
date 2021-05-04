//TAB=8
//----------------------------
//	Sparkle 2
//	Hi-Score File Saver
//	C64 CODE
//----------------------------

{
.import source "SL.sym"			//Import labels from SL.asm

//Constants & variables
.const	SupportIO	=cmdLineVars.get("io").asBoolean()

//ZP locations
.const	ZP		=$02
.const	Bits		=$04

.var	FirstLit	=$f7		//First block's literal count
.var	NextLit		=$fa		//All other block's literal count

.if (SupportIO == true) {
.eval	FirstLit	-=1
.eval	NextLit		-=1
}

.const	EoB		=$f8		//End of Bundle flag
.const	NextBCt		=$ff		//Next block count - $00 EOR-transformed

*=$2900	"C64 Save Code"

.pseudopc $0300 {

ByteCnt:
.byte	$00,$f7				//First 2 bytes of block - 00 and block count, will be overwritten by Byte counter

SLSaveStart:
//----------------------------------
//		Init
//----------------------------------

		sta	ByteCnt+1	//HiByte of total bytes to be sent, ByteCnt = #$00 by default
		tax
		lda	ByteConv,x	//Block count EOR-transformed
		sta	BlockCnt+1
		lda	#$00		//Will be updated during disk building using the Hi-Score Files Load Address-1
		sta	AdLo
		txa
		clc
		adc	#$00		//Will be updated during disk building using the Hi-Score Files Load Address-1
		sta	AdHi
		jsr	Set01		//Always start with $01=#$35
		bne	StartSend	//Branch always, first we send the block count, if 0, nothing to be saved, job done

SendNextBlock:

//----------------------------------
//		Send Block Header
//----------------------------------

HdrCtr:		ldy	#BHdrEnd-BlockHdr-1
HdrLoop:	lda	BlockHdr,y
		jsr	Send
		dey
		bpl	HdrLoop

//----------------------------------
//		Update Address and Byte Counter
//----------------------------------

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

//----------------------------------
//		Send Literals
//----------------------------------
		
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

//----------------------------------
//		Send Trailing Zeros
//----------------------------------

		lda	HdrCtr+1	//#$07 vs #$05
		cmp	#<BHdrLong-BlockHdr-1
		bne	SkipZeros
		sec			//+1
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

//----------------------------------
//		Send BlockCnt, Update LitCnt
//----------------------------------

		lda	LitCnt
		cmp	#<FirstLit	//First block? (sending #$f8 literals)
		bne	SkipBCnt
BlockCnt:	lda	#$f7		//=#$01 EOR-tranformed, minimum block count
		jsr	Send
		lda	#<NextLit	//Update LitCnt
		sta	LitCnt
SkipBCnt:

//----------------------------------
//		Check Next Block
//----------------------------------

StartSend:	lda	ByteCnt+1	//If function is called with X=0 then we will return immediately
		bne	ToNext		//Otherwise, block count is sent to signal stat of transfer
		lda	ByteCnt
		beq	Send		//A=#$00, signal transfer complete
		cmp	#<NextLit+1
		bcs	ToNext
		sbc	#$00		//C=0, we are subtracting 1 actually here
		sta	LitCnt		//LitCnt of last block (0-based)
ToNext:		jsr	Send		//A<>#$00, signal next block
		jmp	SendNextBlock

//----------------------------------
//		Sending a byte
//----------------------------------

Send:		sta	Bits
		lda	#$31
		jmp	SS_Send

ByteConv:
.byte	$ff,$f7,$fd,$f5,$fb,$f3,$f9,$f1,$fe,$f6,$fc,$f4,$fa,$f2,$f8,$f0
BlockHdr:
LitCnt:
.byte	FirstLit,$00
AdHi:
.byte	$00
IOFlag:
.if (SupportIO == true)	{
.byte	$00				//I/O flag
}
AdLo:
.byte	$00,$81
BHdrLong:
.byte	$fe,$00				//First byte ($fe) can be anything, the drive code will change it to $fe anyway
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
.import source "SD.sym"			//import labels from SD.asm

//Constants & variables
.const	DO		=$02
.const	CO		=$08
.const	AA		=$10
.const 	busy		=AA		//DO=0,CO=0,AA=1	$1800=#$10	dd00=010010xx (#$4b)
.const	ready		=CO		//DO=0,CO=1,AA=0	$1800=#$08	dd00=100000xx (#$83)

//ZP Usage
.const	nS		=$02		//Next Sector
.const	ZP07		=$57		//=#$07
.const	WList		=$3e		//Wanted Sector list ($3e-$52) (00=unfetched, [-]=wanted, [+]=fetched)
.const	DirSector	=$56		//Initial value=#$c5 (<>#$10 or #$11)
.const	LastS		=$61		//Sector number of last block of a Bundle, initial value=#$00
.const	ChkSum		=DirSector	//Temporary value on ZP for H2STab preparation and GCR loop timing
					//DirSector can be overwritten here

.const	BitShufTab	=Tab300+1	//Bit Shuffle Tab (16 bytes total, insterspersed on page)

*=$2a00	"Drive Save Code"

.pseudopc $0100	{			//Stack pointer =#$00 at start

//----------------------------------
//		Init
//----------------------------------

Start:		lda	#<SFetchJmp	//Modify JMP address for Checksum Error on ZP - fetch again if checksum does not match
		sta	FetchAgain+1	//First 5 bytes will be overwritten with Block Header and Stack
		
		bne	RcvCheck	//Branch always, first let's check if we will receive anything...
		
NextBlock:	ldy	#$02		//Reset BufLoc Hi Byte
		sty	BufLoc+2
		dey			//Find and mark next wanted sector on track, Y=#$01 (=block count)
		ldx	nS		//We only use track 35/40 for this purpose ATM, so no need for track change 
		jsr	Build		//Mark next wanted sector on wanted list
		sty	ChkSum		//Clear Checksum, Y=#$00 here

//----------------------------------
//		Receive $100 bytes
//----------------------------------

GetByteLoop:
		jsr	NewByte		//Receive 1 block from C64, 1 byte at a time

ByteBfr:	sta	$0700		//And save it to buffer, overwriting internal directory
		eor	ChkSum
		sta	ChkSum		//Calculate checksum
		dec	ByteBfr+1
		bne	GetByteLoop

		jsr	Encode	//Data Block: $104 bytes (#$07+$100 data bytes+checksum+#$00+#$00) needing $145 GCR-encoded bytes
				//Last $45 bytes of Tab8 are overwritten by GCR codes, but luckily this is not a problem!
				//Tab8 is encoded as 77788888 and is required to decode the track number in the sector header
				//The expected value is #$23 (Track 35) which translates to
				//10|01010011 -> #$53 - thus, GCR loop reads from the lower, intact half of Tab8 :)
				//On 40-track disks: #$28 = 10|01001001 -> #$49 - lower, intact half of Tab8 again
				//The high nibble of the track number can only be 0 (01|010), 1 (01|011), or 2 (10|010)
				//Bit 2 is 0 in all 3 cases making all tracks accessible via the intact part of Tab8 :)

		jsr	ToggleLED	//Turn LED on

//----------------------------

SFetch:		ldy	#<SHeaderJmp	
		jmp	FetchHeader+2

//----------------------------
//		Save buffer to disk
//----------------------------
					//We are on Track 35/40 here, so it is ALWAYS Speed Zone 0 (32 cycles per byte)
SHeader:				//96-127*
		//jmp (SHeader)		//101 End of GCR loop on ZP
					//we could even add some delay here for zone 0...
					//Header byte #9 (56666677) = $55, skipped
		lda	$0103		//105
		jsr	ShufToRaw	//01
						//jsr	ShufToRaw		111
						//ldx	#$99			113
						//nop	#$64			115
						//axs	#$00			117
						//nop				119
						//eor	BitShufTab,x	123
						//rts				129/01
		cmp	LastS		//04
		clv			//06	Header byte #10 (77788888) = $55, skipped
		bne	SFetch		//09
		tax			//11
		ldy	#$06		//13
		sty	WList,x		//17	Mark off sector on Wanted List

BvcLoop:	bvc	*		//02	Skip 7 (NOT 9!) more $55 bytes (Header Gap)
		clv			//04
		dey			//06
		bpl	BvcLoop		//08

		sty	$1c03		//12	Y=#$ff
		lda	#$ce		//14
		sta	$1c0c		//18

		ldx	#$05		//20

FFLoop:		bvc	*		//02	Byte #18
		sty	$1c01		//06	Write 5 sync bytes (#$ff)
		clv			//08	The 1541 ROM code actually writes 6 sync bytes
		dex			//10
		bne	FFLoop		//12	BPL to match the 1541 ROM

		ldy	#$bb		//14
		ldx	#$02		//16
		txa			//18
BfrLoop2:	sta	BfrLoop1+2	//22	23
BfrLoop1:	lda	$0200,y		//26	27

		bvc	*		//02	02
		sta	$1c01		//08
		clv			//04
		iny			//10
		bne	BfrLoop1	//12
		lda	#$07		//14
		dex			//16
		bne	BfrLoop2	//19/18

		bvc	*		//02
		jsr	$fe00		//Using ROM function here to save a few bytes...		
						//LDA	$1c0c
						//ORA #$e0
						//STA $1c0c
						//LDA #$00
						//STA $1c03
						//RTS
		jsr	ToggleLED	//Trun LED off - no proper ROM function for this unfortunately...

RcvCheck:	jsr	NewByte		//More blocks to write?

		tax
		bne	NextBlock

		lda	#<FetchJmp	//Disk writing is done, restore GCR loop
		sta	FetchAgain+1

		ldx	#$44
		stx	DirSector	//Resetting DirSector to ensure next index-based load refetches the directory
RestoreLoop:
		lda	$023b,x
		bmi	*+4
		ora	#$08		//Restore H2STab and GCR Tab8
		sta	$02bb,x
		dex
		bpl	RestoreLoop
		jmp	CheckATN	//Back to loading :)

//----------------------------------
//		Receive 1 byte at a time
//----------------------------------

NewByte:	ldx	#$94		//Make sure C64 is ready to send
		jsr	CheckPort
		lda	#$80		//$dd00=#$9b, $1800=#$94
		ldx	#busy		//=#$10 (AA=1, CO=0, DO=0)
		jsr	RcvByte		//OK to use stack here
		
		ldx	#$95		//Wait for C64 to signal transfer complete
CheckPort:	cpx	$1800
		bne	*-3
		rts

//----------------------------------
//		Endcode $104 bytes to $145 GCR bytes
//----------------------------------

Encode:		lda	#$bb		//Reset BufLoc Lo Byte
		sta	BufLoc+1

		lax	ZP07		//X = Bitcounter for encoded bytes: #$07
		jsr	GCREncode	//A = First byte of Data Block: #$07

EncodeLoop:	lda	$0700		//Encode 256 data bytes
		jsr	GCREncode
		
		inc	EncodeLoop+1
		bne	EncodeLoop

		lda	ChkSum		//Endcode Checksum
		jsr	GCREncode
		jsr	GCREncode	//Encode two tail 00s, A=00 here

//----------------------------------
//		Convert nibbles to GCR codes
//----------------------------------

GCREncode:	pha
		lsr
		lsr
		lsr
		lsr
		jsr	GCRize		//Convert high nibble to 5-bit GCR code first
		pla			//Then low nibble next
		and	#$0f
GCRize:		tay
		lda	$f77f,y
		asl
		asl
		asl			//Move 5 GCR bits to the left side of byte
		ldy	#$05		//Bitcounter for GCR codes
NextBit:	asl
BufLoc:		rol	$02bb		//Current GCR buffer location, reset at the beginning
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