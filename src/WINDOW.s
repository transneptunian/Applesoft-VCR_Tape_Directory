*********************
**                  *
**      SHOW        *
** BY STEPHEN LEW   *
**  COPYRIGHT 1986  *
**BY MICROSPARC, INC*
**CONCORD, MA 01742 *
**                  *
**MERLIN CONVERSION *
**                  *
*********************
*
START    ORG $0804
*
*
* ZERO PAGE LOCATIONS
*
PNT      EQU $06
CAPS     EQU $08
YSAV     EQU $19
XSAV     EQU $1A
CHAR     EQU $1B
GBASL    EQU $1C
GBASH    EQU $1E
WNDLFT   EQU $20
WNDWDTH  EQU $21
WNDTOP   EQU $22
WNDBTM   EQU $23
CH       EQU $24
CV       EQU $25
BASL     EQU $28
BASH     EQU $29
INVFLG   EQU $32
RNDLO    EQU $4E
RNDHI    EQU $4F
STRPNT   EQU $A0
CHARGET  EQU $B1
CHARGOT  EQU $B7
GPAGE    EQU $E6
TEMP     EQU $FC
*
* INTERNAL EQUATES
*
PAR      EQU $0800
MIN      EQU $1000
MAX      EQU $2000
*
* SOFT SWITCHES
*
KEYBOARD EQU $C000
KBDSTRB  EQU $C010
GRAPHICS EQU $C050
FULLSCRN EQU $C052
HIRES    EQU $C057
*
* ROM ROUTINES
*
FRMEVL   EQU $DD7B
CHKCOM   EQU $DEBE
SYNERR   EQU $DEC9
ILLEGAL  EQU $E199
GETBYTE1 EQU $E6F8
GETBYTE  EQU $E74C
INITTEXT EQU $FB2F
VTAB     EQU $FC22
HOME     EQU $FC58
KEYIN    EQU $FD1B
COUT1    EQU $FDF0
*
********************
**                 *
**  WINDOW SYSTEM  *
**                 *
********************
*
BEGIN    LDA #$4C
         STA $03F5
         LDA #<FIRST
         STA $03F6
         LDA #>FIRST
         STA $03F7
         RTS
*
* KEYIN VECTOR
*
KEYIN2   STA (BASL),Y
         STX XSAV
KEYIN3   LDY CH
         LDA BASL
         STA GBASL
         LDA BASH
         ORA #$3C
         STA GBASL+1
         LDX #$01
         LDA (GBASL),Y
         PHA
RNDCNT   INC RNDLO
         BNE NOFLIP
         INC RNDHI
         DEX
         BNE NOFLIP
         EOR #$7F      ; FLIP CURSOR
         STA (GBASL),Y
         LDX #$50
NOFLIP   BIT KEYBOARD  ; KEY DOWN?
         BPL RNDCNT
         PLA
         STA (GBASL),Y
         LDA KEYBOARD
         CMP #$9B      ; IS IT ESCAPE?
         BNE NOTESC
         BIT KBDSTRB
         JSR ESCAPE
         JMP KEYIN3
NOTESC   LDA (BASL),Y
         LDX XSAV
         JMP KEYIN
DISPLAY  CLC
         LDA BASL
         ADC CH
         STA GBASL
         LDA BASH
         ADC #$1C
         STA GBASL+1
         LDA CHAR
         AND #$40
         BEQ NUMB+1
         LDA CAPS
         BNE LCASE+1
         LDA CHAR
         AND #$20
         BNE LCASE+1
         LDA #$0E
LCASE    BIT $0FA9
NUMB     BIT $0DA9
         STA GBASH+1
         LDA CHAR
         ASL
         ASL
         ASL
         STA GBASH
         LDX #$07
         LDY #$00
NLIN     LDA (GBASH),Y
         EOR TEMP
         STA (GBASL),Y
         INC GBASH
         CLC
         LDA GBASL+1
         CLC
         ADC #$04
         STA GBASL+1
         DEX
         BPL NLIN
         RTS
*
* COUT VECTOR
*
COUT2    STA CHAR   ; SAVE REG
         STY YSAV
         STX XSAV
         LDY INVFLG
         CPY #$FF
         BEQ FLIP
         LDY #$00
FLIP     STY TEMP
         LDA CHAR
         AND #$7F
         CMP #$20
         BCS STORE
         CMP #$01    ; CTRL-A
         BNE NOTOG
         LDA #$00
         STA CAPS
NOTOG    CMP #$1A   ; CTRL-Z
         BNE NOTOG2
         LDA #$FF
         STA CAPS
NOTOG2   CMP #$0D   ; CTRL-L
         BEQ CR
         CMP #$0A
         BEQ CR
         CMP #$0C
         BNE OUT
         JSR HOME1
OUT      LDY YSAV   ; RESTORE REG
         LDX XSAV
         LDA CHAR
         JMP COUT1
STORE    JSR DISPLAY
         LDY CH
         INY
         CPY WNDWDTH
         BCC OUT
CR       LDY CV
         INY
         CPY WNDBTM
         BCC OUT
SCROLL   LDA WNDLFT
         STA TEMP
         LDA WNDBTM
         ASL
         ASL
         ASL
         STA TEMP+3
         LDA WNDTOP
         ASL
         ASL
         ASL
         STA TEMP+2
         ADC #$08
         STA TEMP+1
SCRL1    JSR CVTOBAS  ; CALC BASADDR
         LDA GBASL
         STA GBASH
         LDA GBASL+1
         STA GBASH+1
         LDY TEMP+2
         LDA TEMP+1
         STA TEMP+2
         JSR CVTOBAS
         LDA TEMP+2
         STA TEMP+1
         STY TEMP+2
         LDY #$00
SCRL2    LDA (GBASL),Y
         STA (GBASH),Y
         INY
         CPY WNDWDTH    ; END OF LINE?
         BCC SCRL2
         INC TEMP+2
         INC TEMP+1
         LDA TEMP+1
         CMP TEMP+3     ; LAST LINE?
         BCS SCRL3
         BCC SCRL1
SCRL3    JSR CVTOBAS
         LDA #$7F
         LDY #$00
SCRL4    STA (GBASL),Y
         INY
         CPY WNDWDTH
         BCC SCRL4
         INC TEMP+2
         LDA TEMP+2
         CMP TEMP+3
         BCC SCRL3
         JMP OUT
*
* CLOUSE OUTPUT WINDOW
*
CLOSE    LDA PNT+1
         CMP #>MAX-1
         BNE CLOSE1
         LDA PNT
         CMP #$FF
         BNE CLOSE1
         RTS
CLOSE1   LDX #$00
LOOPA1   JSR PULL    ; PULL PARAMS
         STA PAR,X   ; OFF STACK
         INX
         CPX #$04
         BNE LOOPA1
         LDX #$00
LOOPA2   JSR PULL
         STA WNDLFT,X
         INX
         CPX #$0A
         BNE LOOPA2
         JSR CONVERT
         LDA TEMP+2
         LDY TEMP+3
         LDX TEMP+1
         DEX
         STX TEMP+1
         DEY
         STA TEMP+3
         STY TEMP+2
AGAINA   JSR CVTOBAS
         LDY TEMP+1
         DEX
LOOPB    JSR PULL
         STA (GBASL),Y
         DEY
         CPY #$FF
         BNE LOOPB
         DEC TEMP+2
         LDA TEMP+2
         CMP TEMP+3
         BCS AGAINA
         RTS
*
* OPEN OUTPUT WINDOW
*
OPEN     LDA PNT
         STA ERRLOC+1
         LDA PNT+1
         STA ERRLOC+5
OPEN1    JSR CONVERT
AGAINB   JSR CVTOBAS
         LDY #$00
LOOPC    LDA (GBASL),Y
         JSR PUSH
         INY
         CPY TEMP+1
         BCC LOOPC
         INC TEMP+2
         LDA TEMP+2
         CMP TEMP+3
         BCC AGAINB
         LDX #$09
LOOPD2   LDA WNDLFT,X
         JSR PUSH
         DEX
         BPL LOOPD2
         LDX #$03
LOOPD1   LDA PAR,X
         JSR PUSH
         DEX
         BPL LOOPD1
*
* CLEAR OUTPUT WINDOW
*
CLEAR    LDX #$03
LOOPE    LDA PAR,X
         STA WNDLFT,X
         DEX
         BPL LOOPE
         JSR CONVERT
         DEC TEMP+1
         DEC TEMP+3
         DEC TEMP+3
         JSR CVTOBAS
         LDY #$00
         LDA (GBASL),Y
         AND #$1F
         STA (GBASL),Y
         TYA
         INY
LOOPF    STA (GBASL),Y
         INY
         CPY TEMP+1
         BCC LOOPF
         LDA (GBASL),Y
         AND #$7E
         STA (GBASL),Y
         INC TEMP+2
AGAINC   JSR CVTOBAS
         LDY #$00
         LDA (GBASL),Y
         AND #$1F
         ORA #$40
         STA (GBASL),Y
         INY
         LDA #$7F
LOOPG    STA (GBASL),Y
         INY
         CPY TEMP+1
         BCC LOOPG
         LDA (GBASL),Y
         AND #$7C
         STA (GBASL),Y
         INC TEMP+2
         LDA TEMP+2
         CMP TEMP+3
         BCC AGAINC
         LDX #$01
         STX TEMP+3
AGAIND   JSR CVTOBAS
         LDY #$00
         LDA TEMP+3
         BEQ SKIP
         LDA (GBASL),Y
         AND #$1F
         STA (GBASL),Y
SKIP     TYA
         INY
LOOPH    STA (GBASL),Y
         INY
         CPY TEMP+1
         BCC LOOPH
         LDA (GBASL),Y
         AND #$7C
         STA (GBASL),Y
         INC TEMP+2
         DEC TEMP+3
         BPL AGAIND
*
* CLEAR WINDOW
*
HOME1    LDA WNDLFT
         STA TEMP
         LDA WNDTOP
         ASL
         ASL
         ASL
         STA TEMP+2
         LDA WNDBTM
         ASL
         ASL
         ASL
         STA TEMP+3
NLN1     JSR CVTOBAS
         LDA #$7F
         LDY WNDWDTH
         DEY
NLN2     STA (GBASL),Y
         DEY
         BPL NLN2
         INC TEMP+2
         LDA TEMP+2
         CMP TEMP+3
         BCC NLN1
         JMP HOME
CONVERT  LDX PAR
         DEX
         STX TEMP
         LDX PAR+1
         INX
         INX
         STX TEMP+1
         LDA PAR+2
         ASL
         ASL
         ASL
         TAX
         DEX
         DEX
         STX TEMP+2
         LDA PAR+3
         ASL
         ASL
         ASL
         TAX
         INX
         INX
         STX TEMP+3
         RTS
CVTOBAS  LDA TEMP+2
         ASL
         ASL
         AND #$1C
         STA GBASL+1
         LDA TEMP+2
         LSR
         LSR
         LSR
         LSR
         AND #$03
         ORA GBASL+1
         ORA GPAGE
         STA GBASL+1
         LDA #$00
         BCC SKIP2
         ADC #$7F
SKIP2    STA RNDLO
         LDA TEMP+2
         LSR
         AND #$60
         STA GBASL
         LSR
         LSR
         ORA RNDLO
         ORA GBASL
         ADC TEMP
         STA GBASL
         RTS
PUSH     STY YSAV    ; PUSH VALUE TO
         LDY #$00    ; STACK
         STA (PNT),Y
         DEC PNT
         LDA PNT
         CMP #$FF
         BNE SKIP3
         DEC PNT+1
         LDA PNT+1
         CMP #>MIN
         BEQ ERROR
SKIP3    LDY YSAV
         RTS
PULL     STY YSAV
         INC PNT
         BNE SKIP4
         INC PNT+1
SKIP4    LDY #$00
         LDA (PNT),Y
         LDY YSAV
         RTS
ERROR    PLA
         PLA
ERRLOC   LDA #$00
         STA PNT
         LDA #$00
         STA PNT+1
         RTS
*
* FILL SCREEN WITH BACKGROUND
*
CLS      LDA #$20
         STA PNT+1
         LDA #$00
         STA PNT
         TAX
         TAY
NEXT     LDA TAB,X
         STA (PNT),Y
         INY
         LDA TAB+1,X
         STA (PNT),Y
         INY
         BNE NEXT
         INC PNT+1
         LDA PNT+1
         CMP #$40
         BEQ SCRNCLR
         AND #$04
         CLC
         ROR
         TAX
         JMP NEXT
SCRNCLR  RTS
TAB      HEX 2A55552A
*
* INITIALIZE WINDOW SYSTEM
*
INIT     JSR INITTEXT
         JSR HOME
         JSR SWCHS
         LDA #$20
         STA GPAGE
         LDA #$00
         STA CAPS
         JSR CLS
         BIT HIRES
         BIT FULLSCRN
         BIT GRAPHICS
         RTS
SWCHS    LDA #$4C   ; SET AMPERSAND
         STA $03F5  ; VECTOR
         LDA #<AMP
         STA $03F6
         LDA #>AMP
         STA $03F7
         LDA $03D2  ; LOAD TEST BYTE
         CMP #$BE   ; PRODOS?
         BNE DOS    ; NO SET UP DOS
         LDA #<COUT2
         STA $BE30
         LDA #>COUT2
         STA $BE31
         LDA #<KEYIN2
         STA $BE32
         LDA #>KEYIN2
         STA $BE33
         RTS
DOS      LDA #<COUT2   ; DOS SET UP
         STA $36
         LDA #>COUT2
         STA $37
         LDA #<KEYIN2
         STA $38
         LDA #>KEYIN2
         STA $39
         JMP $03EA
AMP      CMP #$97      ; HOME?
         BNE NOTHOME
         JSR CHARGET
         JSR HOME1
         JMP CHARGOT
NOTHOME  CMP #$AE      ; RESTORE?
         BNE NORESTOR
         JSR CHARGET
         JSR CLOSE
         JMP CHARGOT
NORESTOR CMP #$94      ; DRAW?
         BEQ DRAW
         CMP #$A8
         BEQ SAVWIND
FIRST    CMP #$BF      ; NEW?
         BEQ NEW
         JMP SYNERR
DRAW     JSR CHARGET
DRAW1    JSR GETPAR
         JSR CLEAR
         JMP CHARGOT
SAVWIND  JSR CHARGET
         JSR GETPAR
         JSR OPEN
         JMP CHARGOT
NEW      JSR CHARGET
         JSR INIT
         JSR FRMEVL
         LDY #$02
         LDA (STRPNT),Y
         STA PNT+1
         DEY
         LDA (STRPNT),Y
         STA PNT
         DEY
         LDA (STRPNT),Y
         STA RNDLO
         BEQ NULL
NEXTCHAR LDA (PNT),Y
         JSR COUT2
         INY
         CPY #$28
         BEQ COMMA
         CPY RNDLO
         BNE NEXTCHAR
NULL     LDA #$20
NEXTSPC  JSR COUT2
         INY
         CPY #$28
         BNE NEXTSPC
COMMA    JSR CHKCOM
         LDA #$FF
         STA PNT
         LDA #>MAX-1
         STA PNT+1
         JMP DRAW1
GETPAR   JSR GETBYTE1
         STX PAR
         CPX #$25
         BCS ILQUANT
         JSR GETBYTE
         STX PAR+1
         TXA
         CLC
         ADC PAR
         CMP #$28
         BCS ILQUANT
         JSR GETBYTE
         STX PAR+2
         CPX #$01
         BCC ILQUANT
         JSR GETBYTE
         STX PAR+3
         CPX #$18
         BCS ILQUANT
         RTS
ILQUANT  JMP ILLEGAL
KEYIN4   LDA BASL
         STA GBASL
         LDA BASH
         ORA #$3C
         STA GBASL+1
         LDY CH
         LDA (GBASL),Y
         EOR #$7F
         STA (GBASL),Y
NOKEY    BIT KEYBOARD
         BPL NOKEY
         EOR #$7F
         STA (GBASL),Y
         LDA KEYBOARD
         BIT KBDSTRB
         RTS
ADVANCE  INC CH
         LDA CH
         CMP WNDWDTH
         BCC SAMELIN
         JMP CR
BS       DEC CH
         BPL SAMELIN
         LDA WNDWDTH
         STA CH
         DEC CH
UP       LDA WNDTOP
         CMP CV
         BCS SAMELIN
         DEC CV
         JMP VTAB
SAMELIN  RTS
TABLE    HEX CBCACDC995888A8B
ESCON    TYA
         AND #$03
         CLC
         ADC #$C1
         JSR ESCDO
ESCAPE   JSR KEYIN4
         STA CHAR
         LDY #$07
NEXTCODE CMP TABLE,Y
         BEQ ESCON
         DEY
         BPL NEXTCODE
ESCDO    SEC
         EOR #$C0
         BNE NOTAT
         JMP HOME1
NOTAT    ADC #$FD
         BCC ADVANCE
         BEQ BS
         ADC #$FD
         BEQ UP
         BCS NOCODE
         LDA #$8A
         JMP COUT2
NOCODE   RTS
         END