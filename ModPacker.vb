Friend Module ModPacker
    Structure Sequence
        Public Len As Integer           'Length of the sequence in bytes (0 based)
        Public Off As Integer           'Offset of Match sequence in bytes (1 based), 0 if Literal Sequence
        Public Nibbles As Integer
        Public TotalBits As Integer     'Total Bits in Buffer
    End Structure

    Private ReadOnly AllowShortMidMatches As Boolean = False

    Public BytePtr As Integer           'Buffer Byte Stream Pointer
    Public BitPtr As Integer            'Buffer Bit Stream Pointer
    Public NibblePtr As Integer         'Buffer 4Bit Stream Pointer
    Public BitPos As Integer            'Bit Position in the Bit Stream byte
    Public BitsLeft As Integer          'Bits left in BitPtr

    Public TotalBits As Integer = 0

    Public TotLits, TotSM, TotMM, TotLM As Integer

    Private TransitionalBlock As Boolean

    Private ReadOnly MatchSelector As Integer = 1
    Private ReadOnly LitSelector As Integer = 0

    Private ReadOnly LongMatchTag As Byte = &HF8    'Could be changed to &H00, but this is more economical
    Private ReadOnly NextFileTag As Byte = &HFC
    Private ReadOnly EndTag As Byte = 0             'Could be changed to &HF8, but this is more economical (Number of EndTags > Number of LongMatchTags)

    Private FirstLitOfBlock As Boolean = False      'If true, this is the first block of next file in same buffer, Lit Selector Bit NOT NEEEDED
    Private NextFileInBuffer As Boolean = False     'Indicates whether the next file is added to the same buffer

    Private BlockUnderIO As Integer = 0
    Private AdLoPos As Byte, AdHiPos As Byte

    'Match offset and length are 1 based
    Private ReadOnly MaxMidOffset As Integer = 255 + 1 'Offset will be decreased by 1 when saved
    Private ReadOnly MaxShortOffset As Integer = 63 + 1

    Private ReadOnly MaxLongLen As Byte = 254 + 1   'Cannot be 255, there is an INY in the decompression ASM code, and that would make YR=#$00
    'Private ReadOnly MaxMidLen As Byte = &H1F - 2 + 1     'Cannot be more than 29 because 30=LongMatchTag, 31=NextFileTage
    Private ReadOnly MaxMidLen As Byte = 61 + 1     'Cannot be more than 61 because 62=LongMatchTag, 63=NextFileTage
    Private ReadOnly MaxShortLen As Byte = 3 + 1    '1-3, cannot be 0 because it is preserved for EndTag

    Private ReadOnly MaxLitLen As Integer = 16

    Private MatchBytes As Integer = 0
    Private MatchBits As Integer = 0
    Private LitBits As Integer = 0
    Private MLen As Integer = 0
    Private MOff As Integer = 0

    Private ReadOnly MaxBits As Integer = 2048
    Private ReadOnly MaxLitPerBlock As Integer = 251 - 1     'Maximum number of literals that fits in a block, LitCnt is 0-based
    '256 - (AdLo, AdHi , 1 Bit, 1 Nibble, Number of Lits)

    Private Seq() As Sequence           'Sequence array, to find the best sequence
    Private SL(), SO(), LL(), LO() As Integer
    Private SI As Integer               'Sequence array index
    Private LitSI As Integer            'Sequence array index of last literal sequence
    Private StartPtr As Integer

    'Private Cycles As Integer
    'Private BitStreamBytes As Integer
    Public Sub PackFile(PN As Byte(), Optional FA As String = "", Optional FUIO As Boolean = False)
        If DoOnErr Then On Error GoTo Err

        '----------------------------------------------------------------------------------------------------------
        'PROCESS FILE
        '----------------------------------------------------------------------------------------------------------

        Prg = PN
        FileUnderIO = FUIO
        PrgAdd = Convert.ToInt32(FA, 16)
        PrgLen = Prg.Length

        ReDim SL(PrgLen - 1), SO(PrgLen - 1), LL(PrgLen - 1), LO(PrgLen - 1)
        ReDim Seq(PrgLen)       'This is actually one element more in the array, to have starter element with 0 values

        With Seq(0)             'Initialize first element of sequence - WAS Seq(1)!!!
            '.Len = 0           '1 Literal byte, Len is 0 based
            '.Off = 0           'Offset=0 -> literal sequence, Off is 1 based
            .TotalBits = 10     'LitLen bit + 8 bits, DO NOT CHANGE IT TO 9!!!
        End With

        '----------------------------------------------------------------------------------------------------------
        'CALCULATE BEST SEQUENCE
        '----------------------------------------------------------------------------------------------------------

        CalcBestSequence(PrgLen - 1, 1, True)     'SeqLowestIndex is 1 because Prg(0) is always 1 literal on its own, we need at lease 2 bytes for a match

        '----------------------------------------------------------------------------------------------------------
        'DETECT BUFFER STATUS AND INITIALIZE COMPRESSION
        '----------------------------------------------------------------------------------------------------------

        FirstLitOfBlock = True                                      'First block of next file in same buffer, Lit Selector Bit NOT NEEEDED

        If BytePtr = 255 Then
            NextFileInBuffer = False                                'This is the first file that is being added to an empty buffer
        Else
            NextFileInBuffer = True                                 'Next file is being added to buffer that already has data
        End If

        If NewBundle Then
            TransitionalBlock = True                                'New bundle, this is a transitional block
            BlockPtr = ByteSt.Count                                 'If this is a new bundle, store Block Counter Pointer
            NewBundle = False
        End If

        Buffer(BytePtr) = (PrgAdd + PrgLen - 1) Mod 256             'Add Address Hi Byte
        AdLoPos = BytePtr

        If CheckIO(PrgLen - 1) = 1 Then                             'Check if last byte of block is under IO or in ZP
            BlockUnderIO = 1                                        'Yes, set BUIO flag
            BytePtr -= 1                                            'And skip 1 byte (=0) for IO Flag
        Else
            BlockUnderIO = 0
        End If

        Buffer(BytePtr - 1) = Int((PrgAdd + PrgLen - 1) / 256)      'Add Address Lo Byte
        AdHiPos = BytePtr - 1

        BytePtr -= 2
        LastByte = BytePtr          'The first byte of the ByteStream after (BlockCnt and IO Flag and) Address Bytes (251..253)

        '----------------------------------------------------------------------------------------------------------
        'COMPRESS FILE
        '----------------------------------------------------------------------------------------------------------

        Pack()

        Exit Sub
Err:
        ErrCode = Err.Number
        MsgBox(ErrorToString(), vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")

    End Sub

    Private Sub CalcBestSequence(SeqHighestIndex As Integer, SeqLowestIndex As Integer, Optional FirstRun As Boolean = False)
        If DoOnErr Then On Error GoTo Err

        Dim MaxO, MaxL, MaxLL, MaxSL As Integer
        Dim SeqLen, SeqOff As Integer

        '----------------------------------------------------------------------------------------------------------
        'CALCULATE MAX MATCH LENGTHS AND OFFSETS FOR EACH POSITION
        '----------------------------------------------------------------------------------------------------------

        'Pos = Min>0 to Max value, direction of execution is arbitrary (could be Max to Min>0 Step -1)
        For Pos As Integer = SeqLowestIndex To SeqHighestIndex         'Pos cannot be 0, Prg(0) is always literal as it is always 1 byte left

            MaxLL = If(Pos >= MaxLongLen - 1, MaxLongLen, Pos + 1)
            MaxSL = If(Pos >= MaxShortLen - 1, MaxShortLen, Pos + 1)

            'Offset goes from 1 to max offset (cannot be 0)
            MaxO = If(Pos + MaxMidOffset < SeqHighestIndex, MaxMidOffset, SeqHighestIndex - Pos)    'MaxO=256 or less
            'Match length goes from 1 to max length
            'If (SL(Pos) > 0) And (SL(Pos) >= LL(Pos)) Then
            'MaxL = If(Pos >= MaxShortLen - 1, MaxShortLen, Pos + 1)  'MaxL=255 or less
            'Else
            MaxL = If(Pos >= MaxLongLen - 1, MaxLongLen, Pos + 1)  'MaxL=255 or less
            'End If

            If (FirstRun) Or (SL(Pos) > 0) Or (LL(Pos) > 0) Then
                SO(Pos) = 0
                SL(Pos) = 0
                LO(Pos) = 0
                LL(Pos) = 0

                'Dim O As Integer = 1

                'While (O <= MaxO) And (LL(Pos) < MaxLL) And (SL(Pos) < MaxSL)
                ''Check if first byte matches at offset, if not go to next offset
                'If Prg(Pos) = Prg(Pos + O) Then
                'Dim L As Integer = 1
                'While (Prg(Pos - L) = Prg(Pos + O - L))
                'L += 1
                'If L = MaxL Then Exit While
                'End While
                'If L >= 2 Then
                'If O <= MaxShortOffset Then
                'If (SL(Pos) < MaxShortLen) And (SL(Pos) < L) Then
                'SL(Pos) = If(L > MaxShortLen, MaxShortLen, L)   'Short matches cannot be longer than 4 bytes
                'SO(Pos) = O       'Keep Offset 1-based
                'End If
                'If LL(Pos) < L Then
                'LL(Pos) = L
                'LO(Pos) = O
                'End If
                'Else
                'If (LL(Pos) < L) And (L > 2) Then 'Skip short (2-byte) Mid Matches
                'LL(Pos) = L
                'LO(Pos) = O
                'End If
                'End If
                'End If
                'End If
                'O += 1
                'End While

                For O As Integer = 1 To MaxO                                    'O=1 to 255 or less
                    'Check if first byte matches at offset, if not go to next offset
                    If Prg(Pos) = Prg(Pos + O) Then
                        For L As Integer = 1 To MaxL                            'L=1 to 254 or less
                            If L = MaxL Then
                                GoTo Match
                            ElseIf Prg(Pos - L) <> Prg(Pos + O - L) Then
                                'Find the first position where there is NO match -> this will give us the absolute length of the match
                                'L=MatchLength + 1 here
                                If L >= 2 Then
Match:                              If O <= MaxShortOffset Then
                                        If (SL(Pos) < MaxShortLen) And (SL(Pos) < L) Then
                                            SL(Pos) = If(L > MaxShortLen, MaxShortLen, L)   'Short matches cannot be longer than 4 bytes
                                            SO(Pos) = O       'Keep Offset 1-based
                                        End If
                                        'If LL(Pos) < L Then
                                        'LL(Pos) = L
                                        'LO(Pos) = O
                                    End If
                                    'Else
                                    If AllowShortMidMatches Then
                                        If (LL(Pos) < L) Then 'Allow short (2-byte) Mid Matches
                                            LL(Pos) = L
                                            LO(Pos) = O
                                        End If
                                    Else
                                        If (LL(Pos) < L) And (L > 2) Then 'Skip short (2-byte) Mid Matches
                                            LL(Pos) = L
                                            LO(Pos) = O
                                        End If
                                    End If
                                    'End If
                                End If
                                Exit For
                            End If
                        Next
                        'If both short and long matches maxed out, we can leave the loop and go to the next Prg position
                        If (LL(Pos) = MaxLL) And (SL(Pos) = MaxSL) Then
                            Exit For
                        End If
                    End If
                Next
            End If
            'Next

            '----------------------------------------------------------------------------------------------------------
            'FIND BEST SEQUENCE FOR EACH POSITION
            '----------------------------------------------------------------------------------------------------------

            'For Pos As Integer = SeqLowestIndex To SeqHighestIndex     'Start with second element, first has been initialized  above

            Seq(Pos + 1).TotalBits = &HFFFFFF       'Max block size=100 = $10000 bytes = $80000 bits, make default larger than this

            If LL(Pos) <> 0 Then                    'TODO: check if there is a more optimal way...
                CheckMatchSeq(LL(Pos), LO(Pos), Pos)
            End If
            If SL(Pos) <> 0 Then
                CheckMatchSeq(SL(Pos), SO(Pos), Pos)
            End If
            'Both LL(Pos) and SL(Pos) are 0, so this is a literal byte
            If (LL(Pos) = 0) And (SL(Pos) = 0) Then
                CheckLitSeq(Pos)
            End If

        Next

        Exit Sub
Err:
        ErrCode = Err.Number
        MsgBox(ErrorToString(), vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")

    End Sub

    Private Sub CheckMatchSeq(SeqLen As Integer, SeqOff As Integer, Pos As Integer)
        If DoOnErr Then On Error GoTo Err
        Dim TotBits As Integer

        'Check all possible lengths
        For L As Integer = SeqLen To 2 Step -1
            'Calculate MatchBits
            MatchBits = If((L <= MaxShortLen) And (SeqOff <= MaxShortOffset), 8 + 1, If(L <= MaxMidLen, 16 + 1, 24 + 1))

            'Calculate total bit count, independently of nibble status
            TotBits = Seq(Pos + 1 - L).TotalBits + MatchBits

            With Seq(Pos + 1)
                'See if total bit count is better than best version
                If TotBits < .TotalBits Then
                    'If better, update best version
                    .Len = L            'MatchLen is 1 based
                    .Off = SeqOff       'Off is 1 based
                    .Nibbles = Seq(Pos + 1 - L).Nibbles
                    .TotalBits = TotBits
                End If
            End With
        Next

        CheckLitSeq(Pos)

        Exit Sub
Err:
        ErrCode = Err.Number
        MsgBox(ErrorToString(), vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")

    End Sub

    Private Sub CheckLitSeq(Pos As Integer)
        If DoOnErr Then On Error GoTo Err

        Dim TotBits As Integer

        'Continue previous Lit sequence or start new sequence
        LitCnt = If(Seq(Pos).Off = 0, Seq(Pos).Len, -1)

        'Calculate literal bits for a presumtive LitCnt+1 value
        LitBits = Int((LitCnt + 1) / MaxLitPerBlock) * 13
        Select Case (LitCnt + 1) Mod MaxLitPerBlock
            Case 0
                LitBits += 1                       'Lits = 0	1 literal, 1 bit
            Case 1 To MaxLitLen - 1
                LitBits += 5                       'Lits = 1-15	2-16 literals, 5 bits
            Case Else
                LitBits += 13                      'Lits = 16-250	17-251 literals, 13 bits
        End Select

        'LITERALS ARE ALWAYS FOLLOWED BY MATCHES, SO TYPE SELECTOR BIT IS NOT NEEDED AFTER LITERALS AT ALL

        TotBits = Seq(Pos - LitCnt - 1).TotalBits + LitBits + ((LitCnt + 2) * 8)

        With Seq(Pos + 1)
            'See if total bit count is less than best version
            If TotBits < .TotalBits Then
                'and save it to sequence at Pos+1 (position is 1 based)
                .Len = LitCnt + 1       'LitCnt is 0 based, LitLen is 0 based
                .Off = 0                'An offset of 0 marks a literal sequence, match offset is 1 based
                .Nibbles = Seq(Pos - (LitCnt + 1)).Nibbles + If(LitBits > 1, 1, 0)
                .TotalBits = TotBits
            End If
        End With

        Exit Sub
Err:
        ErrCode = Err.Number
        MsgBox(ErrorToString(), vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")

    End Sub

    Private Sub Pack()
        If DoOnErr Then On Error GoTo Err

        'Packing is done backwards

        Dim BufferFull As Boolean

        SI = PrgLen - 1
        StartPtr = SI

        'Cycles += 61 'From NextFile label
        'BitStreamBytes = 0

Restart:
        Do

            If Seq(SI + 1).Off = 0 Then
                '--------------------------------------------------------------------
                'Literal sequence
                '--------------------------------------------------------------------
                LitCnt = Seq(SI + 1).Len                'LitCnt is 0 based
                LitSI = SI
                MLen = 0                                'Reset MLen - this is needed for accurate bit counting in sequencefits

                'The max number of literals that fit in a single buffer is 249 bytes
                'This bypasses longer literal sequences and improves compression speed
                BufferFull = False

                'Shortcut to bypass long literal sequences that wouldn't fit in the buffer anyway
                If LitCnt > BytePtr Then    'MaxLitPerBlock Then
                    BufferFull = True
                    LitCnt = BytePtr        'MaxLitPerBlock
                End If

                Do While LitCnt > -1
                    If SequenceFits(LitCnt + 1, CalcLitBits(LitCnt), CheckIO(SI - LitCnt)) = True Then
                        Exit Do
                    End If
                    LitCnt -= 1
                    BufferFull = True
                Loop

                'Go to next element in sequence
                SI -= LitCnt + 1    'If nothing added to the buffer, LitCnt=-1+1=0

                If BufferFull = True Then
                    AddLitSequence()
                    CloseBuffer()   'The whole literal sequence did not fit, buffer is full, close it
                End If

            Else
                '--------------------------------------------------------------------
                'Match sequence
                '--------------------------------------------------------------------

                BufferFull = False

                MLen = Seq(SI + 1).Len      '1 based
                MOff = Seq(SI + 1).Off      '1 based
Match:
                CalcMatchBytesAndBits(MLen, MOff)
                If MatchBytes = 3 Then
                    '--------------------------------------------------------------------
                    'Long Match - 3 match bytes + 0/1 match bit
                    '--------------------------------------------------------------------
                    If SequenceFits(3 + LitCnt + 1, MatchBits + CalcLitBits(LitCnt), CheckIO(SI - MLen + 1)) Then
                        AddLitSequence()
                        'Add long match
                        AddLongMatch()
                    Else
                        MLen = MaxMidLen
                        BufferFull = True   'Buffer if full, we will need to close it
                        GoTo CheckMid
                    End If
                ElseIf MatchBytes = 2 Then
                    '--------------------------------------------------------------------
                    'Mid Match - 2 match bytes + 0/1 match bit
                    '--------------------------------------------------------------------
CheckMid:           If SequenceFits(2 + LitCnt + 1, MatchBits + CalcLitBits(LitCnt), CheckIO(SI - MLen + 1)) Then
                        AddLitSequence()
                        'Add mid match
                        AddMidMatch()
                    Else
                        BufferFull = True
                        If SO(SI) <> 0 Then
                            MLen = SL(SI)   'SL and SO array indeces are 0 based
                            MOff = SO(SI)
                            GoTo CheckShort
                        Else
                            GoTo CheckLit
                        End If  'Short vs Literal
                    End If      'Mid vs Short
                Else
                    '--------------------------------------------------------------------
                    'Short Match - 1 match byte + 0/1 match bit
                    '--------------------------------------------------------------------
CheckShort:         If SequenceFits(1 + LitCnt + 1, MatchBits + CalcLitBits(LitCnt), CheckIO(SI - MLen + 1)) Then
                        AddLitSequence()
                        'Add short match
                        AddShortMatch()
                    Else
                        '--------------------------------------------------------------------
                        'Match does not fit, check if 1 literal byte fits
                        '--------------------------------------------------------------------
                        BufferFull = True
CheckLit:               MLen = 0    'This is needed here for accurate Bit count calculation in sequencefits (indicates Literal, not Match)
                        If SequenceFits(1 + LitCnt + 1, CalcLitBits(LitCnt + 1), CheckIO(SI - LitCnt)) Then
                            If LitCnt = -1 Then
                                'If no literals, current SI will be LitSI, else, do not change LitSi
                                LitSI = SI
                            End If
                            LitCnt += 1     '0 based, now add 1 for an additional literal (first byte of match that did not fit)
                            SI -= 1         'Rest of LitCnt has been already subtracted from SI
                        End If  'Literal vs nothing
                    End If      'Short match vs literal
                End If          'Long, mid, or short match
Done:
                SI -= MLen

                If BufferFull Then
                    AddLitSequence()
                    CloseBuffer()
                End If
            End If              'Lit vs match

        Loop While SI >= 0

        AddLitSequence()        'See if any remaining literals need to be added, space has been previously reserved for them

        Exit Sub
Err:
        ErrCode = Err.Number
        MsgBox(ErrorToString(), vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")

    End Sub

    Private Sub CalcMatchBytesAndBits(Length As Integer, Offset As Integer) 'Match Length is 1 based
        If DoOnErr Then On Error GoTo Err

        If (Length <= MaxShortLen) And (Offset <= MaxShortOffset) Then
            MatchBytes = 1
        ElseIf Length <= MaxMidLen Then
            MatchBytes = 2
        Else
            MatchBytes = 3
        End If

        MatchBits = If(LitCnt = -1, 1, 0)

        Exit Sub
Err:
        ErrCode = Err.Number
        MsgBox(ErrorToString(), vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")

    End Sub

    Private Function CalcLitBits(Lits As Integer) As Integer     'LitCnt is 0 based
        If DoOnErr Then On Error GoTo Err

        If Lits = -1 Then
            CalcLitBits = 0                       'Lits = -1		no literals, 0 bit
        ElseIf Lits = 0 Then
            CalcLitBits = 2                       'Lits = 0		one literal, 1 bit
        ElseIf Lits < MaxLitLen Then
            CalcLitBits = 6                       'Lits = 1-15		2-16 literals, 5 bits
        Else
            CalcLitBits = 14                      'Lits = 15-250	17-251 literals, 13 bits
        End If

        'BUGFIX: The very first literal sequence of a file or block does not need a type selector bit
        'As we always start with at least one literal byte
        If (FirstLitOfBlock) And (CalcLitBits > 0) Then CalcLitBits -= 1

        LitBits = CalcLitBits

        Exit Function
Err:
        ErrCode = Err.Number
        MsgBox(ErrorToString(), vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")

    End Function

    Private Function SequenceFits(BytesToAdd As Integer, BitsToAdd As Integer, Optional SequenceUnderIO As Integer = 0) As Boolean
        If DoOnErr Then On Error GoTo Err

        Dim BytesFree As Integer = BytePtr      '1,2,3,...,BytePtr-1,BytePtr

        'If (TransitionalBlock = True) Or (BufferCnt = 0) Then
        'BytesFree -= 1
        'End If

        'If this is a transitional block (including block 0 on disk) then we need 1 byte for block count (will be overwritten by Close Byte

        If (TransitionalBlock = True) Or (BufferCnt = 0) Then
            BytesFree -= 1
        End If

        Dim BitsFree As Integer = BitsLeft ' BitPos + If(BitPtr <> 0, 1, 0)    '0-8
        'BitsFree = BitsLeft

        'Add IO Byte ONLY if this is the first sequence in the block that goes under IO
        BytesToAdd += If((BlockUnderIO = 0) And (SequenceUnderIO = 1), 1, 0)

        'Check if we have literal sequences >1 which have bits stored in nibbles
        'BUGFIX: first literal sequence of a block/file has one less bits than any other seuqences, so comparision must be made with 5 instead of 6
        If BitsToAdd >= 5 Then
            If NibblePtr = 0 Then 'If NibblePtr Points at buffer(0) then we need to add 1 byte for a new NibblePtr position in the buffer
                BytesFree -= 1
            End If
            BitsToAdd -= 4      '4 bits less to store in the BitPtr
        End If

        'Add Match/Close Bit if the last sequence was a match
        BitsToAdd += If(MLen > 0, 1, 0)

        BytesToAdd += Int(BitsToAdd / 8)
        BitsToAdd = BitsToAdd Mod 8

        If BitsFree - BitsToAdd < 0 Then BytesToAdd += 1

        If BytesFree >= BytesToAdd Then
            'Check if sequence will fit within block size limits
            SequenceFits = True
            'Data will fit
            If (BlockUnderIO = 0) And (SequenceUnderIO = 1) Then
                'This is the first byte in the block that will go UIO, so lets update the buffer to include the IO flag
                For I As Integer = BytePtr To AdHiPos   'Move all data to the left in buffer, including AdHi
                    Buffer(I - 1) = Buffer(I)
                Next
                Buffer(AdHiPos) = 0                     'IO Flag to previous AdHi Position
                BytePtr -= 1                            'Update BytePtr to next empty position in buffer
                If NibblePtr > 0 Then NibblePtr -= 1    'Only update Nibble Pointer if it does not point to Byte(0)
                If BitPtr > 0 Then BitPtr -= 1          'BitPtr also needs to be moved BUT ONLY IF > 0 - BUG reported by Raistlin/G*P
                AdHiPos -= 1                            'Update AdHi Position in Buffer
                BlockUnderIO = 1                        'Set BlockUnderIO Flag
            End If
        Else
            SequenceFits = False
        End If

        Exit Function
Err:
        ErrCode = Err.Number
        MsgBox(ErrorToString(), vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")

        SequenceFits = False

    End Function

    Private Sub AddMatchBit()
        If DoOnErr Then On Error GoTo Err

        If LitCnt = -1 Then
            AddBits(MatchSelector, 1)   'Last Literal Length was -1, we need the Match selector bit (1)
            'Cycles += 10
        End If

        LitCnt = -1

        Exit Sub
Err:
        ErrCode = Err.Number
        MsgBox(ErrorToString(), vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")

    End Sub

    Private Sub AddLongMatch()
        If DoOnErr Then On Error GoTo Err

        TotMatch += 1

        AddMatchBit()

        Buffer(BytePtr) = LongMatchTag                   'Long Match Flag = &HF8
        Buffer(BytePtr - 1) = MLen - 1
        Buffer(BytePtr - 2) = MOff - 1
        BytePtr -= 3

        'Cycles += 77 + (15 * MLen)

        TotLM += 1

        Exit Sub
Err:
        ErrCode = Err.Number
        MsgBox(ErrorToString(), vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")

    End Sub

    Private Sub AddMidMatch()
        If DoOnErr Then On Error GoTo Err

        TotMatch += 1

        AddMatchBit()

        Buffer(BytePtr) = (MLen - 1) * 4    'Length of match (#$02-#$3f, cannot be #$00 (end byte), and #$01 - distant selector??)
        Buffer(BytePtr - 1) = MOff - 1
        BytePtr -= 2

        'Cycles += 67 + (15 * MLen)

        TotMM += 1

        Exit Sub
Err:
        ErrCode = Err.Number
        MsgBox(ErrorToString(), vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")

    End Sub

    Private Sub AddShortMatch()
        If DoOnErr Then On Error GoTo Err

        TotMatch += 1

        AddMatchBit()

        Buffer(BytePtr) = ((MOff - 1) * 4) + (MLen - 1)
        BytePtr -= 1

        'Cycles += 54 + (15 * MLen)

        TotSM += 1

        Exit Sub
Err:
        ErrCode = Err.Number
        MsgBox(ErrorToString(), vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")

    End Sub

    Private Sub AddLitSequence()
        If DoOnErr Then On Error GoTo Err

        If LitCnt = -1 Then Exit Sub

        Dim Lits As Integer = LitCnt

        If Lits >= MaxLitLen Then
            AddLitBits(MaxLitLen)
            'Then add number of literals as a byte
            Buffer(BytePtr) = Lits ' + 1
            BytePtr -= 1
        Else
            'Add literal bits for 1-15 literals
            AddLitBits(Lits)
        End If

        'Then add literal bytes
        For I As Integer = 0 To Lits
            Buffer(BytePtr - I) = Prg(LitSI - I)
        Next

        BytePtr -= Lits + 1
        LitSI -= Lits + 1
        Lits = -1

        TotLits += 1

        'DO NOT RESET LITCNT HERE, IT IS NEEDED AT THE SUBSEQUENT MATCH TO SEE IF A MATCHTAG IS NEEDED!!!

        Exit Sub
Err:
        ErrCode = Err.Number
        MsgBox(ErrorToString() + vbNewLine + BundleCnt.ToString + vbNewLine + BlockCnt.ToString + vbNewLine + BytePtr.ToString + vbNewLine + LitCnt.ToString, vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")

    End Sub

    Private Sub AddLitBits(Lits As Integer)
        If DoOnErr Then On Error GoTo Err

        'We are never adding more than MaxLitBit number of bits here

        If Lits = -1 Then Exit Sub    'We only call this routine with LitCnt>-1

        'This is only for statistics
        'TotLit += Int(Lits / (MaxLitLen + 1)) + 1

        If FirstLitOfBlock = False Then
            AddBits(LitSelector, 1)               'Add Literal Selector if this is not the first (Literal) byte in the buffer
            'Cycles += 8
        Else
            FirstLitOfBlock = False
        End If

        Select Case Lits
            Case 0
                AddBits(0, 1)               'Add Literal Length Selector 0 - read no more bits
        'Cycles += 52
            Case 1 To MaxLitLen - 1
                AddBits(1, 1)               'Add Literal Length Selector 1 - read 4 more bits
                AddNibble(Lits)             'Add Literal Length: 01-0f, 4 bits (0001-1111)
        'Cycles += 62 + ((Lits + 1) * 15)
            Case MaxLitLen
                AddBits(1, 1)               'Add Literal Length Selector 1 - read 4 more bits
                AddNibble(0)                'Add Literal Length: 0, 4 bits (0000) - we will have a longer literal sequence
                'Cycles += 72 + ((Lits + 1) * 15)
        End Select

        'DO NOT RESET LitCnt HERE!!!

        Exit Sub
Err:
        ErrCode = Err.Number
        MsgBox(ErrorToString(), vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")

    End Sub
    Private Sub AddNibble(Bit As Integer)
        If DoOnErr Then On Error GoTo Err

        If NibblePtr = 0 Then
            NibblePtr = BytePtr
            BytePtr -= 1
            Buffer(NibblePtr) = Bit
        Else
            Buffer(NibblePtr) += Bit * 16
            NibblePtr = 0
        End If

        Exit Sub
Err:
        ErrCode = Err.Number
        MsgBox(ErrorToString(), vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")

    End Sub

    Private Sub AddBits(Bit As Integer, BCnt As Byte)
        If DoOnErr Then On Error GoTo Err

        For I As Integer = BCnt - 1 To 0 Step -1
            If BitPos < 0 Then
                BitPos += 8
                BitsLeft = 8
                BitPtr = BytePtr    'New BitPtr pos
                BytePtr -= 1        'and BytePtr pos
                'BitStreamBytes += 1 'Number of bitstream bytes in buffer
            End If
            If (Bit And 2 ^ I) <> 0 Then
                Buffer(BitPtr) = Buffer(BitPtr) Or 2 ^ BitPos
            End If
DecBitPos:
            BitPos -= 1
            BitsLeft -= 1
            If BitPos = 0 Then
                If (Buffer(BitPtr) Mod 2 = 1) Then
                    'MsgBox(Hex(BitPtr))
                    BitPos = -1
                End If
            End If
            'Very first BitPtr in buffer has a 1 in BitPos=0 (Token Bit) -> Skip It!!!
            'If (BitPtr = 0) And (BitPos = 0) Then BitPos = -1
        Next

        'MsgBox(BufferCnt.ToString + vbNewLine + BitPtr.ToString + vbNewLine + BitPos.ToString + vbNewLine + BitsLeft.ToString)

        Exit Sub
Err:
        ErrCode = Err.Number
        MsgBox(ErrorToString(), vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")

    End Sub

    Public Function CloseBuffer() As Boolean
        If DoOnErr Then On Error GoTo Err

        CloseBuffer = True

        'Buffer(BytePtr) = EndTag            'Not needed, byte 0 will be overwritten to EndTag during loading
        AddMatchBit()

        'Cycles += 19
        'Cycles += BitStreamBytes * 14

        'Debug.Print(BufferCnt.ToString + vbTab + Cycles.ToString)

        BlockCnt += 1
        BufferCnt += 1

        'This does not work here yet, Pack needs to be changed to a function
        'If BufferCnt > BlocksFree Then
        'MsgBox("Unable to add bundle to disk :(", vbOKOnly, "Not enough free space on disk")
        'GoTo NoDisk
        'End If

        UpdateByteStream()

        ResetBuffer()                       'Resets buffer variables

        NextFileInBuffer = False            'Reset Next File flag

        TransitionalBlock = False           'Only the first block of a bundle is a transitional block

        FirstLitOfBlock = True

        If SI < 0 Then Exit Function             'We have reached the end of the file -> exit

        'If we have not reached the end of the file, then update buffer

        'If PrgAdd + SI = &HFDE6 Then MsgBox(MLen.ToString)

        Buffer(BytePtr) = (PrgAdd + SI) Mod 256
        AdLoPos = BytePtr

        BlockUnderIO = CheckIO(SI)          'Check if last byte of prg could go under IO

        If BlockUnderIO = 1 Then
            BytePtr -= 1
        End If

        Buffer(BytePtr - 1) = Int((PrgAdd + SI) / 256) Mod 256
        AdHiPos = BytePtr - 1
        BytePtr -= 2
        LastByte = BytePtr              'LastByte = the first byte of the ByteStream after and Address Bytes (253 or 252 with blockCnt)

        '------------------------------------------------------------------------------------------------------------------------------
        '"COLOR BUG"
        'Compression bug related to the transitional block (i.e. finding the last block of a bundle) - FIXED
        'Fix: add 5 or 6 bytes + 2 bits to the calculation to find the last block of a bundle
        '+2 new bundle tag, +2 NEXT Bundle address, +1 first literal byte of NEXT Bundle, +0/1 IO status of first literal byte of NEXT file
        '+1 literal bit, +1 match bit (may or may not be needed, but we don't know until the end...)
        '------------------------------------------------------------------------------------------------------------------------------

        'Check if the first literal byte of the NEXT Bundle will go under I/O
        'Bits needed for next bundle is calculated in ModDisk:SortPart
        '(Next block = Second block) or (remaining bits of Last File in Bundle + Needed Bits fit in this block)

        'LETHARGY BUG - Bits Left need to be calculated from Seq(SI+1) and NOT Seq(SI)
        'Add 4 bits if number of nibbles is odd
        Dim BitsLeftFree As Integer = Seq(SI + 1).TotalBits + ((Seq(SI + 1).Nibbles Mod 2) * 4)

        BitsNeededForNextBundle += If(MLen = 0, 0, 1)   'If last sequence was a Match, we also need a Match Bit

        'If the next block is the first one on a new track, no need to recalculate the sequence
        'As all previous blocks will be loaded from the previous track before this block gets loaded
        Dim NewTrack As Boolean = False
        If BufferCnt < (17 * 21) Then

            If BufferCnt Mod 21 = 0 Then NewTrack = True

        ElseIf BufferCnt < ((17 * 21) + (6 * 19)) Then

            If (BufferCnt - (17 * 21)) Mod 19 = 0 Then NewTrack = True

        ElseIf BufferCnt < ((17 * 21) + (6 * 19) + (6 * 18)) Then

            If (BufferCnt - (17 * 21) - (6 * 19)) Mod 18 = 0 Then NewTrack = True

        Else

            If (BufferCnt - (17 * 21) - (6 * 19) - (6 * 18)) Mod 17 = 0 Then NewTrack = True

        End If

        'If NewCalc = False Then
        'BitsLeftFree = Seq(SI).TotalBits
        'End If
        If (BlockCnt = 1) Or (NewTrack = True) Or ((BitsLeftFree + BitsNeededForNextBundle <= ((LastByte - 1) * 8) + BitPos) And (LastFileOfBundle = True) And (NewBlock = False)) Then
            'Seq(SI+1).Bytes/Nibbles/Bits = to calculate remaining bits in file
            'BitsNeededForNextBundle (5-6 bytes + 1/2 bits)
            '+5/6 bytes +1/2 bits
            'LastByte-1: subtract close tag/block count = Byte(1)
            'Bits remaining in block: LastByte * 8 (+ remaining bits in last BitPtr (BitPos+1))
            'But we are trying to overcalculate here to avoid misidentification of the last block
            'Which would result in buggy decompression

            'This is the last block ONLY IF the remainder of the bundle + the next bundle's info fits!!!
            'AND THE NEXT Bundle IS NOT ALIGNED in which case the next block is the last one
            'Seg(SI).bit includes both the byte stream in bits and the bit stream (total bits needed to compress the remainder of the bundle)
            '+Close Tag: 8 bits
            '+BitsNeeded: 5-6 bytes for next bundle's info + 1 lit bit +/- 1 match bit (may or may not be needed, but we wouldn't know until the end)
            'For the 2nd and last blocks of a bundle and the first blocks on a new track only recalculate the first byte's sequence
            'If BlockCnt <> 1 Then MsgBox((BitsLeftFree + BitsNeededForNextBundle).ToString + vbNewLine + (Seq(SI + 1).TotalBits + BitsNeededForNextBundle).ToString + vbNewLine + ((LastByte - 1) * 8 + BitPos).ToString)
            'Only recalculate the very first byte's sequence
            CalcBestSequence(If(SI > 1, SI, 1), If(SI > 1, SI, 1))
            If BlockCnt <> 1 Then
                BitsLeftFree = Seq(SI + 1).TotalBits + ((Seq(SI + 1).Nibbles Mod 2) * 4)
                'If the new bit count does not fit in the buffer then this is NOT the last block -> recalc sequence
                If BitsLeftFree + BitsNeededForNextBundle > ((LastByte - 1) * 8) + BitPos Then GoTo CalcAll
            End If
        Else
            'For all other blocks recalculate the first 256 bytes' sequence (max offset=256)
CalcAll:
            CalcBestSequence(If(SI > 1, SI, 1), If(SI - MaxMidOffset > 1, SI - MaxMidOffset, 1))
        End If

        StartPtr = SI

        Exit Function
Err:
        ErrCode = Err.Number
        MsgBox(ErrorToString(), vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")
NoDisk:
        CloseBuffer = False

    End Function

    Public Function CloseBundle(Optional NextFileIO As Integer = 0, Optional LastPartOnDisk As Boolean = False, Optional FromEditor As Boolean = False) As Boolean
        If DoOnErr Then On Error GoTo Err

        CloseBundle = True

        If NewBlock = True Then GoTo NewB   'The bundle will start in a new block

        'ADDS NEW Bundle TAG (Long Match Tag + End Tag) TO THE END OF THE Bundle

        '-----------------------------------------------------------------------------------
        '"SPRITE BUG"
        'Compression bug related to the transitional block - FIXED
        'Fix: include NEXT file's I/O status in calculation of needed bytes
        '-----------------------------------------------------------------------------------

        'BYTES NEEDED: Long Match Tag + End Tag + BitPtr+ AdLo + AdHi + 1st Literal + 1 if next file goes under I/O
        'BlockCnt is no longer needed - it will be overwritten by Close Tag
        'Dim Bytes As Integer = 5 + NextFileIO
        Dim Bytes As Integer = 6 + NextFileIO

        'THE FIRST LITERAL ALSO NEEDS A LITERAL BIT
        'DO NOT ADD MATCH BIT HERE, IT WILL BE ADDED IN SequenceFits()
        'Bug fixed based on CloseFile bug reported by Visage/Lethargy
        Dim Bits As Integer = 0 '1

        'NextFileInBuffer = True

        TransitionalBlock = True    'This is always a transitional block, unless close sequence does not fit

        If SequenceFits(Bytes, Bits) Then       'This will add the EndTag to the needed bytes

            'Buffer has enough space for New Bundle Tag and New Bundle Info and first Literal byte (and IO flag if needed)

            'If last sequence was a match (no literals) then add a match bit
            If (MLen > 0) Or (LitCnt = -1) Then AddBits(1, 1)

NextPart:   'Match Bit is not needed if this is the beginning of the next block
            FilesInBuffer += 1  'There is going to be more than 1 file in the buffer

            Buffer(1) = EORtransform(0)

            NibblePtr = 0
            Buffer(BytePtr) = LongMatchTag                          'Then add New File Match Tag
            Buffer(BytePtr - 1) = EndTag
            BitPtr = BytePtr - 2
            Buffer(BitPtr) = &H1
            BytePtr -= 3
            BitPos = 7
            BitsLeft = 7

            If LastPartOnDisk = True Then       'This will finish the disk
                Buffer(BytePtr) = BytePtr - 2   'Finish disk with a dummy literal byte that overwrites itself to reset LastX for next disk side
                Buffer(BytePtr - 1) = &H3       'New address is the next byte in buffer
                Buffer(BytePtr - 2) = &H0       'Dummy $00 Literal that overwrites itself
                LitCnt = 0                      'One (dummy) literal
                'AddLitBits()                   'NOT NEEDED, WE ARE IN THE MIDDLE OF THE BUFFER, 1ST BIT NEEDS TO BE OMITTED
                AddBits(0, 1)                  'ADD 2ND BIT SEPARATELY (0-BIT, TECHNCALLY, THIS IS NOT NEEDED SINCE THIS IS THE LAST BIT)
                '-------------------------------------------------------------------
                'Buffer(ByteCnt - 3) = &H0      'THIS IS THE END TAG, NOT NEEDED HERE, WILL BE ADDED WHEN BUFFER IS CLOSED
                'ByteCnt -= 4					'*BUGFIX, THANKS TO RAISTLIN/G*P FOR REPORTING
                '-------------------------------------------------------------------
                BytePtr -= 3
                If FromEditor = False Then
                    'Only if we are NOT in the Editor AND BundleNo<128
                    If BundleNo < 128 Then
                        DirBlocks((BundleNo * 4) + 3) = BitPtr
                        DirPtr(BundleNo) = BufferCnt
                    End If
                    'Save last, "dummy" bundle info
                    LastBitPtr = BitPtr
                    LastBufferCnt = BufferCnt
                    'BundleNo += 1
                End If
            End If

            'DO NOT CLOSE LAST BUFFER HERE, WE ARE GOING TO ADD NEXT Bundle TO LAST BUFFER
            If ByteSt.Count > BlockPtr + 255 Then     'Only save block count if block is already added to ByteSt
                ByteSt(BlockPtr + 1) = EORtransform(LastBlockCnt)   'New Block Count is ByteSt(BlockPtr+1) in buffer, not ByteSt(BlockPtr+255)
                LoaderBundles += 1
            End If

            LitCnt = -1                                                 'Reset LitCnt here
        Else
NewB:       'Next File Info does not fit, so close buffer
            CloseBuffer()               'Adds EndTag and starts new buffer
            'Then add 1 dummy literal byte to new block (blocks must start with 1 literal, next bundle tag is a match tag)
            Buffer(255) = &HFD          'Dummy Address ($03fd* - first literal's address in buffer... (*NextPart above, will reserve BlockCnt)
            Buffer(254) = &H3           '...we are overwriting it with the same value
            Buffer(253) = &H0           'Dummy value, will be overwritten with itself
            LitCnt = 0
            AddLitBits(LitCnt)       'WE NEED THIS HERE, AS THIS IS THE BEGINNING OF THE BUFFER, AND 1ST BIT WILL BE CHANGED TO COMPRESSION BIT
            BytePtr = 252
            LastBlockCnt += 1

            If LastBlockCnt > 255 Then
                'Parts cannot be larger than 255 blocks compressed
                'There is some confusion here how PartCnt is used in the Editor and during Disk building...
                MsgBox("Bundle " + If(CompressBundleFromEditor = True, BundleCnt + 1, BundleCnt).ToString + " would need " + LastBlockCnt.ToString + " blocks on the disk." + vbNewLine + vbNewLine + "Bundles cannot be larger than 255 blocks!", vbOKOnly + vbCritical, "Bundle exceeds 255-block limit!")
                If CompressBundleFromEditor = False Then GoTo NoGo
            End If

            BlockCnt -= 1
            'THEN GOTO NEXT Bundle SECTION
            GoTo NextPart
        End If

        NewBlock = SetNewBlock        'NewBlock is true at closing the previous bundle, so first it just sets NewBlock2
        SetNewBlock = False            'And NewBlock2 will fire at the desired bundle

        'MsgBox(BundleCnt.ToString + vbNewLine + Hex(BitPtr))
        'DirBlocks((BundleCnt * 4) + 3) = BitPtr
        'DirPtr(BundleCnt) = BufferCnt
        'MsgBox(BundleCnt.ToString + vbNewLine + BufferCnt.ToString)
        Exit Function
Err:
        ErrCode = Err.Number
        MsgBox(ErrorToString(), vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")

NoGo:
        CloseBundle = False

    End Function

    Public Sub CloseFile()
        If DoOnErr Then On Error GoTo Err

        'ADDS NEXT FILE TAG TO BUFFER

        '4-5 bytes and 1-2 bits needed for NextFileTag, Address Bytes and first Lit byte (+1 more if UIO)
        'BYTES NEEDED: End Tag + AdLo + AdHi + 1st Literal +/- I/O FLAG of NEW FILE's 1st literal
        'BUG reported by Raistlin/G*P
        Dim Bytes As Integer = 4 + CheckIO(PrgLen - 1)

        'THE FIRST LITERAL BYTE WILL ALSO NEED A LITERAL BIT
        'DO NOT check whether Match Bit is needed for new file - will be checked in Sequencefits()
        'BUG reported by Visage/Lethargy
        Dim Bits As Integer = 1

        NextFileInBuffer = True

        If SequenceFits(Bytes, Bits) Then   'DO NOT INCLUDE NEXT NEXT FILE'S IO STATUS HERE - IT WOULD RESULT IN AN UNWANTED I/O FLAG INSERTION

            'Buffer has enough space for New File Match Tag and New File Info and first Literal byte (and I/O flag if needed)

            'If last sequence was a match (no literals) then add a match bit
            If (MLen > 0) Or (LitCnt = -1) Then AddBits(MatchSelector, 1)

            Buffer(BytePtr) = NextFileTag                           'Then add New File Match Tag
            BytePtr -= 1
            FirstLitOfBlock = True
        Else
            'Next File Info does not fit, so close buffer, next file will start in new block
            CloseBuffer()
        End If

        Exit Sub
Err:
        ErrCode = Err.Number
        MsgBox(ErrorToString(), vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")

    End Sub

    Public Sub ResetBuffer() 'CHANGE TO PUBLIC
        If DoOnErr Then On Error GoTo Err

        ReDim Buffer(255)       'New empty buffer

        'Initialize variables

        FilesInBuffer = 1

        BitPos = 7             'Reset Bit Position Counter (counts 8 bits backwards: 7-0)

        BitPtr = 0
        Buffer(BitPtr) = &H1
        BitsLeft = 7
        NibblePtr = 0
        BytePtr = 255

        'Cycles = 61             'From NextFile label
        'BitStreamBytes = 0

        'DO NOT RESET LitCnt HERE!!! It is needed for match tag check

        Exit Sub
Err:
        ErrCode = Err.Number
        MsgBox(ErrorToString(), vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")

    End Sub

    Public Function CheckIO(Offset As Integer, Optional NextFileUnderIO As Integer = -1) As Integer
        If DoOnErr Then On Error GoTo Err

        Offset += PrgAdd

        If Offset < 256 Then       'Are we loading to the Zero Page? If yes, we need to signal it by adding IO Flag
            CheckIO = 1
        ElseIf NextFileUnderIO > -1 Then
            CheckIO = If((Offset >= &HD000) And (Offset <= &HDFFF) And (NextFileUnderIO = 1), 1, 0)
        Else
            CheckIO = If((Offset >= &HD000) And (Offset <= &HDFFF) And (FileUnderIO = True), 1, 0)
        End If

        Exit Function
Err:
        ErrCode = Err.Number
        MsgBox(ErrorToString(), vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")

    End Function

    Public Sub UpdateByteStream()   'THIS IS ALSO USED BY LZ4+RLE!!!
        If DoOnErr Then On Error GoTo Err

        ReDim Preserve ByteSt(BufferCnt * 256 - 1)

        For I = 0 To 255
            ByteSt((BufferCnt - 1) * 256 + I) = Buffer(I)
        Next

        Exit Sub
Err:
        ErrCode = Err.Number
        MsgBox(ErrorToString(), vbOKOnly + vbExclamation, Reflection.MethodBase.GetCurrentMethod.Name + " Error")

    End Sub

End Module
