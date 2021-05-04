//TAB=8
//----------------------------------------------------------------------------------------
//	SPARKLE 2
//	Inspired by Lft's Spindle and Krill's Loader
//	Drive Code
//	Tested on 1541-II, 1571, 1541 Ultimate-II+, Oceanic, and THCM's SX-64
//----------------------------------------------------------------------------------------
//	Memory Layout
//
//	0000	0083	ZP GCR Tabs and variables
//	0084	00ff	GCR Loop
//	0100	01ff	Data Buffer on Stack
//	0200	03f4	GCR Tabs with code interleaved
//	0303	06ed	Drive Code ($12 bytes free)
//	0700	07ff	Directory (4 bytes per entry, 64 entries per dir block, 2 dir blocks on disk)
//
//	Layout at Start
//
//	0300	03f4	GCR Tabs			block 0
//	03f5	05ff	Code				blocks 1-2
//	0600	06ff	ZP GCR Tabs and GCR loop	block 3
//	0700	07ff	Init Code			block 4
//
//	Layout in PRG
//
//	2300	23f4	GCR Tabs			block 0
//	23f5	26ed	Drive Code			block	1-3 3	-> block 5	
//	2700	27ff	ZP GCR tabs and GCR loop	block 4	-> block 3
//	2800	28f4	Init code			block 5	-> block 4
//
//----------------------------------------------------------------------------------------
//	Track 18
//
//	00	BAM
//	01-06	DirArt
//	07-10	C64 Code
//	11-16	Drive Code
//	17-18	Internal Directory
//
//----------------------------------------------------------------------------------------
//	Flip Info in BAM (EOR-transformed):
//
//	Disk:		Buffer:  Function:
//	18:00:$ff	$0101	   DiskID	(for flip detection, compare to NextID @ $21 on ZP)
//	18:00:$fe	$0102	   NextID	(will be copied to NextID on ZP after flip =#$80 if no more flips)
//	18:00:$fd	$0103	   IL3R		(will be copied to $60)
//	18:00:$fc	$0104	   IL2R		(will be copied to $61)
//	18:00:$fb	$0105	   IL1R		(will be copied to $62)
//	18:00:$fa	$0106	   IL0		(will be copied to $63, used to update nS)
//	18:00:$f9	$0107	   IL0R		(will be copied to $64)
//
//	18:00:$f8	$0108	   LastT	(will be copied to NoFlipTab)
//	18:00:$f7	$0109	   LastS	(will be copied to NoFlipTab)
//	18:00:$f6	$010a	   SCtr		(will be copied to NoFlipTab)
//	18:00:$f5	$010b	   BPtr		(will be copied to NoFlipTab)
//
//	18:00:$f4	$010c	   IncSaver	(will be copied to IncSaver)
//
//	18:00:$f3	$010d	   ProductID1
//	18:00:$f2	$010e	   ProductID2
//	18:00:$f1	$010f	   ProductID3
//
//----------------------------------------------------------------------------------------
//	Internal Directory Structure
//
//	00	Track
//	01	First sector on track after track change (NOT first sector of bundle, will be used to mark fetched sectors)
//	02	Sector Counter (sectors left unfetched, will be used to mark fetched sectors and find first sector of bundle)
//	03	Bundle Pointer (will be copied to last byte of first block, used by depacker to find start of bundle within block)
//
//----------------------------------------------------------------------------------------

//Constants:
.const	CSV		=$04	//Checksum Verification Counter Default Value

.const	DO		=$02
.const	CO		=$08
.const	AA		=$10
.const 	busy		=AA	//DO=0,CO=0,AA=1	$1800=#$10	dd00=010010xx (#$4b)
.const	ready		=CO	//DO=0,CO=1,AA=0	$1800=#$08	dd00=100000xx (#$83)

.const	Sp		=$52	//Spartan Stepping constant (=82*72=5904=$1710=$17 bycles delay)

//ZP Usage:
.const	cT		=$00	//Current Track
.const	cS		=$01	//Current Sector
.const	nS		=$02	//Next Sector
.const	BlockCtr	=$03	//No. of blocks in Bundle, stored as the last byte of first block
.const	WantedCtr	=$08	//Wanted Sector Counter
.const	Random		=$18	//Marks random file access
.const	VerifCtr	=$19	//Checksum Verification Counter
.const	NewBundle	=$23	//#$00->#$01, stop motor if #$01
.const	StepDir		=$28	//Seek Direction
.const	LastBlock	=$29	//#$01 if last block of a Bundle is fetched, otherwise $00
.const	WList		=$3e	//Wanted Sector list ($3e-$52) (00=unfetched, [-]=wanted, [+]=fetched)
.const	DirSector	=$56	//Initial value=#$c5 (<>#$10 or #$11)
.const	EoD		=$5e	//End of Disk flag, only used with sequential loading

.const	LastT		=$60	//Track number of last block of a Bundle, initial value=#$01
.const	LastS		=$61	//Sector number of last block of a Bundle, initial value=#$00
.const	SCtr		=$62	//Sector Counter, sectors left unfetched in track
.const	BPtr		=$63	//Bundle Pointer within block for random access

.const	NBC		=$66	//New Block Count temporary storage

.const	StepTmrRet	=$68	//Indicates whether StepTimer code is called in subroutine
.const	BitRateRet	=$6e	//Indicates	whether Store code is called in subroutine
.const	TrackChg	=$78	//Indicates whether Tranck change is needed AFTER CATN (last block of bundle=last sector of track)

.const	NextID		=$7e	//Next Side's ID - will be updated from 18:00:$fd of next side
.const	ILTab		=$7f	//Inverted Custom Interleave Table
.const	IL0		=$82	//for nS

.const	LM1		=$10	//=LMT1 ($037d)
.const	LM2		=$20	//=LMT2 ($0383)
.const	LM3		=$30	//=LMT3 ($038b)
.const	LM4		=$38	//=LMT4 ($039d)
.const	LM5		=$69	//=LMT5 ($03bd)
.const	LM6		=$79	//=LMT6 ($03c1)

.const	ZP01ff		=$58	//$58/$59 = $01ff
.const	ZP0101		=$59	//$59/$5a = $0101
.const	ZP12		=$54	//=#$12
.const	ZP07		=$57	//=#$07
.const	ZP0f		=$55	//=#$0f
.const	ZP3e		=$32	//=#$3e
.const	ZPf8		=$7c	//=#$f8

.const	IncSaver	=$74	//=#$02 if Saver Code is included, otherwise #$00
.const	SaverCode	=$76	//Indicates whether Saver Code Drive code is in the buffer

.const	SFetch		=$0128	//$0127
.const	SHeader		=$012d	//$012c

//Tabs:
.const	Tab200		=$0200

//GCR Decoding Tabs:
.const	Tab1		=Tab300+4
.const	Tab2		=Tab200
.const	Tab3		=$00
.const	Tab4		=Tab300
.const	Tab5		=$00
.const	Tab6		=$01
.const	Tab7		=Tab300
.const	Tab8		=Tab200+1

//Other Tabs:
.const	H2STab		=Tab200+$0d	//HiNibble-to-Serial Conversion Tab ($10 bytes total, $10 bytes apart)
.const	BitShufTab	=Tab300+$01	//Bit Shuffle Tab (16 bytes total, insterspersed on page)
.const	GCRZoneTab	=Tab300+$a0	//To adjust GCR loop length

//--------------------------------------

*=$23d1	"Drive Code"

.pseudopc $03d1	{

		beq	Fetch		//We are staying on the same Track, skip track change
		nop	#$14		//Skip GCR Tab1 value
		bcs	SkipStepDn
		nop	#$5a		//Skip GCR Tab4 value
		eor	#$ff
		nop	#$94		//Skip GCR Tab1 value
		adc	#$01
		ldy	#$03		//Y=#$03 -> Stepper moves Down/Outward
		sty	StepDir		//Store stepper direction UP/INWARD (Y=#$01) or DOWN/OUTWARD (Y=#$03)
		bne	$03f1

//$03e5
.byte	$d5,$f5,$a9,$5c,$d5,$f5,$95,$f4,$d5,$f5,$43,$56
//$03f1

SkipStepDn:	asl			//Y=#$01 is not stored - it is the default value which is restored after every step
		tay			//Y=Number of half-track changes
		nop	#$54		//Skip GCR Tab1 value

//--------------------------------------
//		Multi-track stepping
//--------------------------------------

		inc	StepTmrRet	//#$00->#$01 - signal need for RTS 

		jsr	StepTmr		//Move head to track and update bitrate (also stores new Track number to cT and calculates SCtr)

		lda	Spartan+1
		sta	$1c00		//Store bitrate

		lda	#CSV
		sta	VerifCtr	//Verify track after head movement

//--------------------------------------
//		Fetch Code
//--------------------------------------

Fetch:		lda	VerifCtr	//If checksum verification needed at disk spin up...
		bne	FetchData	//...then fetch any data block instead of a Header
FetchHeader:
		ldy	#<HeaderJmp	//Checksum verification after GCR loop will jump to Header Code
		ldx	#$04		//4 bytes to stack
		lda	#$52		//First byte of Header
		bne	Presync		//Skip Data Block fetching

FetchData:	ldy	#<DataJmp	//Checksum verification after GCR loop will jump to Data Code
		ldx	#$00		//256 bytes to stack
		lda	#$55		//First byte of Data

//--------------------------------------

Presync:	txs			//Header: $0104,$0103..$0101, Data: $0100,$01ff..$0101
		sty.z	ModJmp+1	//Update Jump Address on ZP

		ldy	#$ff

		bit	$1c00		//We happen to be in a SYNC mark right now, skip it
		bpl	*-3

Sync:		bit	$1c00		//Wait for next SYNC
		bmi	Sync

		cmp	$1c01		//Sync byte - MUST be read (VICE bug #582), not necessarily #$ff
		clv
		bvc	*		//02
		cmp	$1c01		//06*	Read1 = 11111222 @ (00-25), which is 01010|010(01) for Header
		clv			//08					  or 01010|101(11) for Data
		bne	Sync		//10	First byte of Header/Data is discarded

		sty.z CSum+1		//13	Y=#$ff, we are working with inverted GCR Tabs, checksum must be inverted
		iny			//15	Y=#$00
		lda	cT		//18
		cmp	#$12		//20	Track number >=18?
		bcc	*+4		//23/22	We need different timing for Zone 0 and Zones 1-3
		cmp	(Zone0+1),y	//--/27	4 cycles difference
		sta	(Zone0+1),y	//29/33	Any value will do in A as long as $0102 and $0103 are the same
		sta	(Zone0+4),y	//35/39	$0102 and $0103 will actually contain the current track number
		ldx	ZP3e		//38/42	X=#$3e		[26-51  28-55  30-59  32-63]
		lda	$1c01		//42/46 *Read2 = 22333334 @ 42/-9  46/-9  46/-13 46/+14
		sax.z	t3+1		//45/49	t3+1 = 00333330
		lsr			//47/51	C=4 - needed for GCR loop
		lax	#$00		//49/53	Clear A, X - both needed for first 2 EORs after BNE in GCR loop
		iny			//51/55	Y=#$01 (<>#$00 for BNE to work after jump in GCR loop)
		jmp	GCREntry	//54/58	Same number of cycles before BNE as in GCR loop

//--------------------------------------
//		Got Header
//--------------------------------------

Header:		tay			//A=0 here
		lda	(Zone0+1),y	//= lda $0102
		jsr	ShufToRaw	//check current track (only 4 bytes are used on stack, JSR is safe here)
		cmp	cT
		bne	FetchHeader

		lda	(Zone0+4),y	//= lda $0103
		jsr	ShufToRaw	//check current sector (only 4 bytes are used on stack, JSR is safe here)
		tax			//A=X=sector fetched
		ldy	WList,x
		bpl	FetchHeader

		stx	cS

		cpx	LastS		//Is this the last sector of a bundle?
		bne	FetchData

		lda	cT
		cmp	LastT
		bne	FetchData	//A<>00, not the last sector, store sector in cS and fetch data 

		lax	WantedCtr	//Last sector fetched -> check how many sectors are left to load
		dex
ToFHeader:	bne	FetchHeader	//more than one sector left on Wanted List, skip last sector, fetch next

		sta	LastBlock	//-> #$01, we have the last block of the bundle	
		beq	FetchData	//ALWAYS	

//--------------------------------------
//		Checksum Verification
//--------------------------------------

DataVerif:	dec	VerifCtr
		bpl	Fetch+2		//ALWAYS, fetch next data block for checksum verification (skipping headers if VerifCtr>0)

//--------------------------------------
//		Disk ID Check		//Y=#$00 here
//--------------------------------------

Track18:	cpx	#$10		//Drive Code Block 3 (Sector 16) or Dir Block (Sectors 17-18)?
		bcc	CheckID		//No

ToCD:		jmp	CopyCode	//Sector 15 (Block 3) - copy it from the Buffer to its place, Y=#$00 here, WantedCtr=1
					//Will be changed to JMP CopyDir after Block 3 copied

CheckID:	lax	NextID		//Side is done, check if there is a next side
		bpl	Flip		//Disk ID = #$00-#$7e, if NextID > #$7f - no more disks

//--------------------------------------
//		No more disks, so return with a "dummy" load
//--------------------------------------

NoFlip:		ldx	#$04		//There are no more disk sides, so let's do a "dummy" load to allow the loader to return
NFLoop:		lda	NoFlipTab-1,x
		sta	LastT-1,x
		dex
		bne	NFLoop
		stx	NewBundle	//X=#$00, clear NewBundle, EoD is cleared on both sequential and random sides
		inc	Random		//Set Random
		jmp	RandomNoFlip	//Y remains #$00 here, needed after JMP

//--------------------------------------
//		Flip Detection		//Y=$#00 here
//--------------------------------------

Flip:		cmp	(ZP0101),y	//DiskID, compare it to NextID in memory, EOR-transformed
		bne	ToFHeader	//ID mismatch, fetch again until flip detected

		ldy	#$03
ProdIDLoop:	lda	$010c,y		//Also compare Product ID, only continue if same
		cmp	ProductID-1,y
		bne	ToFHeader	//Product ID mismatch, fetch again until same
		dey
		bne	ProdIDLoop

//--------------------------------------

		ldy	#$06		//Flip detected, copy Next Side Info, data is EOR-transformed
		sty	DirSector	//Invalid value to trigger reload of the directory of the new disk side
CopyBAM:	lda	(ZP0101),y	//= LDA $0101,y
		sta	NextID-1,y 	//($0101=DiskID), $0102=NextID, $103=IL3R, $104=IL2R, $105=IL1R, $106=IL0, $107=IL0R
		cpy	#$05
		bcs	SkipNFT

		lda	$0107,y		//NoFlipTab needs to be updated here too ($0108-$010b)
		sta	NoFlipTab-1,y
SkipNFT:	dey
		bne	CopyBAM
		
		lda	$010c		//Value (#$00 vs. #$02) indicates whether Saver Code is included on this disk side
		sta	IncSaver

		tya
		jmp	CheckDir	//Y=A=#$00

//--------------------------------------

ToCATN:		jmp	CheckATN

//--------------------------------------
//		Got Data
//--------------------------------------

Data:		ldy	VerifCtr	//Checksum Verification Counter
		bne	DataVerif	//If counter<>0, go to verification loop

		ldx	cS		//Current Sector in Buffer
		lda	cT		//Y=#$00 here
		cmp	#$12		//If this is Track 18 then we are fetching Block 3 or a Dir Block or checking Flip Info
		beq	Track18		//We are on Track 18

//--------------------------------------
//		Update Wanted List
//--------------------------------------

		sta	WList,x		//Sector loaded successfully, mark it off on Wanted list (A=Current Track - always positive)
		dec	SCtr		//Update Sector Counter

//--------------------------------------
//		Check Saver Code
//--------------------------------------

		lsr	SaverCode
		bcc	*+5
		jmp	$0100		//Saver Code fetched, execute it in buffer

//--------------------------------------
//		Check Last Block	//Y=#$00 here
//--------------------------------------

		lsr	LastBlock
		bcc	ChkNewBndl	//C=0 - not the last block

		lda	(ZP01ff),y	//Save new block count for later use
		sta	NBC
		lda	#$ff		//And delete it from the block
		sta	(ZP01ff),y	//So that it does not confuse the depacker...

		lsr	Random		//Check if this is also the first block of a randomly accessed bundle
		bcc	ChkNewBndl

		sta	$0100		//This is the first block of a random bundle, delete first byte
		lda	BPtr		//Last byte of bundle will be pointer to first byte of new Bundle
		sta	(ZP0101),y

//--------------------------------------

ChkNewBndl:	lda	NewBundle
		bne	ToCATN

//--------------------------------------
//
//		Early Track change	//If this is the last sector on a track, track change can be started here...
//					//...except if this is the last block of a bundle...
//--------------------------------------//...because we don't know if the next call will be sequential or random

//--------------------------------------
//		Check Sector Count
//--------------------------------------

CheckSCtr:	lda	SCtr		//Any more sectors? A=#$00 here
		bne	ToCATN

//--------------------------------------
//		Prepare seeking
//--------------------------------------
					//Otherwise, clear wanted list and start seeking
PrepSeek:	jmp	JmpClrList	//Y=#$00 here	

//--------------------------------------

NextTrack:	ldx	cT		//All blocks fetched in this track, so let's change track
		ldy	#$81		//Prepare Y for 0.5-track seek

		lda	NBC		//Very last sector?
		beq	ToCATN		//Yes, skip stepping, finish transfer

		inx			//Go to next track

ChkDir:		cpx	#$12		//next track = Track 18?, if yes, we need to skip it
		bne	Seek		//0.5-track seek, skip setting timer

		inx			//Skip track 18
		inc	nS		//Skipping Dir Track will rotate disk a little bit more than a sector...
		inc	nS		//...(12800 cycles to skip a track, 10526 cycles/sector on track 18)...
					//...so start sector of track 19 is increased by 2
		ldy	#$83		//1.5-track seek, set timer at start

//--------------------------------------
//		Stepper Code		X=Wanted Track
//--------------------------------------

StepTmr:	lda	#$98
		sta	$1c05

Seek:		lda	$1c00
PreCalc:	//anc	#$1b		//ANC	DOES NOT WORK ON ULTIMATE-II+
		and	#$1b		//So we use AND+CLC
		clc
		adc	StepDir		//#$03 for stepping down, #$01 for stepping up
		ora	#$0c		//LED and motor ON
		cpy	#$80
		beq	BitRate		//This was the last half step precalc, leave Stepper Loop without updating $1c00
		sta	$1c00

		dey
		cpy	#$80
		beq	PreCalc		//Ignore timer, precalculate last half step and leave Stepper Loop (after 0.5/1.5 track changes)

StepWait:	bit	$1c05
		bmi	StepWait

		cpy	#$00
		bne	StepTmr

//--------------------------------------
//		Set Bitrate
//--------------------------------------

BitRate:	ldy	#$11		//Sector count=17
		cpx	#$1f		//Tracks 31-40, speed zone 0
		bcs	RateDone	//Bitrate=%00

		iny			//Sector count=18
		cpx	#$19		//Tracks 25-30, speed zone 1
		bcs	BR20		//Bitrate=%01

		iny			//Sector count=19
		ora	#$40		//Bitrate=%10
		cpx	#$12		//Tracks 18-24, speed zone 2
		bcs	RateDone
					//Tracks 01-17, speed zone 3
		ldy	#$15		//Sector count=21
BR20:		ora	#$20		//Bitrate=%11

//--------------------------------------
//		Update variables
//--------------------------------------

RateDone:	sta	Spartan+1
		txa			//A=new track number

		sty	MaxSct1+1	//Update Max No. of Sectors in this Track
		sty	MaxSct2+1	//Three extra bytes here but faster loop later

		ldx	ILTab-$11,y	//Inverted Custom Interleave Tab
		stx	IL+1

		ldx	#$01		//Extra subtraction for Zone 3
		stx	StepDir		//Reset stepper direction to Up/Inward here
		cpy	#$15
		beq	*+3
		dex
		stx	SubSct+1

		lsr	BitRateRet	
		bcc	StoreTr	
		rts	

StoreTr:	sta	cT		//Store new track number
		lda	Random
		bne	*+4
		sty	SCtr		//Reset Sector Counter

		ldx	GCRZoneTab,y	//Adjust GCR Loop length
		cpx.z	ModGCR+1
		beq	SkipPatch	//Skip loop patch if same zone
		stx.z	ModGCR+1

//--------------------------------------
//		GCR loop patch
//--------------------------------------

		lax	ZP0101		//A=X=#$01
		cpy	#$15
		beq	*+4
		lda	#$03		//Improve rotation speed tolerance in Zones 1-3
		tay
LMLoop:		lda	(LM1),y		//by adding 4 extra cycles between Read1 and Read2
		sta.z	LoopMod1,x
		lda	(LM2),y
		sta.z	LoopMod2,x
		lda	(LM3),y
		sta.z	LoopMod3,x
		lda	(LM4),y		//and 2 more cycles between Read3 and Read4
		sta.z	LoopMod4,x
		lda	(LM5),y
		sta.z	LoopMod5,x
		lda	(LM6),y
		sta.z	LoopMod5+1,x
		dey
		dex
		bpl	LMLoop

SkipPatch:	lsr	StepTmrRet
		bcc	*+3
		rts

		lsr	TrackChg	//Are we changing track after CATN?
		bcc	CheckATN	//No, goto CATN
		jmp	StartTr		//Yes, jump to transfer

//--------------------------------------

Reset:		jmp	($fffc)

//--------------------------------------
//		Wait for C64
//--------------------------------------

CheckATN:	lda	$1c00		//Fetch Motor and LED status
		ora	#$08		//Make sure LED will be turned back on when we restart
		tax			//This need to be precalculated here, so that we do not affect Z flag at Restart

		ldy	#$64		//100 frames (2 seconds) delay before turning motor off (#$fa for 5 sec)
DelayOut:	lda	#$4f		//Approx. 1 frame delay (20000 cycles = $4e20 -> $4e+$01=$4f)
		sta	$1c05		//Start timer, wait 2 seconds before turning motor off
DelayIn:	lda	$1c05
		bne	ChkLines
		dey
		bne	DelayOut
		lda	#$73		//Timer finished, turn motor off
		sax	$1c00
		lda	#<CSV		//Reset Verification Counter
		sta	VerifCtr	//I.e. when motor restarts, first we verify proper read

ChkLines:	lda	$1800		
		bpl	Reset		//ATN released - C64 got reset, reset the drive too
		alr	#$05		//A=#$00/#$02 after this, if C=1 then no change
		bcs	DelayIn

					//C=0, file requested
Restart:	stx	$1c00		//Restart Motor and turn LED on if they were turned off
		beq	SeqLoad		//A=#$00 - sequential load
					//A=#$02 - random load
//--------------------------------------
//
//		Random File Access
//
//--------------------------------------

GetByte:	lda	#$80		//$dd00=#$9b, $1800=#$94
		ldx	#busy		//X=#$10 (AA=1, CO=0, DO=0)

		jsr	RcvByte		//OK to use stack here

		cmp	#$ff
		beq	Reset		//C64 requests drive reset

		ldy	#$00		//Needed later (for FetchBAM if this is a flip request, and FetchDir too)
		sty	EoD		//EoD needs to be cleared here
		sty	NewBundle	//So does NewBundle

		asl
		bcs	NewDiskID	//A=#$80-#$ff, Y=#$00 - flip disk
		beq	CheckDir	//A=#$00, skip Random flag
		inc	Random
CheckDir:	ldx	#$11		//A=#$00-#$7f, X=#$11 (dir sector 17) - DO NOT CHANGE TO INX, IT IS ALSO A JUMP TARGET!!!
		asl
		sta	DirLoop+1	//Relative address within Dir segment
		bcc	CompareDir
		inx			//A=#$40-#$7f, X=#$12 (dir sector 18)
		cmp	#$f8		//Index=#$7e - check if we are loading the Saver Code
		bne	CompareDir
		lda	IncSaver	//=#$02 if Saver Code is included on Disk, #$00 otherwise
		sta	SaverCode

CompareDir:	cpx	DirSector	//Dir Sector, initial value=#$c5		
		beq	ReadDir		//Is the needed Dir Sector fetched?

		stx	DirSector	//No, store new Dir Segment index and fetch directory sector
		stx	LastS		//Also store it in LastS to be fetched
		jmp	FetchDir	//ALWAYS, fetch directory, Y=#$00 here (needed)

ReadDir:	ldx	#$03
DirLoop:	lda	$0700,x
		sta	LastT,x
		dex
		bpl	DirLoop

RandomNoFlip:
		jsr	ClearList	//Clear Wanted List, Y=00 here

		inc	BitRateRet

		tax			//X=A=LastT
		lda	Spartan+1
		pha
		jsr	BitRate		//Update Build loop, Y=MaxSct after this
		pla			//Also find interleave and sector count for requested track
		sta	Spartan+1

		ldx	LastS		//This is actually the first sector on the track here
		tya			//A=MaxSct
		sec
		sbc	SCtr		//Remaining sectors on track
		tay			//Y=already fetched sectors on track
		beq	SkipUsed	//Y=0, we start with the first sector, skip marking used sectors
		dec	MarkSct		//Change STA ZP,x to STY ZP,x ($95 -> $94) (A=$ff - wanted, Y>#$00 - used)
		jsr	Build		//Mark all sectors as USED before first sector to be fetched
		inc	MarkSct		//Restore Build loop

SkipUsed:	iny			//Mark the first sector of the new bundle as WANTED
		jsr	Build		//A=#$ff, X=Next Sector, Y=#$00 after this call
		sty	LastBlock	//Reset LastBlock (LSR would also work but STY is faster)

		lax	LastT
		jmp	GotoTrack	//X=desired Track, Y=#$00

//--------------------------------------

NewDiskID:	lsr			//Next Disk's ID for flip detection
		sta	NextID

ToFetchBAM:	jmp	FetchBAM	//Go to Track 18 to fetch Sector 0 (BAM) for Next Side Info, A=#$12, Y=#$00

//--------------------------------------
//
//		Sequential Loading
//
//--------------------------------------

SeqLoad:	tay			//A=#$00 here -> Y=#$00
		lsr	EoD		//End of Disk?
		bcs	ToFetchBAM	//If Yes, load BAM, otherwise start transfer

//--------------------------------------
//
//		Check if Track change is needed here
//
//--------------------------------------

		lsr	NewBundle
		bcc	StartTr
		
		inc	TrackChg
		jmp	CheckSCtr	//Needs Y=#$00, JSR cannot be used
		
StartTr:	ldy	#$00		//transfer loop counter
		ldx	#$ef		//bit mask for SAX, instead of #$0a
		lda	#ready		//A=#$08, ATN=0, AA not needed

//--------------------------------------
//		67-cycle transfer loop
//--------------------------------------

Loop:		bit	$1800		//07,08,09,10	Will fall through when entering loop
		bpl	*-3		//11,12
W4:		sta	$1800		//13,14,15,16	(17 cycles)
					//					Spartan Loop:
SLoop:		lda	$0100,y		//00,01,02,03				17,18,19,20
		dey			//04,05					21,22
		bit	$1800		//06,07,08,09				23,24,25,26
		bmi	*-3		//10,11		X=#$ef			27,28
W1:		sax	$1800		//12,13,14,15	(16 cycles)		29,30,31,32	(33 cycles)

		inx			//00,01		X=#$f0, saves 1 byte...
		axs	#$00		//02,03		X=X AND A
		asl			//04,05
		ora	#$10		//06,07		set AA=1
		bit	$1800		//08,09,10,11
		bpl	*-3		//12,13
W2:		sta	$1800		//14,15,16,17	(18 cycles)

		lda	H2STab,x	//00,01,02,03
		ldx	#$ef		//04,05		instead of #$0a
		bit	$1800		//06,07,08,09
		bmi	*-3		//10,11
W3:		sax	$1800		//12,13,14,15	(16 cycles)

		lsr			//00,01
ByteCt:		cpy	#$100-Sp	//02,03		Sending #$52 bytes before Spartan Stepping
		bne	Loop		//04,05,06		#$52 x 72 = #$17 bycles*, #$31 bycles left for 2nd halftrack step and settling
					//			*actual time #$18-$1a+ bycles, and can be (much) longer
					//			 if C64 is not immediately ready to receive fetched block
					//			 thus, the drive may actually stop on halftracks before transfer continues

//--------------------------------------

		bit	$1800		//06,07,08,09
		bpl	*-3		//10,11
W4L:		sta	$1800		//12,13,14,15	(16 cycles)	Last 2 bits completed

//--------------------------------------
//	SPARTAN STEPPING (TM)				<< - Uninterrupted data transfer across adjacent tracks - >>
//--------------------------------------		Transfer starts 1-2 bycles after first halftrack step

Spartan:	lda	#$00		//00,01		Last halftrack step is taken during data transfer
		sta	$1c00		//02,03,04,05	Update bitrate and stepper with precalculated value
		tya			//06,07		Y=#$ae or #$00 here
		eor	#$100-Sp	//08,09		#$31 bycles left for the head to take last halftrack step...
		sta	ByteCt+1	//10,11,12,13	... and settle before new data is fetched
ChkPt:		beq	SLoop		//14,15,16	Additional 17 cycles here per block transferred

.print ""
.print "Loop:  $0" + toHexString(Loop)
.print "ChkPt: $0" + toHexString(ChkPt)

.if ([>Loop] != [>ChkPt])	{
.error "ERROR!!! Transfer loop crosses pages!!!"
} else	{
.print "Transfer loop on a single page :)"
}

//--------------------------------------

		lda	#busy		//16,17 	A=#$12
		bit	$1800		//18,19,20,21	Last bitpair received by C64?
		bmi	*-3		//22,23
		sta	$1800		//24,25,26,27	Transfer finished, send Busy Signal to C64

		bit	$1800		//Make sure C64 pulls ATN before continuing
		bpl	*-3		//Without this the next ATN check may fall through
					//resulting in early reset of the drive

		jsr	ToggleLED	//Transfer complete - turn LED off, leave motor on

//--------------------------------------
//		Update Block Counter
//--------------------------------------

		dec	BlockCtr	//Decrease Block Counter
		bne	ChkWCtr

UpdateBCtr:	inc	NewBundle	//#$00 -> #$01, next block will be first of next Bundle
		lda	NBC		//New Block Count
		sta	BlockCtr
		bne	ChkWCtr		//A = Block Count

		inc	EoD		//New BCtr=#$00 - this is the end of the disk
		jmp	CheckATN	//No more blocks to fetch in sequence, wait for next loader call
					//If next loader call is sequential -> will go to BAM for flip check/reset
					//If next loader call is random -> will load requested file

//--------------------------------------

ChkWCtr:	dec	WantedCtr	//If we just updated BlockCtr then WantedCtr will be 0
		bne	ToFetch		//If there are more blocks on the list then fetch next

//--------------------------------------
//		Build wanted list	//A=#$00, X=#$ef here
//--------------------------------------
		
		ldy	SCtr		//Check if we have less unfetched sectors left on track than blocks left in Bundle	
		cpy	BlockCtr
		bcc	NewWCtr		//Pick the smaller of the two for new Wanted Counter
		ldy	BlockCtr
		ldx	cT		//If SCtr>=BlockCtr then the Bundle will end on this track...
NewWCtr:	sty	WantedCtr	//Store new Wanted Counter (SCtr vs BlockCtr whichever is smaller)
		stx	LastT		//...so save current track to LastT, otherwise put #$ef to corrupt EOR result in check
		
		ldx	nS		//Preload Next Sector in chain
		jsr	Build		//Build new wanted list (buffer transfer complete, JSR is safe)
ToFetch:	jmp	Fetch		//then fetch

EndOfDriveCode:

.if (EndOfDriveCode > $0700)	{
.error "Error!!! Drive code too long!!!"
}

//--------------------------------------

}

*=$2800	"Installer"

.pseudopc	$0700	{

//--------------------------------------
//		Initialization
//--------------------------------------

CodeStart:	sei
		lda	#$7a
		sta	$1802		//0  1  1  1  1  0  1  0  Set these 1800 bits to OUT (they read back as 0)
		lda	#busy
		sta	$1800		//0  0  0  1  0  0  1  0  CO=0, DO=1, AA=1 This reads as #$43 on $dd00
					//AI|DN|DN|AA|CO|CI|DO|DI This also signals that the drive code has been installed
//--------------------------------------
//		Generate Various Tabs
//--------------------------------------

		ldx	#$00		//Technically, this is not needed - X=$00 after loading all 5 blocks
MakeZPTab:	lda	ZPTab,x		//Copy Tabs 3, 5 & 6 and GCR Loop from $0600 to ZP
		sta	$00,x

MakeTab8:	lda	Tab200+$20,x	//Prepare Tab8
		sta	Tab200,x	//Copy from $0300-$031f to $0200-$02ff
		dex
		bne	MakeZPTab

//----------------------------
//		Copy code and tabs
//----------------------------

		ldx	#<BLEnd-BL
CBL:		lda	CD+CDEnd-CopyDir-1,x		//Copy code to $0282, #$26 bytes
		sta	BL-1,x
		lda	CD+CDEnd-CopyDir+BLEnd-BL-1,x	//Copy start code to $0300, #$26 bytes
		sta	CStart-1,x
SkipCode:	cpx	#<CDEnd-CopyDir+1
		bcs	SkipCD
		lda	CD-1,x				//Copy code to $0202
		sta	CopyDir-1,x
SkipCD:		cpx	#$08
		bcs	SkipT2
		lda	T2Base1-1,x			//Prepare Tab2
		sta	Tab2+$40,x
		lda	T2Base2-1,x
		sta	Tab2+$60,x
SkipT2:		dex
		bne	CBL

//--------------------------------------
//		Make H2STab
//--------------------------------------

MakeH2STab:	lda	#$50		//Prepare HiNibble-to-Serial Conversion Tab, X=#$00 at start
		sax	Bits64+1	// .6.4....		Last byte of wanted list could be used here
		txa			// 76543210		as a temporary ZP address. We are on track 18
		alr	#$a0		// .7.5....		which only has 19 sectors, so the last 2 bytes
		sec			//!.7.5....		of the Wanted List are not used during block 3
		ror			// !.7.5...		and directory fetch
Bits64:		ora	#00		// !6745...
		lsr			// .!6745..
		lsr			// ..!6745.
		sta	H2STab,x	// 7654.... -> ..!6745.
		txa
		axs	#$10
		bne	MakeH2STab	//X=#$00 after this

//--------------------------------------

		lda	#$ee		//Read mode, Set Overflow enabled
		sta	$1c0c

					//Turn motor and LED on
		lda	#$d6		//1    1    0    1    0*   1*   1    0	We always start on Track 18, this is the default value
		sta	$1c00		//SYNC BITR BITR WRTP LED  MOTR STEP STEP	Turn motor and LED on

		jmp	Fetch		//Fetching block 3 (track 18, sector 16) WList+$10=#$ff, WantedCtr=1
					//A,X,Y can be anything here
T2Base1:
.byte	$f6,$db,$df,$d9,$dd,$d8,$dc
T2Base2:
.byte	$6f,$d3,$d7,$d1,$d5,$d0

//--------------------------------------
//		Copy Block 3 to $0600
//--------------------------------------

CopyCode:
CCLoop:		lda	$0100,y		//Code Block 3 is EOR transformed and rearranged, just copy it
		sta	$0600,y		//Y=00 at start
		iny
		bne	CCLoop
		lda	#<CopyDir	//Change JMP CopyCode to JMP CopyDir
		sta	ToCD+1
		lda	#>CopyDir
		sta	ToCD+2
		tya			//A=#$00 - Bundle #$00 to be loaded
		jmp	CheckDir	//Load 1st Dir Sector and then first Bundle, Y=A=#$00
CD:
}

//--------------------------------------
//		Code to $200
//--------------------------------------

.pseudopc	$0200	{
		//Directory sectors are EOR transformed and resorted, just copy them, no need for EOR transforming here
		//Y=#$00 before loop
CopyDir:
CDLoop:		lda	$0100,y		//00,01,02		pla			02
		sta	$0700,y		//03,04,05		tsx			03
		iny			//06			sta	$0700,x		04,05,06
		bne	CDLoop		//07,08			bne	CDLoop		07,08
		jmp	ReadDir		//09,0a,0b		ldx	DirSector	09,0a
ClrRTS:		rts			//0c			jmp	ReadDir		0b,0c,0d
		.byte $00		//0d
//--------------------------------------
JmpClrList:	sec			//0e
		.byte	$80		//0f	nop #$xx to skip clc
ClearList:	clc			//10
		ldx	#$14		//11,12
ClrWList:	sty	WList,x		//13,14	Y=00, clear Wanted Block List
		dex			//15
		bpl	ClrWList	//16,17
		bcc	ClrRTS		//18,19
		jmp	NextTrack	//16,1b,1c
//--------------------------------------
CDEnd:
}

CB:

//--------------------------------------
//		Code to $280
//--------------------------------------

.pseudopc	$0280	{
BL:
NxtSct:		inx			//80
Build:		iny			//81		Temporary increase as we will have an unwanted decrease after bne
		lda	#$ff		//82,83	Needed if nS = last sector of track and it is already fetched			
		bne	MaxSct1		//84,85	Branch ALWAYS
ChainLoop:	lda	WList,x		//86,87	Check if sector is unfetched (=00)
		bne	NxtSct		//88,89	If sector is not unfetched (it is either fetched or wanted), go to next sector

		lda	#$ff		//8a,8b
		nop	#$00		//8c,8d	Skip $028d
MarkSct:	sta	WList,x		//8e,8f	Mark Sector as wanted (or used in the case of random bundle, STA <=> STY)
		stx	LastS		//90,91	Save Last Sector
IL:		axs	#$00		//92,93	Calculate Next Sector using inverted interleave
MaxSct1:	cpx	#$00		//94,95	Reached Max?
		bcc	SkipSub		//96,97	Has not reached Max yet, so skip adjustments
MaxSct2:	axs	#$00		//98,99	Reached Max, so subtract Max
		beq	SkipSub		//9a,9b
		nop	#$00		//9c,9d	Skip $029d = #$2a
SubSct:		axs	#$01		//9e,9f	Decrease if sector > 0
SkipSub:	dey			//a0	Any more blocks to be put in chain?
		bne	ChainLoop	//a1,a2
		stx	nS		//a3,a4
		rts			//a5	A=#$ff, X=next sector, Y=#$00 here
BLEnd:
}

CS:

//--------------------------------------
//		Code to $300
//--------------------------------------

.pseudopc $0300	{
CStart:
		nop	$f6ff		//Skip BitShufTab values
FetchBAM:	sty	LastS		//Y=#$00
FetchDir:	jsr	ClearList	//#$14 is also used as a GCR Tab1 value
		nop	$fff6		//Skip BitShufTab values
		ldx	LastS
		dec	WList,x		//Mark sector as wanted
		bmi	*+4

.byte	$6f, $66			//BitShufTab values

		lax	ZP12		//Both FetchBAM and FetchDir need track 18
		sta	LastT		//A=X=#$12

//--------------------------------------
//		Fetching any T:S	//A=X=wanted track, Y=#$00
//--------------------------------------

GotoTrack:	iny
		nop	$6f66		//Skip BitShufTab values
ContCode:	sty	WantedCtr	//Y=#$01 here
		sty	BlockCtr
		sec
		sbc	cT		//Calculate Stepper Direction and number of Steps
		jmp	$03d1

.byte	$05

CEnd:
}

//--------------------------------------

*=$2784	"ZP Code"
ZPCode:
.pseudopc ZPCode-$2700	{

//----------------------------------------------------------
//
//	 125-cycle GCR read+decode+verify loop on ZP
//	  works with rotation speeds of 284-311 rpm
//   across all four disk zones with max wobble in VICE
//
//----------------------------------------------------------

Zone3:		pha			//+3	php? 					64
		pla			//+4	plp?					67

Zone2:		sta	(FakeAdd),y	//+6	($a0)=$fc4b+Y (ROM)		66	73

Zone1:		nop 			//+2				62	68	75

Zone0:		eor	$0102,x		//$01ff^...		60	66	72	79
		eor	$0103,x		//			64	70	76	83
		sta.z	CSumT+1		//			67	73	79	86

					//			[52-77	56-83	60-89	64-95]
		lda	$1c01		//Read3 = 44445555  4	71/-6	77/-6	83/-6	90/-5
LoopMod4:	ldx	ZP0f		// <-> ldx #$0f	  2/3	73	80	86	93
		sax.z	t5+1		//t5+1 = 00005555   3	76
		arr	#$f0		//A=44444000	    2	78
		tay			//Y=44444000	    2	80

LoopMod5:				//			[78-103	84-111	90-119	96-127]
		lda	$1c01-$0f,x	//Read4 = 56666677  4/5	84/+7   92/+8   98/+8   105/+9
					//<->lda $1c01
		sax.z	t7+1		//t7+1 = 00006677  3	87
FakeAdd:	alr	#$fc		//A=05666660, C=0  2	89
		tax			//X=05666660	   2	91

t3:		lda	Tab3		//00333330	(ZP)	94
t4:		eor	Tab4,y		//00000000,44444000	98
Write1:		pha			//Buffer=$0100/$0104	101	SP=#$00->#$ff or #$04->#$03
					//$0104 = CheckSum
CSumT:		eor	#$00		//			103
CSum:		eor	#$00		//			105
		sta.z	CSum+1		//			108

t6:		lda	Tab6,x		//00000000,05666660	112
t5:		adc	Tab5		//00005555 (ZP)	V=0	115!/+11  123!/+11  129!/+9   136!/+8
Write2:		pha			//Buffer=$01ff/$0103	118	SP=#$ff->#$fe or #$03->#$02
					//$0103 = Sector
					//			[104-129  112-139   120-149   128-159]
		lax	$1c01		//Read5 = 77788888  4	122/-7	  130/-9    136/-13   143/+15
					//X=77788888
		and	#$e0		//		    2	124	  132	    138	      145
					//DO NOT MOVE AND #$E0 BELOW BVC!!!
//-------------------------------------------------------------------------------------

		bvc	*		//			00-01

		tay			//Y=77700000        2	03

t7:		lda	Tab7,y		//00006677,77700000	07
t8:		eor	Tab8,x		//00000000,77788888	11
Write3:		pha			//Buffer=$01fe/$0102	14	SP=#$fe->#$fd or #$02->#$01
					//$0102 = Track		[00-25	00-27	00-29	00-31]
		lda	$1c01		//Read1 = 11111222  4	18/-7	18/-9	18/-11	18/-13
LoopMod1:	ldx	ZP07		// <-> ldx #$07	    2/3	20	21	21	21
		sax.z	t2+1		//t2+1=00000222	    3	23	24	24	24
LoopMod2:	and	ZPf8-$07,x	// <-> and #$f8	    2/4	25	28	28	28
		tay			//Y=11111000	    2	27	30	30	30

LoopMod3:	ldx	ZP3e		// <-> ldx #$3e	    2/3	29	33	33	33
					//			[26-51	28-55	30-59	32-63]
		lda	$1c01		//A=22333334	    4	33/+7	37/+9	37/+7	37/+5
		sax.z	t3+1		//t3+1=00333330 ZP  3	36
		alr	#$c1		//A=02200000, C=4   2	38
		tax			//X=02200000	    2	40

t1:		lda	Tab1,y		//00000000,11111000	44
t2:		eor	Tab2,x		//00000222,02200000	48
Write4:		pha			//Buffer=$01fd/$0101	51	SP=#$fd->#$fc or #$01->#$00
					//$0101 = ID2
		tsx			//			53	57	57	57	X=#$fc/#$00 after first round
GCREntry:
ModGCR:		bne	Zone1		//			56/55	60/59	60/59	60/59

//-------------------------------------------------------------------------------------
		
		eor	$0102		//			59	63	63	63
		eor	$0103		//			63	67	67	67
		tax			//Save checksum in X	65	69	69	69
					//			[52-77  56-83	60-89	64-95]
		lda	$1c01		//Final read = 44445555	69/-8	73/-9	73/+13	73/+9
		arr	#$f0		//A=44444000		71			75
		tay			//Y=44444000		73			77
		txa			//Return checksum to A	75			79
		ldx	t3+1		//X=00333330		78			82
		eor	Tab3,x		//(ZP)			82			84
		eor	Tab4,y		//Checksum (Data) or ID1 (Header) 		90
		eor	CSum+1		//Calculate final checksum	    		93
		bne	FetchAgain	//If A=#$00 here then checksum is OK		95
ModJmp:		jmp	(HeaderJmp)	//Continue if A=#$00 (Checksum OK)		100
FetchAgain:	jmp	(FetchJmp)	//Fetch again if A<>#$00 (Checksum Error)
}

//-------------------------------------------------------------------
//				TABS
//	BOTH NIBBLES ARE BIT SHUFFLED AND EOR TRANSFORMED!!!
//	   DISK CAN BE WRITTEN WITHOUT EOR TRANSFORMATION
//-------------------------------------------------------------------

*=$2700	"ZP Tabs"		//#$80 bytes
.pseudopc	$0600	{
ZPTab:
//     x0  x1  x2  x3  x4  x5  x6  x7  x8  x9  xa  xb  xc  xd  xe  xf
.byte $12,$00,$04,$01,$e0,$70,$a0,$30,$01,$50,$00,$10,$60,$40,$20,$00	//0x	WantedCtr = #$01
.byte <LMT1,>LMT1
.byte	      $be,$8e,$ae,$8f,$2e,$87,$00,CSV,$fe,$8a,$ee,$8b,$6e,$83	//1x	$1c=#$07 for Tab3 and GCR loop mod
.byte <LMT2,>LMT2
.byte	      $ff,$00,$8e,$8d,$0e,$85,$01,$00,$5e,$80,$ce,$89,$4e,$81	//2x
.byte <LMT3,>LMT3
.byte	      $3e,$86,$9e,$8c,$1e,$84,<LMT4,>LMT4
.byte					      $7e,$82,$de,$88,$00,$00	//3x	Wanted List $3e-$52 (Sector 15 = #$ff)
.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$00	//4x	(0) unfetched, (+) fetched, (-) wanted
.byte $00,$00,$00,$0e,$12,$0f,$c5,$07,$ff,$01,$01,$0a,$af,$0b,$00,$03	//5x 	$55=#$0f, $57=#$07 for GCR loop mod
.byte $01,$00,$14,$00,$d7,$0d,$1e,$05,$00,<LMT5,>LMT5
.byte						  $00,$fa,$09,$00,$01	//6x	$60-$64 - LastT, LastS, SCtr, BPtr
.byte $3c,$4b,$5a,$06,$02,$0c,$00,$04,$00,<LMT6,>LMT6
.byte						  $02,$f8,$08,$00,$fd	//7x	$7c=#$f8 for GCR loop mod 
.byte $fd,$fd,$04,$fc								//8x	$7f-$83 - ILTab
}

*=$2300	"Tabs"			//#$100 bytes
.pseudopc $0300 {
Tab300:
//     x0  x1  x2  x3  x4  x5  x6  x7  x8  x9  xa  xb  xc  xd  xe  xf
.byte $48,$ff,$da,$de,$59,$d4,$d2,$d6,$7b,$f6,$eb,$ea,$e2,$8c,$ef,$ee	//0x
.byte $e6,$6f,$66,$e8,$e0,$9d,$e5,$ec,$e4,$66,$e3,$e9,$e1,$d9,$e7,$ed	//1x
.byte $1e,$2d,$3c,$4b,$5a,$05,$74,$85,$63,$05,$52,$85,$41,$05
//$032e
RcvByte:
		ldy	#$85		//$85 is also part of Tab7
		sax	$1800		//A&X = #$80 & #$10 = #$00, $dd00=#$1b, $1800=#$85
BitLoop:	cpy	$1800		//4
		beq	*-3		//2/3	4+3+4+2+4+2+2+3 = 24 cycles worst case
		ldy	$1800		//4	read: 6-12 cycles after $dd00 write (always within range)
		cpy	#$80		//2
		ror			//2
		bcc	BitLoop	//3	17/24 cycles/bit, 18 cycles per loop on C64 is enough
		stx	$1800		//Drive busy
		rts			//A = Bundle Index

//     x0  x1  x2  x3  x4  x5  x6  x7  x8  x9  xa  xb  xc  xd  xe  xf
//$0345
.byte	 	      $bd,$15,$35,$25,$50,$15,$35,$25,$34,$15,$35,$25	//4x
.byte $51
FetchJmp:
.byte	  <Fetch,>Fetch
.byte		  $69,$24
HeaderJmp:
.byte			  <Header,>Header
.byte				  $96,$59
//$0359
ToggleLED:	lda	#$08
		nop	#$a4		//Skip GCR Tab1 value
		eor	$1c00						//5x
		sta	$1c00
		rts
//$0364
.byte		      $1b,$95,$b5,$a5,$54,$95,$b5,$a5,$74,$95,$b5,$a5	//6x
.byte $55
//$0371
ShufToRaw:	ldx	#$99		//Fetched data are bit shuffled and...
		nop	#$64		//skip GCR Tab1 value
		axs	#$00		//...EOR transformed for fast transfer
		nop			//revert to raw (works both ways)
		eor	BitShufTab,x	//(EOR = #$5d, also a GCR Tab4 value)
		rts
.byte							$e4		//7x
//$037d
LMT1:		ldx	#$07		//2 cycles
		ldx	ZP07		//3 cycles
//$0381
.byte     $6f,$66
//$0383
LMT2:		and	#$f8		//2 cycles
		and	ZPf8-$07,x	//4 cycles
//$0387
DataJmp:
.byte				  <Data,>Data
.byte					  $66,$6f
//$038b
LMT3:		ldx	#$3e		//2 cycles
		ldx	ZP3e		//3 cycles
//$038f
.byte								  $1e	//8x
.byte $53,$ff,$f6,$2d,$04
//$0395
SFetchJmp:
.byte			      <SFetch,>SFetch
.byte				      $4a,$5b,$f6,$ff,$69,$84		//9x
//$039d
LMT4:		ldx	#$0f		//2 cycles
		ldx	ZP0f		//3 cycles
//$03a1
NoFlipTab:
.byte     $fe,$fd,$fc,$fb
.byte			  $45,$e5,$c5,$5e,$45,$e5,$c5,$d4,$45,$e5,$c5	//ax GCRZoneTab @ $07a0 ($07b1,$07b2,$07b3,$07b5)
.byte $57,$a3,$a5,$a7,$44,$a8
//$03b6
SHeaderJmp:
.byte			      <SHeader,>SHeader
.byte				      $5f
//$03b9
ProductID:
.byte					  $fe,$ed,$92
.byte					 	      $c4		//bx
//$03bd
LMT5:
.byte							  $ad,$01,$bd	//LDA $XX01 vs. LDA $XXf2,x (4 vs 5 cycles)
.byte $f2
//$03c1
LMT6:
.byte     $01,$1c,$f2,$1b						//$1c01 vs. $1c01-$0f									
//$03c5
.byte			  $55,$75,$65,$58,$55,$75,$65,$b4,$55,$75,$65	//cx
.byte $52
}