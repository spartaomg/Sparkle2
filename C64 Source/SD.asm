//TAB=8
//----------------------------------------------------------------------------------------
//	SPARKLE 2
//	Inspired by Lft's Spindle, Bitbreaker's Bitfire, and Krill's Loader
//	Drive Code
//	Tested on 1541-II, 1571, 1541 Ultimate-II+, Oceanic, and THCM's SX-64
//----------------------------------------------------------------------------------------
//	- 2-bit + ATN protocol, combined fixed-order and out-of-order loading
//	- 125-cycle on-the-fly GCR read-decode-verify loop with 1 BVC instruction
//	- tolerates disk rotation speeds between 282-312 rpm in VICE in all 4 disk zones
//	- 72 bycles/block transfer (67-cycle drive transfer loop)
//	- Spartan Stepping (TM) for uninterrupted loading across neighboring tracks
//	- LZ blockwise back-to-back compression
//----------------------------------------------------------------------------------------
//	Revision history
//
//	v1.0 	- initial version based on Sparkle 1 Drive Code
//		- 128-cycle on-the-fly GCR read-decode-verify loop
//		- introducing Spartan Stepping (TM)
//
//	v1.1 	- 127-cycle GCR RDV loop
//		  tolerates disk speeds 291-307 rpm
//		- new disk sector layout
//		  tracks start with Sector 2
//		  zone 3 with IL4, zones 0-2 with IL3
//
//	v1.2	- improved 127-cycle GCR RDV loop
//		  tolerates disk speeds 289-307 rpm
//		- improved Spartan Stepping
//		  60 bycles left for second half-step allowing settling of the R/W head
//		- simplified bit shuffle and conversion
//		- optimized sector layout and interleave handling for Spartan Stepping
//
//	v1.3	- new 125-cycle GCR RDV loop with 1 BVC instruction
//		  tolerates disk speeds 289-309 rpm
//		- loader version used in OMG Got Balls!
//		- alternative 127-cycle GCR RDV loop with 2 BVC instructions
//		  tolerates disk speeds 286-307 rpm (not used)
//
//	v1.4	- speed improvements by eliminating motor stops in the middle of data transfer
//		- motor stop is delayed by 2 seconds after data transfer is complete
//		- updated Spartan Step code
//
//	v1.5	- updated stepper code
//		- bug fixes
//		  fixed a bug that prevented seeking to Track 1 after disk finished then reloaded
//		  fixed buggy motor stop delay
//
//	v1.6	- C64 reset detection
//		- new commmunication code: busy = #$02 (DO), ready = #$18 (CO|AA)
//		  allows the C64 to detect drive reset
//		  leaves DO/DI untouched when drive is busy, can detect C64 reset which turns DI=1
//		  no reset detection during data transfer
//		- improved flip detection
//		- updated seek code
//		- improved 125-cycle GCR RDV loop, now tolerates disk speeds 285-309 rpm
//		- ANC instruction replaced with AND+CLC for Ultimate-II+ compatibility in stepper code
//
//	v1.7	- lots of code optimization
//		  swapped unfetched (00), wanted (ff/negative) and fetched (01/positive) flags
//		- updated, faster wanted list building
//		  results in faster loading with 0-25% CPU load
//
//	v1.8	- drive code updated to work with back-to-back compression code: no half-blocks left unused
//		  the last block of a Bundle also contains the beginning of the next Bundle
//		  C64 buffer needs to be left untouched between loader calls
//
//	v1.9 	- drive transfer loop modified to work with a 16-byte H2STab instead of a 256-byte tab
//		  new transfer loop now takes 67 cycles (previous version was 65)
//		  C64 transfer loop remains 72 cycles long
//		  new 16-byte H2STab moved from $0200 to $0600
//		- $0200-$02ff is now used as a secondary buffer
//		  last block of a Bundle is fetched OOO and stored here until all other blocks are transferred
//		  thus, the last block (which also contains the beginning of the next Bundle) is always transferred last 
//		  results in even faster loading across all CPU loads
//		- simplified wanted list preparations
//		- end-of-disk detection
//
//	v2.0	- new 126-cycle GCR RDV loop with improved wobble tolerance based on THCM's tests
//		  tolerates disk speeds 291-309 rpm with max wobble in VICE, similar tolerance in Micro64
//		  passed THCM's 24-hour test without error
//		  previous 125-cycle GCR loop failed on THCM's SX-64 due to lack of wobble tolerance 
//		- bug fixes based on THCM's tests
//		- test disk code including zone tests
//
//	v2.1	- new 125-cycle GCR RDV loop
//		  tolerates disk speeds 289-311 rpm with max wobble in VICE across all 4 speed zones
//		  passed THCM's 24-hour test without error in over $0d00 (3328) full disk loads
//
//	v2.2	- new communication code
//		  inverts ATN check to allow bus lock
//		  no drive reset detection currently
//		- improved C64 reset detection
//		- final, v1.0 release code!
//
//	v2.3	- custom interleave
//		- updated wanted sector selection algorithm
//		- introduced in Sparkle v1.3
//
//	v2.4	- updated 125-cycle GCR RDV loop
//		  tolerates 284-311 rpm disk speeds with max wobble in VICE across all 4 disk zones
//		- GCR loop and sector parameters are only updated at zone changes
//		- reworked block count update to work with new block structure
//		- interleave bug fix (loader in infinite loop on track 19 if IL0=20)
//		- released with Sparkle v1.4
//
//	v2.5	- block chain building bug fixed
//		- released with Sparkle V1.5
//
//	v2.6	- major update with random file access
//		- new memory layout (see below)
//		- secondary buffer feature removed to give space for directory
//		- directory structure (max 128 files per disk, 64 files per block):
//		  00 - track (EOR transformed)
//		  01 - first sector on track (EOR transformed)
//		  02 - sector count remaining on track (EOR transformed)
//		  03 - block pointer, points at the first byte of bundle in block (NOT EOR transformed)
//		- updated communication code
//
//	v2.7	- high score file saver
//		- flip disk detection with selectable disk ID ($80-$ff)
//		- product ID check added to flip detection
//		- additional memory layout improvements
//		  code is now interleaved with tabs at $0300-#03ff
//		- reset drive with bundle ID #$ff
//		- released with Sparkle 2
//
//	v2.8	- new GCR loop patch
//		  better speed tolerance in zones 0-2
//		  zone 3 remains 282-312 at 0 wobble in VICE
//		- checking trailing 0s after fetching data block to improve reliability 
//		  idea borrowed from Bitbreaker's Bitfire
//		- bits of high nibble of fetched data are no longer shuffled, only EOR'd with #$7
//		  they only get shuffled during transfer using an updated H2STab
//		  BitShufTab is now reduced to 4 bytes only -> moved to $0220
//		- more free memory
//		- ATNA-based transfer loop eliminating H2STab
//
//----------------------------------------------------------------------------------------
//	Memory Layout
//
//	0000	0085	ZP GCR Tabs and variables
//	0086	00ff	GCR Loop
//	0100	01ff	Data Buffer on Stack
//	0200	03f1	GCR Tabs with code interleaved
//	0330	06c4	Drive Code ($3b bytes free)
//	0700	07ff	Directory (4 bytes per entry, 64 entries per dir block, 2 dir blocks on disk)
//
//	Layout at Start
//
//	0300	03f1	GCR Tabs			block 0
//	0330	05ff	Code				blocks 1-2
//	0600	06ff	ZP GCR Tabs and GCR loop	block 3
//	0700	07f4	Init Code			block 4
//
//	Layout in PRG
//
//	2300	23f1	GCR Tabs			block 0
//	2330	26c4	Drive Code			blockS 1-3 3 -> block 5	
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
//	Disk:		Buffer:	Function:
//	18:00:$ff	$0101	DiskID		(for flip detection, compare to NextID @ $21 on ZP)
//	18:00:$fe	$0102	NextID		(will be copied to NextID on ZP after flip =#$00 if no more flips)
//	18:00:$fd	$0103	IL3R		(will be copied to $60)
//	18:00:$fc	$0104	IL2R		(will be copied to $61)
//	18:00:$fb	$0105	IL1R		(will be copied to $62)
//	18:00:$fa	$0106	IL0		(will be copied to $63, used to update nS)
//	18:00:$f9	$0107	IL0R		(will be copied to $64)
//
//	18:00:$f8	$0108	LastT		(will be copied to NoFlipTab)
//	18:00:$f7	$0109	LastS		(will be copied to NoFlipTab)
//	18:00:$f6	$010a	SCtr		(will be copied to NoFlipTab)
//	18:00:$f5	$010b	BPtr		(will be copied to NoFlipTab)
//
//	18:00:$f4	$010c	IncSaver	(will be copied to IncSaver)
//
//	18:00:$f3	$010d	ProductID1
//	18:00:$f2	$010e	ProductID2
//	18:00:$f1	$010f	ProductID3
//
//----------------------------------------------------------------------------------------
//	Directory Structure
//
//	00	Track
//	01	First sector on track after track change (NOT first sector of bundle, will be used to mark fetched sectors)
//	02	Sector Counter (sectors left unfetched, will be used to mark fetched sectors and first sector of bundle)
//	03	Byte Pointer (will be copied to last byte of first block, used by depacker to find start of stream)
//
//----------------------------------------------------------------------------------------

.const	SkewBase	=$02
.const	Skew		=SkewBase^$ff		//$02^$ff
.const	Skew13		=((SkewBase*2)+4)^$ff	//<((Skew*2)-3)	//=(((Skew^$ff) *2)+4)^$ff

.const	BAM_DiskID	=$0101
.const	BAM_NextID	=$0102
//.const	BAM_NoFlip	=$0108
.const	BAM_IncSave	=$010c
.const	BAM_ProdID	=$010d

//Constants:
.const	CSV		=$02	//Checksum Verification Counter Default Value

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
.const	StepDir		=$28	//Stepping  Direction
.const	LastBlock	=$29	//#$01 if last block of a Bundle is fetched, otherwise $00
.const	WList		=$3e	//Wanted Sector list ($3e-$52) (00=unfetched, [-]=wanted, [+]=fetched)
.const	DirSector	=$56	//Initial value=#$c5 (<>#$10 or #$11)
.const	EoD		=$5e	//End of Disk flag, only used with sequential loading

.const	LastT		=$60	//Track number of last block of a Bundle, initial value=#$01
.const	LastS		=$61	//Sector number of last block of a Bundle, initial value=#$00
.const	SCtr		=$62	//Sector Counter, sectors left unfetched in track
.const	BPtr		=$63	//Byte Pointer within block for random access

.const	NBC		=$66	//New Block Count temporary storage

.const	StepTmrRet	=$68	//Indicates whether StepTimer code is called in subroutine
.const	BitRateRet	=$6e	//Indicates whether Store code is called in subroutine
.const	IncSaver	=$74	//=#$02 if Saver Code is included, otherwise #$00
.const	SaverCode	=$76	//Indicates whether Saver Code Drive code is in the buffer
.const	TrackChg	=$78	//Indicates whether Track change is needed AFTER CATN (last block of bundle=last sector of track)

.const	NextID		=$7e	//Next Side's ID - will be updated from 18:00:$fd of next side
.const	ILTab		=$7f	//Inverted Custom Interleave Table ($7f-$83)
.const	IL0		=$82	//for nS

.const	ZP12		=$3b	//=#$12, part of Tab6
.const	ZP00		=$6b	//=#$00, part of Tab6
.const	ZP01ff		=$58	//$58/$59 = $01ff
.const	ZP0101		=$59	//$59/$5a = $0101

.const	SF		=$0129	//SS drive code fetch vector
.const	SH		=$012e	//SS drive code header vector

.const	OPC_JMP		=$4c
.const	OPC_BNE		=$d0

//Free ZP addresses:
//10,11,30,31,38,39,54,5c,64,69,6a,6c,70,71,72,79,7a,$7c,84,85

.const	TabZP		=$00
.const	Tab200		=$0200

//GCR Decoding Tabs:
.const	Tab1		=Tab300+1
.const	Tab2		=Tab200
.const	Tab3		=TabZP
.const	Tab4		=Tab300
.const	Tab5		=TabZP
.const	Tab6		=TabZP+1
.const	Tab7		=Tab300
.const	Tab8		=Tab200+1

.const	XX1		=$c3
.const	XX2		=$9d
.const	XX3		=$e5
.const	XX4		=$67

//Other Tabs:
.const	H2STab		=Tab200+$0d	//HiNibble-to-Serial Conversion Tab ($10 bytes total, $10 bytes apart)

//--------------------------------------

*=$2300	"Drive Code"
.pseudopc $0220	{
BitShufTab:
}
.pseudopc $0300	{
Tab300:
//	 00  01  02  03  04  05  06  07  08  09  0a  0b  0c  0d  0e  0f
.byte	$2f,$26,$84,$80,XX1,$8a,$8c,$88,$26,$2f,$3e,$3f,$37,XX2,$3a,$3b	//0x	Template for Tab2 and Tab8
.byte	$33,XX3,XX4,$3d,$35,XX1,$30,$39,$31,XX2,$36,$3c,$34,XX3,$32,$38	//1x
.byte	$60
//0321-24
NoFlipTab:
.byte	    $fe,$fd,$fc,$fb
.byte		            $00,$20,$a0,XX4,$00,$20,$a0,XX1,$00,$20,$a0	//2x

//--------------------------------------
//		HERE STARTS THE FUN
//		Fetching BAM OR Dir
//--------------------------------------
//0330
FetchBAM:	sty	LastS		//30 31	Y=#$00
FetchDir:	jsr	ClearList	//32-34	#$14 is also used as a GCR Tab1 value
		ldx	LastS		//35 36
		dec	WList,x		//37 38	Mark sector as wanted
		lax	ZP12		//39 3a	Both FetchBAM and FetchDir need track 18
		sta	LastT		//3b 3c	A=X=#$12

//--------------------------------------
//		Fetching any T:S	//A=X=wanted track, Y=#$00
//--------------------------------------

GotoTrack:	iny			//3d
ContCode:	sty	WantedCtr	//3e 3f	Y=#$01 here
		sty	BlockCtr	//40 41
		sec			//42
		sbc	cT		//43 44	Calculate Stepper Direction and number of Steps
		beq	Fetch		//45 46	We are staying on the same Track, skip track change
		nop	$2ad0		//47-49	SKIPPING $d0,$2a GCR table values
		bcs	SkipStepDn	//4a 4b
		eor	#$ff		//4c 4d
		bcc	SkipTabs1	//4e 4f
//0350
.byte	$d1,$aa
//0352
FetchJmp:
.byte		<FT,>FT
//0354
HeaderJmp:
.byte			<HD,>HD
//0356
DataJmp:
.byte				<DT,>DT
//0358
.byte					$d9,$ba
//035a
SFetchJmp:
.byte						<SF,>SF
//035c
SHeaderJmp:
.byte							<SH,>SH
//035e
Mod2:		//jmp	Mod2		//			--	79	87	87
Mod2c:		pha			//5e			--	--	--	90
		pla			//5f			--	--	--	94
		nop			//60			--	--	--	96	
Mod2b:
Mod2a:		nop			//61			--	81	89	98
		arr	#$f0		//62 63			78	83	91	100
		tay			//64			80	85	93	102
		jmp	LoopMod2+3	//65-67			--	88	96	105
		//lda	$1c01		//			84	92	100	109
//0368
.byte					$d4,$6a
//036a
SkipTabs1:	adc	#$01		//6a 6b
		ldy	#$03		//6c 6d	Y=#$03 -> Stepper moves Down/Outward
		bne	*+4		//6e 6f
//0370
.byte	$d5,$ea
//0372
		sty	StepDir		//72 73	Store stepper direction UP/INWARD (Y=#$01) or DOWN/OUTWARD (Y=#$03)
SkipStepDn:	asl			//74	Y=#$01 is not stored - it is the default value which is restored after every step
		tay			//75	Y=Number of half-track changes
		bne	SkipTabs2	//76 77
//0378
.byte					$dd,$fa
//037a
RcvByte:	ldy	#$85		//7a 7b
		sax	$1800		//7c-7e		A&X = #$80 & #$10 = #$00, $dd00=#$1b, $1800=#$85
RBLoop:		cpy	$1800		//7f-81	4
		beq	*-3		//82 83	2/3	4+3+4+2+4+2+2+3 = 24 cycles worst case
		ldy	$1800		//84-86	4	read: 6-12 cycles after $dd00 write (always within range)
		cpy	#$80		//87 88	2
		ror			//89	2
		bcc	RBLoop		//8a 8b	3	17/24 cycles/bit, 18 cycles per loop on C64 is enough
		stx	$1800		//8c-8e		Drive busy
		rts			//8f		20 bytes total, A = Bundle Index
//0390
.byte	$d3,$8a
//0392
SkipTabs2:	inc	StepTmrRet	//92 93	#$00->#$01 - signal need for RTS 
		jsr	StepTmr		//94-96	Move head to track and update bitrate (also stores new Track number to cT and calculates SCtr)
		nop	$9adb		//97-99	SKIPPING $db,$9a

//--------------------------------------
//		Multi-track stepping
//--------------------------------------

		lda	Spartan+1	//9a-9c
		sta	$1c00		//9d-9f	Store bitrate
		lda	#CSV		//a0 a1
		sta	VerifCtr	//a2 a3	Verify track after head movement

//--------------------------------------
//		Fetch Code
//--------------------------------------
FT:
Fetch:		lda	VerifCtr	//a4 a5	If checksum verification needed at disk spin up...
		nop			//a6
		nop	$5ade		//a7-a9	SKIPPING $de,$5a
		bne	FetchData	//aa ab	...then fetch any data block instead of a Header
FetchHeader:
		ldy	#<HeaderJmp	//b2 b3	Checksum verification after GCR loop will jump to Header Code
		bne	*+4		//ae af
//03b0
.byte	$d7,$ca
//03b2
		lda	#$52		//b2 b3	First byte of Header
		ldx	#$04		//b4 b5	4 bytes to stack
		bne	Presync		//b6 b7	Skip Data Block fetching
//03b8
.byte					$df,$da
//03ba
FetchData:	ldx	#$00		//ba bb	256 bytes to stack
		ldy	#<DataJmp	//bc bd	Checksum verification after GCR loop will jump to Data Code
		lda	#$55		//be bf	First byte of Data

Presync:	sty	ModJmp+1	//c0-c2		Update Jump Address
		txs			//c3		Header: $0104,$0103..$0101, Data: $0100,$01ff..$0101
		ldy	#$7f		//c4 c5
		bne	*+4		//c6 c7
//03c8
.byte					$d8,$3a
//03ca
Sync:		bit	$1c00		//ca-cc		We happen to be in a SYNC mark right now, skip it
		bpl	*-3		//cd ce
		nop	$0ad2		//cf-d1		SKIPPING $d2,$0a
		bit	$1c00		//d2-d4		Wait for SYNC
		bmi	*-3		//d5 d6
		nop	$1ada		//d7-d9		SKIPPING $da,$1a
		nop	$1c01		//da-dc		Sync byte - MUST be read (VICE bug #582), not necessarily #$ff
		clv			//dd

					//Addr |Cycles
		bvc	*		//de df|00-01
		cmp	$1c01		//e0-e2|05	*Read1 = 11111222  ->	01010|010(01) for Header
		clv			//e3	07				01010|101(11) for Data
		beq	SkipTabs3	//e4 e5|10	First byte of Header/Data is discarded
		bne	Sync		//e6 e7|--
//03e8
.byte					$dc,$7a
//03ea
JmpFData:	jmp	FetchData	//BEQ FetchData would also work 
//03ed
ProductID:						
.byte							    $ab,$cd,$ef	//ex
//03f0
.byte	$d6,$4a
//03f2
SkipTabs3:	sty.z	CSum+1		//f2 f3|13	Y=#$ff, we are working with inverted GCR Tabs, checksum must be inverted
		ldy	#$00		//f4	15	Y=#$00
		lda	cT		//f5 f6|18
		cmp	#$19		//f7 f8|20	Track number >=25?
		bcc	SkipDelay	//f9 fa|23/22	We need different timing for zones 0-1 and zones 2-3
		pha			//fb	--/26	8 cycles delay for zones 0-1
		pla			//fc	--/29
		nop			//fd	--/31
SkipDelay:	sta	$0102,y		//fe-00|28/36	Any value will do in A as long as $0102 and $0103 are the same
		sta	(GCRLoop+4),y	//01 02|34/42	$0102 and $0103 will actually contain the current track number
		ldx	#$3e		//03 04|36/44			   [26-51  28-55  30-59  32-63]
		lda	$1c01		//05-07|40/48	*Read2 = 22333334 @ 40/-11 40/+12 48/-11 48/-15
		sax.z	t3+1		//08 09|43/51	t3+1 = 00333330	
		lsr			//0a	45/53	C=4 - needed for GCR loop
		lax	ZP00		//0b 0c|48/56	Clear A, X - both needed for first 2 EORs after BNE in GCR loop
					//		LAX #$00 would work but we need ZP for timing
		iny			//0d	50/58	Y=#$01 (<>#$00 for BNE to work after jump in GCR loop)
		jmp	GCREntry	//0e-10|53/61	Same number of cycles before BNE as in GCR loop

//--------------------------------------
//		Got Header
//--------------------------------------

HD:					//A=$0103 = sector number in header
Header:		jsr	ShufToRaw	//JSR OK here
		tay			//Y=fetched sector
		lda	$0102		//A=track number in header
		jsr	ShufToRaw
		cmp	cT		//A=fetched track
ToFHeader:	bne	FetchHeader	//Check current track
		ldx	WList,y
		bpl	FetchHeader	//Check current sector

		sty	cS		//Store current sector

		cpy	LastS		//Is this also the last sector of a bundle?
ToFData:	bne	FetchData	//Not the last one -> fetch data

		lda	cT		//Check expected track of last sector of bundle
		cmp	LastT
		bne	ToFData		//Not the expected track of the last sector -> fetch data

		lax	WantedCtr	//Last sector of a bundle fetched -> check how many sectors are left to load
		dex
		bne	ToFHeader	//More than one sector left on Wanted List, skip last sector, fetch next

		sta	LastBlock	//-> #$01, we have the last block of the bundle
		beq	JmpFData	//ALWAYS

//--------------------------------------
//		Checksum Verification
//--------------------------------------

DataVerif:	dec	VerifCtr
		jmp	Fetch+2		//ALWAYS, fetch next data block for checksum verification (skipping headers if VerifCtr>0)

//--------------------------------------
//		Disk ID Check		//Y=#$00 here
//--------------------------------------

Track18:	cpx	#$10		//Drive Code Block 3 (Sector 16) or Dir Block (Sectors 17-18)?
		bcc	CheckID		//No

ToCD:		jmp	CopyCode	//Sector 15 (Block 3) - copy it from the Buffer to its place, Y=#$00 here, WantedCtr=1
					//Will be changed to JMP CopyDir after Block 3 copied

CheckID:	lax	NextID		//Side is done, check if there is a next side
//		bpl	Flip		//Disk ID = #$00 - #$7f, if NextID > #$7f - no more disks

//--------------------------------------
//		No more disks, so return with a "dummy" load
//--------------------------------------

//NoFlip:		ldx	#$04		//There are no more disk sides, so let's do a "dummy" load to allow the loader to return
//NFLoop:		lda	NoFlipTab-1,x
//		sta	LastT-1,x
//		dex
//		bne	NFLoop
//		stx	NewBundle	//X=#$00, clear NewBundle, EoD is cleared on both sequential and random sides
//		inc	Random		//Set Random
//		jmp	RandomNoFlip	//Y remains #$00 here, needed after JMP

//--------------------------------------
//		Flip Detection		//Y=$#00 here
//--------------------------------------

Flip:		cmp	(ZP0101),y	//DiskID, compare it to NextID in memory, EOR-transformed -> $0100
		bne	ToFHeader	//ID mismatch, fetch again until flip detected

		ldy	#$03
ProdIDLoop:	lda	BAM_ProdID-1,y	//Also compare Product ID, only continue if same
		cmp	ProductID-1,y
		bne	ToFHeader	//Product ID mismatch, fetch again until same
		dey
		bne	ProdIDLoop

//--------------------------------------

		ldy	#$06		//Flip detected, copy Next Side Info, data is EOR-transformed
		sty	DirSector	//Invalid value to trigger reload of the directory of the new disk side
CopyBAM:	lda	(ZP0101),y	//= LDA $0100,y
		sta	NextID-1,y 	//($0100=DiskID), $0101=NextID, $102=IL3R, $103=IL2R, $104=IL1R, $105=IL0, $106=IL0R
//		cpy	#$05
//		bcs	SkipNFT
//
//		lda	BAM_NoFlip-1,y	//NoFlipTab needs to be updated here, too ($0108-$010b)
//		sta	NoFlipTab-1,y
SkipNFT:	dey
		bne	CopyBAM

		lda	BAM_IncSave	//Value (#$00 vs. #$02) indicates whether Saver Code is included on this disk side
		sta	IncSaver

		tya
		jmp	CheckDir	//Y=A=#$00

//--------------------------------------

ToCATN:		jmp	CheckATN

//--------------------------------------
//		Finish Checksum
//--------------------------------------

//		jmp 	FinishCSum	//Calc final checksum		29	29	29	29
FinishCSum:	cmp	$0103		//Final checksum		33	33	33	33
		bne	FetchAgain	//If A=($0103) then CSum is OK	35	35	35	35
ModJmp:		jmp	(HeaderJmp)	//Checksum OK			40	40	40	40
FetchAgain:	jmp	(FetchJmp)	//Checksum mismatch

//--------------------------------------
//		Got Data
//--------------------------------------
DT:					//			       [26-51	28-55	30-59	32-63]
Data:		lda	$1c01		//A=77788888			44/-7	44/-11	44/+14	44/+12
		cpy	#$29		//%00101001	check trailing 0s
		bne	FetchAgain	//
		and	#$e0		//%111XXXXX
		cmp	#$40		//expected value is %010XXXXX, last nibble varries
		bne	FetchAgain

		ldy	VerifCtr	//Checksum Verification Counter
		bne	DataVerif	//If counter<>0, go to verification loop

		ldx	cS		//Current Sector in Buffer
		lda	cT		//Y=#$00 here
		cmp	#$12		//If this is Track 18 then we are fetching Block 3 or a Dir Block or checking Flip Info
		beq	Track18		//We are on Track 18

//.print "Header: $0" + toHexString(Header)
//.print "Data:   $0" + toHexString(Data)

//.if ([>Header] != [>Data])	{
//.error "ERROR!!! Header & Data NOT on the same page!!!"
//} else	{
//.print "Header & Data on the same page :)"
//}

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
		jmp	$0100		//Saver Code fetched

//--------------------------------------
//		Check Last Block	//Y=#$00 here
//--------------------------------------

		lsr	LastBlock
		bcc	ChkNewBndl	//C=0 - not the last block

		lda	(ZP01ff),y	//Save new block count for later use
		sta	NBC
		lda	#$7f		//And delete it from the block
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
		sec			//Signal to use JMP instead of RTS
		jmp	JmpClrList	//Y=#$00 here	

//--------------------------------------

NextTrack:	ldx	cT		//All blocks fetched in this track, so let's change track
		ldy	#$81		//Prepare Y for 0.5-track seek

		lda	NBC		//Very last sector?
		beq	ToCATN		//Yes, skip stepping, finish transfer

		inx			//Go to next track

ChkDir:		cpx	#$12		//next track = Track 18?, if yes, we need to skip it
		bne	Seek		//0.5-track seek, skip setting timer

		inx			//Skip track 18
.if (SkewBase == $00)	{
		inc	nS		//Skipping Dir Track will rotate disk a little bit more than a sector...
		inc	nS		//...(12800 cycles to skip a track, 10526 cycles/sector on track 18)...
					//...so start sector of track 19 is increased by 2
}
		ldy	#$83		//1.5-track seek, set timer at start

//--------------------------------------
//		Stepper Code		//X=Wanted Track
//--------------------------------------

StepTmr:	lda	#$98
		sta	$1c05

Seek:		lda	$1c00
PreCalc:	//anc	#$1b		//ANC DOES NOT WORK ON ULTIMATE-II+
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

StoreTr:	sta	cT		//Store new track number - SKIP IF JSR FROM RANDOM
		lda	Random
		bne	*+4
		sty	SCtr		//Reset Sector Counter

//--------------------------------------
//		GCR loop patch
//--------------------------------------

		ldx	#$02		//Restore loop to default
MLoop:		lda.z	Mod1,x
		sta.z	LoopMod1-1,x
		lda	Mod2a+1,x
		sta.z	LoopMod2,x
		dex
		bpl	MLoop
		cpy	#$15		//Y=sector count (17, 18, 19, 21 for zones 0, 1, 2, 3, respectively)
		beq	SkipPatch
		lda	#<OPC_JMP	//Patch for zones 0-2
		sta.z	LoopMod2
		lda	#>Mod2
		sta.z	LoopMod2+2
		ldx.z	Mod2Lo-$11,y
		stx.z	LoopMod2+1

		cpy	#$13
		bcs	SkipPatch
		lda	#<OPC_BNE	//Patch for zones 0-1
		sta.z	LoopMod1
		lda	#<Mod1-(LoopMod1+2)
		sta.z	LoopMod1+1

SkipPatch:	lsr	StepTmrRet
		bcc	*+3
		rts

//--------------------------------------
//		Sector Skew Adjustment
//--------------------------------------

.if (SkewBase != $00)	{

		lda	#Skew		//Skew= -2-4
		ldx	cT
		cpx	#$13		//Track 19?
		bne	*+4
		lda	#Skew13		//Skew= -8-4
		sec
		adc	LastS		//nS=LastS-Skew
		bcs	*+5
		adc	MaxSct1+1	//if nS,0 then nS+=MaxSct
		sta	nS
}

//--------------------------------------

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
		tax			//This needs to be precalculated here, so that we do not affect Z flag at Restart

		ldy	#$64		//100 frames (2 seconds) delay before turning motor off (#$fa for 5 sec)
DelayOut:	lda	#$4f		//Approx. 1 frame delay (20000 cycles = $4e20 -> $4e+$01=$4f)
		sta	$1c05		//Start timer, wait 2 seconds before turning motor off
DelayIn:	lda	$1c05
		bne	ChkLines
		dey
		bne	DelayOut
		//lda	NewBundle	//Timer finished, is this a new bundle?
		//beq	ChkLines	//No, continue waiting for C64
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
		ldx	#busy		//X=#$10 (AA=1, CO=0, DO=0) - WILL BE USED LATER IF SAVER CODE IS NEEDED

		jsr	RcvByte		//OK to use stack here

		cmp	#$ff
		beq	Reset		//C64 requests drive reset

		ldy	#$00		//Needed later (for FetchBAM if this is a flip request, and FetchDir too)
		sty	EoD		//EoD needs to be cleared here
		sty	NewBundle	//So does NewBundle

		asl
		bcs	NewDiskID	//A=#$80-#$fe, Y=#$00 - flip disk
		beq	CheckDir	//A=#$00, skip Random flag
		inc	Random
CheckDir:	ldx	#$11		//A=#$00-#$7f, X=#$11 (dir sector 17) - DO NOT CHANGE TO INX, IT IS ALSO A JUMP TARGET!!!
		asl
		sta	DirLoop+1	//Relative address within Dir segment
		bcc	CompareDir
		inx			//A=#$40-#$7f, X=#$12 (dir sector 18)
		cmp	#$f8		//Index=#$7e - check if we are loading the Saver Code
		bne	CompareDir
		lda	IncSaver	//A=#$02 if Saver Code is included on Disk, #$00 otherwise
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

//RandomNoFlip:
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
		ldx	#$0a		//bit mask for SAX
		lda	#ready		//A=#$08, ATN=0, AA not needed
		sta	$1800

//--------------------------------------
//		Transfer loop
//--------------------------------------
					//			Spartan Loop:		Entry:
Loop:		lda	$0100,y		//03-06			19-22			00-03
		bit	$1800		//07-10			23-26			04-07
		bmi	*-3		//11 12			27 28			08 09
W1:		sax	$1800		//13-16			29-32			10-13
					//(17 cycles)	 	(33 cycles)

		dey			//00 01
		asl			//02 03
		ora	#$10		//04 05
		bit	$1800		//06-09
		bpl	*-3		//10 11
W2:		sta	$1800		//12-15
					//(16 cycles)

		ror			//00 01
		alr	#$f0		//02 03
		bit	$1800		//04-07
		bmi	*-3		//08 09
W3:		sta	$1800		//10-13
					//(14 cycles)

		lsr			//00 01
		alr	#$30		//02 03
ByteCt:		cpy	#$101-Sp	//04 05		Sending #$52 bytes before Spartan Stepping (#$59 for $1a bycles)
		bit	$1800		//06-09		#$52 x 72 = #$17 bycles*, #$31 bycles left for 2nd halftrack step and settling
		bpl	*-3		//10 11		*actual time #$18-$1a+ bycles, and can be (much) longer
W4:		sta	$1800		//12-15		if C64 is not immediately ready to receive fetched block
					//(16 cycles)	thus, the drive may actually stop on halftracks before transfer continues
		
		bcs	Loop		//00-02

//--------------------------------------
//	SPARTAN STEPPING (TM)				<< - Uninterrupted data transfer across adjacent tracks - >>
//--------------------------------------		Transfer starts 1-2 bycles after first halftrack step initiated

Spartan:	lda	#$00		//02 03		Last halftrack step is taken during data transfer
		sta	$1c00		//04-07		Update bitrate and stepper with precalculated value
		tya			//08 09		Y=#$ae or #$00 here
		eor	#$101-Sp	//10 11		#$31 bycles left for the head to take last halftrack step...
		sta	ByteCt+1	//12-15		... and settle before new data is fetched
ChkPt:		bpl	Loop		//16-18

.print ""
.print "Loop:  $0" + toHexString(Loop)
.print "ChkPt: $0" + toHexString(ChkPt)

.if ([>Loop] != [>ChkPt])	{
.error "ERROR!!! Transfer loop crosses pages!!!"
} else	{
.print "Transfer loop on a single page :)"
}

//--------------------------------------

		lda	#busy		//16,17 	A=#$10
		bit	$1800		//18,19,20,21	Last bitpair received by C64?
		bmi	*-3		//22,23
		sta	$1800		//24,25,26,27	Transfer finished, send Busy Signal to C64
					
		bit	$1800		//Make sure C64 pulls ATN before continuing
		bpl	*-3		//Without this the next ATN check may fall through
					//resulting in early reset of the drive

//		lda	#$ff		//Counting down $fe00 cycles max which is about 3.3 frames on C64
//		sta	$1c05		//As a rare event, an interrupt may occur on the C64 right here
//Wait4C64:	bit	$1800		//which would delay pulling ATN and result in resetting the drive
//		bmi	C64OK		//ATN pulled, OK to continue
//		lda	$1c05
//		beq	Reset		//Time out, ATN not pulled, assume C64 reset, reset drive as well
//		bne	Wait4C64	//Continue checking until time out

//C64OK:

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

//--------------------------------------

EndOfDriveCode:

.if (EndOfDriveCode > $0700)	{
.error "Error!!! Drive code too long!!!" + toHexString(EndOfDriveCode)
}

//----------------------------------------------------------

}

*=$2800	"Installer"

.pseudopc	$0700	{

//--------------------------------------
//		Initialization	//$0700
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
MakeTabs:	lda	#$10
		eor	Tab200+$20,x	//Prepare Tabs 2 and 8
		sta	Tab200,x	//Copy from $0300-$031f to $0200-$02ff
		lda	ZPTab,x		//Copy Tabs 3, 5 & 6 and GCR Loop from $0600 to ZP
		sta	$00,x
		dex
		beq	TabsDone
		bmi	MakeTabs
		lda	#$50
		cpx	#$60
		bcs	MakeTabs+2
		bmi	MakeTabs
TabsDone:
//--------------------------------------
//		Copy code and tabs
//--------------------------------------

		ldx	#<BLEnd-BL
CBL:		lda	CD+CDEnd-CopyDir-1,x		//Copy code to $0280, #$26 bytes
		sta	BL-1,x
		cpx	#<CEnd-CStart+1
		bcs	SkipCD
		lda	CD-1,x				//Copy code to $0200, #$1c bytes
		sta	CopyDir-1,x
		lda	CD+CDEnd-CopyDir+BLEnd-BL-1,x	//Copy start code to $0305, #$1c bytes
		sta	CStart-1,x
SkipCD:		cpx	#$07
		bcs	SkipT2	
		lda	Tab2Base1-1,x			//Copy remaining parts of Tab2
		sta	Tab2+$41,x
		lda	Tab2Base2-1,x			//Copy remaining parts of Tab2
		sta	Tab2+$61,x
SkipT2:		dex
		bne	CBL

//--------------------------------------

		lda	#$ee		//Read mode, Set Overflow enabled
		sta	$1c0c		//could use JSR $fe00 here...
/*		
		lda	#$01		//Enable latching Port A, disable latching Port B
		sta	$1c0b		//Is this really needed? Default value is #$41
*/					
					//Turn motor and LED on
		lda	#$d6		//1    1    0    1    0*   1*   1    0	We always start on Track 18, this is the default value
		sta	$1c00		//SYNC BITR BITR WRTP LED  MOTR STEP STEP	Turn motor and LED on

		jmp	Fetch		//Fetching block 3 (track 18, sector 16) WList+$10=#$ff, WantedCtr=1
					//A,X,Y can be anything here
Tab2Base1:
.byte	$d5,$d1,$d7,$d3,$d6,$d2
Tab2Base2:
.byte	$dd,$d9,$df,$db,$de

//--------------------------------------
//		Copy block 3 to $0600
//--------------------------------------

CopyCode:
CCLoop:		pla			//=lda $0100,y
		iny			//Y=00 at start
		sta	$0600,y		//Block 3 is EOR transformed and rearranged, just copy it
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
CDLoop:		pla			//00	=LDA $0100,y
		iny			//01
		sta	$0700,y		//02-04
		bne	CDLoop		//05 06
		jmp	ReadDir		//07-09
ClrJmp:		jmp	NextTrack	//0a-0c
//--------------------------------------
ClearList:	clc			//0e
JmpClrList:	ldx	#$14		//0f 10
ClrWList:	sty	WList,x		//11 12	Y=00, clear Wanted Block List
		dex			//13
		bpl	ClrWList	//14 15
		bcs	ClrJmp		//16 17
		rts			//18
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
Build:		iny			//81	Temporary increase as we will have an unwanted decrease after bne
		lda	#$ff		//82,83	Needed if nS = last sector of track and it is already fetched			
		bne	MaxSct1		//84,85	Branch ALWAYS
ChainLoop:	lda	WList,x		//86,87	Check if sector is unfetched (=00)
		bne	NxtSct		//88,89	If sector is not unfetched (it is either fetched or wanted), go to next sector

		lda	#$ff		//8a,8b
MarkSct:	sta	WList,x		//8e,8f	Mark Sector as wanted (or used in the case of random bundle, STA <=> STY)
		stx	LastS		//90,91	Save Last Sector
IL:		axs	#$00		//92,93	Calculate Next Sector using inverted interleave
MaxSct1:	cpx	#$00		//94,95	Reached Max?
		bcc	SkipSub		//96,97	Has not reached Max yet, so skip adjustments
MaxSct2:	axs	#$00		//98,99	Reached Max, so subtract Max
		beq	SkipSub		//9a,9b
SubSct:		axs	#$01		//9e,9f	Decrease if sector > 0
SkipSub:	dey			//a0	Any more blocks to be put in chain?
		bne	ChainLoop	//a1,a2
		stx	nS		//a3,a4
		rts			//a5	A=#$ff, X=next sector, Y=#$00 here
BLEnd:
}

CS:

//--------------------------------------
//		Code to $304
//--------------------------------------

.pseudopc $0305	{
CStart:
.byte			    $90,$a0,$80,XX2,$90,$a0,$80,XX3,$90,$a0,$80	//0x	00-0a
//0310
ToggleLED:	lda	#$08		//0b 0c
		eor	$1c00		//0d-0f
		sta	$1c00		//10-12
		rts			//13
//0319
ShufToRaw:	ldx	#$09		//14 15	Fetched data are bit shuffled and
		axs	#$00		//16 17	EOR transformed for fast transfer
		eor	BitShufTab,x	//18-1a	(EOR = #$5d, also a GCR Tab4 value)
		rts			//1b
CEnd:
}

//----------------------------------------------------------

*=$2786	"ZP Code"
ZPCode:
.pseudopc ZPCode-$2700	{

//----------------------------------------------------------------------------------------------
//
//	 		125-cycle GCR read+decode+verify loop on ZP
//		     works reliably with rotation speeds of 282-312 rpm
//		     		across all four disk zones
//
//----------------------------------------------------------------------------------------------

		//bne	Mod1		//			--	--	30	30
Mod1:		tay			//repeat tay - harmless	--	--	32	32
		ldx	#$3e		//but helps with patch	--	--	34	34
		bne	LoopMod1+2	//			--	--	37	37
		//lda	$1c01		//			33	33	41	41
//----------------------------------------------------------------------------------------------

GCRLoop:	eor	$0102,x		//$01ff^...		60	60	68	68
		eor	$0103,x		//			64	64	72	72
		sta.z	CSumT+1		//			67	67	75	75

					//		       [52-77	56-83	60-89	64-95]
		lda	$1c01		//Read3 = 44445555	71/-6	71/-12	79/-10	79/+15
		ldx	#$0f		//			73	73	81	81
		sax.z	t5+1		//t5+1 = 00005555	76	76	84	84
LoopMod2:	//arr	#$f0		//A=44444000		78	--	--	--
		//tay			//Y=44444000		80	--	--	--
		jmp	Mod2a		//We start on track 18 (zone 2) by default
					//		       [78-103	84-111	90-119	96-127]
		lda	$1c01		//Read4 = 56666677	84/+6	92/+8	100/+10	109/+13
		sax.z	t7+1		//t7+1 = 00006677	87	95	103	112
		alr	#$fc		//A=05666660, C=0	89	97	105	114
		tax			//X=05666660		91	99	107	116

t3:		lda	Tab3		//00333330	(ZP)	94	102	110	119
t4:		eor	Tab4,y		//00000000,44444000	98	106	114	123
Write1:		pha			//Buffer=$0100/$0104	101	109	117	126		SP=#$00->#$ff or #$04->#$03
					//$0104 = CheckSum
CSumT:		eor	#$00		//			103	111	119	128
CSum:		eor	#$00		//			105	113	121	130
		sta.z	CSum+1		//			108	116	124	133

t6:		lda	Tab6,x		//00000000,05666660	112	120	128	137
t5:		adc	Tab5		//00005555 (ZP)	V=0 !!!	115/+11	123/+11	131/+11	140/+12
Write2:		pha			//Buffer=$01ff/$0103	118	126	134	143		SP=#$ff->#$fe or #$03->#$02
					//$0103 = Sector
					//		       [104-129	112-139	120-149	128-159]
		lax	$1c01		//Read5 = 77788888	122/-7	130/-9	138/-11	147/-12
					//X=77788888
		alr	#$40		//			124	132	140	149
					//DO NOT MOVE ALR #$40 BELOW BVC!!!

//----------------------------------------------------------------------------------------------

		bvc	*		//			00-01

		tay			//Y=00700000		03

t7:		lda	Tab7,y		//00006677,0-7-0000	07
t8:		eor	Tab8,x		//00000000,77788888	11
Write3:		pha			//Buffer=$01fe/$0102	14					SP=#$fe->#$fd or #$02->#$01
					//$0102 = Track	       [00-25	00-27	00-29	00-31]
		lda	$1c01		//Read1 = 11111222	18/-7	18/-9	18/-11	18/-13
		ldx	#$07		//			20	20	20	21
		sax.z	t2+1		//t2+1=00000222		23	23	23	24
		and	#$f8		//			25	25	25	28
		tay			//Y=11111000		27	27	27	27

LoopMod1:	ldx	#$3e		//			29	29	--	--
					//		       [26-51	28-55	30-59	32-63]
		lda	$1c01		//A=22333334		33/+7	33/+5	41/+11	41/+9
		sax.z	t3+1		//t3+1=00333330 ZP	36	36	44	44
		alr	#$c1		//A=02200000, C=4	38	38	46	46
		tax			//X=02200000		40	40	48	48

t1:		lda	Tab1,y		//00000000,11111000	44	44	52	52
t2:		eor	Tab2,x		//00000222,02200000	48	48	56	56
Write4:		pha			//Buffer=$01fd/$0101	51	51	59	59		SP=#$fd->#$fc or #$01->#$00
					//$0101 = ID2
		tsx			//			53	53	61	61		X=#$fc/#$00 after first round

GCREntry:	bne	GCRLoop		//			56/55	56/55	64/63	64/63

//----------------------------------------------------------------------------------------------

		eor	CSum+1		//			58	58	66	66
		tax			//Store checksum in X	60	60	68	68
		clv			//			62	62	70	70
					//		       [52-77	56-83	60-89	64-95]
		lda	$1c01		//Final read = 44445555	66/-11	66/+10	74/+14	74/+10
		bvc	*		//			01
		arr	#$f0		//A=44444000		03
		tay			//Y=44444000		05
		txa			//Return checksum to A	07
		eor	Tab4,y		//Checksum (D)/ID1 (H)	11
		ldy	$1c01		//Y=56666677		15*
		ldx	t3+1		//X=00333330		18
		eor	Tab3,x		//(ZP)			22
		eor	$0102		//			26
		jmp 	FinishCSum	//Calc final checksum	29
}

//-------------------------------------------------------------------
//				TABS
//	BOTH NIBBLES ARE BIT SHUFFLED AND EOR TRANSFORMED!!!
//	   DISK CAN BE WRITTEN WITHOUT EOR TRANSFORMATION
//-------------------------------------------------------------------
                                                      
*=$2700	"ZP Tabs"								//#$80 bytes
.pseudopc	$0600	{
ZPTab:
//	 x0  x1  x2  x3  x4  x5  x6  x7  x8  x9  xa  xb  xc  xd  xe  xf
.byte	$12,$00,$04,$01,$f0,$60,$b0,$20,$01,$40,$80,$00,$e0,$c0,$a0,$80	//0x
.byte	XX1,XX2,$2e,$1e,$ae,$1f,$be,$17,$00,CSV,$6e,$1a,$ee,$1b,$fe,$13	//1x
Mod2Lo:
.byte	<Mod2c,<Mod2b,<Mod2a
.byte		    $00,$8e,$1d,$9e,$15,$01,$00,$5e,$10,$ce,$19,$de,$11	//2x
.byte	XX3,XX4,$3e,$16,$0e,$1c,$1e,$14,XX1,XX2,$7e,$12,$4e,$18,$00,$00	//3x	Wanted List $3e-$52 (Sector 15 = #$ff)
.byte	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$00	//4x	(0) unfetched, (+) fetched, (-) wanted
.byte	$00,$00,$00,$0e,$12,$0f,$c5,$07,$ff,$01,$01,$0a,XX3,$0b,$00,$03	//5x 
.byte	$01,$00,$14,$00,XX4,$0d,$1e,$05,$00,XX1,XX2,$00,XX4,$09,$00,$01	//6x	$60-$64 - ILTab
.byte	XX4,XX1,XX2,$06,$02,$0c,$00,$04,$00,XX3,XX4,$02,XX1,$08,$00,$fd	//7x 
.byte	$fd,$fd,$04,$fc,XX2,XX3						//8x	LastT, LastS, SCtr, BPtr
}