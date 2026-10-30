; =====================================================================
;  ASCII-Texteditor fuer den C64 
;  Copyright (c) 2026 supertoq
;  Version 2
;  
;  Ein Texteditor der in der Lage ist ASCII Code zu laden, zu editieren und zu speichern.
;  Unterstuetzt wird der 7-Bit-ASCII-Zeichensatz (ANSI X3.4-1986),
;  ausgenommen der Zeichen NUL und CR, diese werden beim Laden einer Datei bewusst ignoriert.
;  ANSI Sonderzeichen werden fuer die Darstellung auf dem C64 in passende Bildschirmcodes umgewandelt.
;  
;  - Dateien werden als C64 SEQ-Dateien mit reinem ASCII gespeichert 
;    (in Windows muss die Dateiendung in .txt umbenannt werden)
;  - Zeilenende LF oder CRLF optional umstellbar
;  - Textspeicher $4000-$CEFF (ca. 36 KByte), BASIC-ROM wird abgeschaltet
;  - Programmspeicherverbrauch 7,3 KByte
;  - Zeichensatz Gross/Klein wird in den RAM $3000 kopiert
;  - Jede Eingabe wird nach ASCII umgewandelt
;  - nicht verfuegbare Tasteneingaben koennen per F8 haendisch eingetragen werden
;  - Deutsche UTF-8 Umlaute werden als invertierter Buchstabe angezeigt, keine Umwandlung im Text
;  - Beim Speichern der Datei wird zuvor eine Platzpruefung durchgefuehrt
;
;  Tastenverwendung:
;    F1 = Speichern  F3 = Laden  F5 = Neu  F7 = Beenden  F8 = ASCII Code Eingabe
;
;    Cursor keys =  Navigation       HOME    =  Zeilenanfang
;    DEL         =  Backspace        CLR     =  Textanfang
;    SHIFT+DEL   =  Entf (INST)      F2      =  Textende
;    RETURN      =  neue Zeile       F4 / F6 =  Seite hoch / runter
;    CTRL+I      =  Tabulator
;
;  Zeichen-Direkteingabe auf der C64-Tastatur: 
;        Pfund-Taste                 =  Backslash \
;        SHIFT+Pfund                 =  Unterstrich _
;        Linkspfeil-Taste            =  Backtick `
;        SHIFT+Plus                  =  Curly Brace {
;        SHIFT+Minus                 =  Curly Brace }
;        | (Taste vor RESTORE)       =  ASCII Pipe | 
;        SHIFT+| (Taste vor RESTORE) =  Caret ^   
;        SHIFT+:                     =  Square Bracket [  
;        SHIFT+;                     =  Square Bracket ]
;
;        F8  =  Zeicheneingabe per ASCII Code (Dezimal)
;               33 - 126 = ASCII Zeichencodes
;               Beachte, Codes 0 - 32 = Steuerzeichen, 127 = DEL 
;               (Die Eingaben von 0 und 13 werden ignoriert)
;               
;               Beispiele fuer Dezimalwerte:
;               126 = ~  125 = }  123 = {  96 = `  9 = Tab 
;
;               Umlaute als Unicode-Eingabe:
;               228 = ae  246 = oe  252 = ue  
;               196 = AE  214 = OE  220 = UE  223 = Sz 
;                             
;  Alternative Zeichendarstellung:
;        Curly Brace { } = dargestellt als invertierte Klammern ()
;        Tilde ~ = dargestellt als invertiertes Minus -
;        UTF-8 DE Umlaute = dargestellt als invertiertes Zeichen    
;        UTF-8 Chevrons « » = dargestellt als invertierte < > 
;
;  Editor starten - von Diskette per LOAD"TEXTEDITOR",8 und RUN
;
;  Beim Laden (F3) und Speichern (F1) kann mit den Cursortasten hoch/runter
;  das Laufwerksgeraet zwischen 8 - 11 gewaehlt werden.
;  Mit der Eingabe von $ als Dateiname wird der Disketteninhalt aufgelistet.
;
; =====================================================================

        .cpu "6502"

; Textcodierung: Zeichen werden 1:1 als ASCII abgelegt
        .enc "ascii"
        .cdef $00, $ff, $00

; Option:
CRLF    = 0                     ; Zeilenende: 0 = LF, 1 = CR+LF

; Option: Ersatzzeichen am Bildschirm
; Zeichen, die der C64 nicht darstellen kann, werden mit diesen
; Bildschirmcodes angezeigt. Werte frei waehlbar (Satz Gross/Klein):
;   0 = @   1-26 = a-z   27 = [   28 = \   29 = ]   30 = Pfeil hoch
;   32-63 = Leerzeichen, Ziffern, Satzzeichen   65-90 = A-Z
;   +128 = invertiert (z.B. 129 = invertiertes a)
ALT_LBRACE      = 168           ; {  invertiertes (
ALT_RBRACE      = 169           ; }  invertiertes )
ALT_TILDE       = 173           ; ~  invertiertes -
ALT_BACKTICK    = 167           ; `  invertiertes '
ALT_PIPE        = 93            ; |  senkrechter Strich
ALT_UNDERSCORE  = 100           ; _  Strich unten
ALT_BACKSLASH   = 28            ; \  eigenes Zeichen
ALT_CARET       = 30            ; ^  Pfeil hoch
ALT_OTHER       = 174           ; alle anderen: invertierter Punkt
; UTF-8 Zeichen (Umlaute und Guillemets)
ALT_AE_KL       = 129           ; a-Umlaut    invertiertes a
ALT_OE_KL       = 143           ; o-Umlaut    invertiertes o
ALT_UE_KL       = 149           ; u-Umlaut    invertiertes u
ALT_AE_GR       = 193           ; A-Umlaut    invertiertes A
ALT_OE_GR       = 207           ; O-Umlaut    invertiertes O
ALT_UE_GR       = 213           ; U-Umlaut    invertiertes U
ALT_SZ          = 194           ; scharfes s  invertiertes B
ALT_LAQUO       = 188           ; Guillemet links (171)   invertiertes <
ALT_RAQUO       = 190           ; Guillemet rechts (187)  invertiertes >

; ---- Speicheraufteilung
BUF     = $4000                 ; Textspeicher: Anfang
BUFEND  = $cf00                 ; Textspeicher: Ende
SCREEN  = $0400                 ; Anfangsadresse des Bildschirmspeichers
TROWS   = 23                    ; Textzeilen auf dem Bildschirm
STAT    = SCREEN+23*40          ; Position Statuszeile (Hilfe/Meldungen)
INFO    = SCREEN+24*40          ; Position Infozeile (freier Speicher)
WARN    = 1000                  ; Wert darunter in rot
WARNCOL = 10                    ; Warnfarbe (hellrot)
LF      = $0a                   ; Zahl Zehn ($0a) fuer LF
TAB     = $09                   ; Tabulator-Zeichen (Code 9)
TABW    = 4                     ; Breite des Tabulators am Bildschirm
TEXTCOL = 15                    ; Textfarbe (hellgrau)
BGCOL   = 6                     ; Hintergrund (dunkelblau)
CHARRAM = $3000                 ; Zeichensatz im RAM (2 KB)
BORDCOL = 6                     ; Rahmenfarbe (0 schwarz, 6 blau, 11 grau)

; ---- Betriebssystem-Routinen (KERNAL)
SETLFS  = $ffba
SETNAM  = $ffbd
OPEN    = $ffc0
CLOSE   = $ffc3
CHKIN   = $ffc6
CHKOUT  = $ffc9
CLRCHN  = $ffcc
CHRIN   = $ffcf
CHROUT  = $ffd2
GETIN   = $ffe4
READST  = $ffb7
CLALL   = $ffe7

; ---------------------------------------------------------------------
;  Erklaerung der Namen im Programm
;
;  Register (Rechenspeicher des Prozessors):
;    A      Hauptregister, hier stehen meist Zeichen und Werte
;    X, Y   Hilfsregister, meist Zaehler oder Positionen
;    Carry  Merker im Prozessor, wird hier fuer Ja/Nein benutzt
;
;  Variablen:
;    cur    Cursorposition (Adresse im Textspeicher)
;    gs     Anfang des Gap (Ende des Textes vor dem Cursor)
;    top    erste Textstelle, die oben am Bildschirm steht
;    p, q, r  Zeiger auf Textstellen (Hilfsvariablen)
;    sc     Zeiger auf eine Stelle im Bildschirmspeicher
;    sz     Anzahl Bytes, die beim Verschieben von Text betroffen sind
;    crow   Zeile des Cursors am Bildschirm
;    ccol   Spalte des Cursors am Bildschirm
;    tmp, tmp2, tcnt, mcol, u8sx, u8lead, u8sec  Hilfsvariablen
;    LF     Zeilenvorschub, das Zeilenende-Zeichen (Code 10)
;
;  Aufbau des Textspeichers (Gap-Buffer, Gap = freier Platz):
;    BUF .. gs     Text vor dem Cursor
;    gs  .. cur    Gap, hier wird eingefuegt (bei gs steht eine 0)
;    cur .. BUFEND Text ab dem Cursor, bei BUFEND steht eine 0
;    Tippen und Loeschen aendern nur gs oder cur, es wird nichts verschoben.
;    Bewegt sich der Cursor, wandert der Gap mit (moveto).
; ---------------------------------------------------------------------

; ---- Zeropage
cur     = $22                   ; Cursorposition im Text
gs      = $24                   ; Anfang des Gap
top     = $26                   ; Textstelle oben links auf dem Bildschirm
r       = $28                   ; Zeiger auf Textstelle
sc      = $f7                   ; Bildschirmzeiger
sz      = $f9                   ; Anzahl Bytes beim Verschieben
p       = $fb                   ; Zeiger auf Textstelle
q       = $fd                   ; Zeiger auf Textstelle

; ---- Makros
inc16   .macro
        inc \1
        bne _skip
        inc \1+1
_skip
        .endm

; Zeiger auf das naechste Zeichen setzen, springt ueber den Gap
; A bleibt erhalten, X ist danach 0
nxt     .macro
        inc \1
        bne _a
        inc \1+1
_a      ldx \1
        cpx gs
        bne _b
        ldx \1+1
        cpx gs+1
        bne _b
        ldx cur
        stx \1
        ldx cur+1
        stx \1+1
_b      ldx #0
        .endm

; Zeiger auf das vorherige Zeichen setzen, springt ueber den Gap
prv     .macro
        lda \1
        cmp cur
        bne _a
        lda \1+1
        cmp cur+1
        bne _a
        lda gs
        sta \1
        lda gs+1
        sta \1+1
_a      lda \1
        bne _b
        dec \1+1
_b      dec \1
        .endm

; Naechstes Byte lesen (nach A), auch wenn p direkt vor dem Gap steht
; X muss 0 sein
pk      .macro
        lda (\1,x)
        bne _d
        lda \1
        cmp gs
        bne _z
        lda \1+1
        cmp gs+1
        bne _z
        lda (cur,x)             ; Byte hinter dem Gap
        jmp _d
_z      lda #0
_d
        .endm

; Zeiger um ein Byte weiter (zweites Byte eines Umlauts ueberspringen)
; Steht der Zeiger auf dem Gap, geht es dahinter weiter
skip2   .macro
        lda \1
        cmp gs
        bne _i
        lda \1+1
        cmp gs+1
        bne _i
        lda cur
        sta \1
        lda cur+1
        sta \1+1
_i      inc \1
        bne _e
        inc \1+1
_e
        .endm

; Wurde eine 0 gelesen: ist es der Gap, hinter dem Cursor weiterlesen
; (Sprung nach Ziel), sonst ist es das Textende (weiter im Programm)
gapjmp  .macro
        lda \1
        cmp gs
        bne _e
        lda \1+1
        cmp gs+1
        bne _e
        lda \1
        cmp cur
        bne _j
        lda \1+1
        cmp cur+1
        beq _e
_j      lda cur
        sta \1
        lda cur+1
        sta \1+1
        jmp \2
_e
        .endm

; Steht der Zeiger auf dem Anfang des Gap, hinter den Gap setzen
norm    .macro
        lda \1
        cmp gs
        bne _e
        lda \1+1
        cmp gs+1
        bne _e
        lda cur
        sta \1
        lda cur+1
        sta \1+1
_e
        .endm

msg     .macro
        lda #<\1
        sta p
        lda #>\1
        sta p+1
        jsr stprint
        .endm

; =====================================================================
        * = $0801
        .word (+), 2026
        .null $9e, format("%d", start)
+       .word 0

start   lda #$36                ; BASIC-ROM aus, KERNAL und Ein-/Ausgabe an
        sta $01
        lda $ba                 ; Laufwerk, von dem geladen wurde
        cmp #8
        bcs +
        lda #8
+       sta device
        lda #BORDCOL
        sta $d020
        lda #BGCOL
        sta $d021
        lda #1
        sta $cc                 ; blinkenden Systemcursor aus
        lda #$80
        sta $028a               ; Tasten wiederholen bei Dauerdruck
        sta $0291               ; Umschalten des Zeichensatzes sperren
        sei                     ; Interrupts aus, Zeichensatz ins RAM kopieren
        lda #$32                ; Zeichensatz-ROM einblenden
        sta $01
        lda #<$d800
        sta p
        lda #>$d800
        sta p+1
        lda #<CHARRAM
        sta q
        lda #>CHARRAM
        sta q+1
        ldx #8                  ; 8 x 256 Bytes = 2 KB
        ldy #0
-       lda (p),y
        sta (q),y
        iny
        bne -
        inc p+1
        inc q+1
        dex
        bne -
        ldy #7                  ; Zeichen \ aus dem Grossschrift-Satz
-       lda $d000+$4d*8,y       ; ($4D) ersetzt das Pfundzeichen
        sta CHARRAM+$1c*8,y     ; (Bildschirmcode $1C)
        dey
        bpl -
        lda #$36
        sta $01
        cli
        lda #$1c                ; Zeichensatz bei $3000, Bildschirm bei $0400
        sta $d018
        ldx #0
        lda #TEXTCOL
-       sta $d800,x
        sta $d900,x
        sta $da00,x
        sta $db00,x
        inx
        bne -
        ldx #39                 ; Infozeile leeren
        lda #$20
-       sta INFO,x
        dex
        bpl -
        ldy #0                  ; F4/F6-Hinweis unter F1/F3
-       lda m_pg,y
        beq +
        jsr a2s
        sta INFO,y
        iny
        bne -
+
        lda #0
        sta statshow
        sta flen
        jsr newtext

; ---------------------------------------------------------------------
;  Hauptschleife
; ---------------------------------------------------------------------
main    jsr findcursor
        jsr draw
        jsr showfree
        lda statshow
        bne +
        jsr drawhelp
+       lda #0
        sta statshow
mk      jsr getkey
        jsr dispatch
        jsr fixtop
        lda $c6                 ; weitere Taste im Tastaturpuffer?
        bne mk                  ; dann erst verarbeiten, danach zeichnen
        jmp main

getkey  jsr GETIN
        cmp #0
        beq getkey
        rts

; ---------------------------------------------------------------------
;  Tastenverteilung
; ---------------------------------------------------------------------
dispatch
        ldx #nkeys-1
-       cmp keys,x
        beq +
        dex
        bpl -
        jsr p2a                 ; normale Zeichentaste
        cmp #0
        beq dsp_rt
        jmp insert
dsp_rt  rts
+       txa
        asl
        tay
        lda hand+1,y
        pha
        lda hand,y
        pha
        rts

keys    .byte $0d,$8d,$11,$91,$1d,$9d,$14,$94,$13,$93
        .byte $89,$8a,$8b,$85,$86,$87,$88,$8c
nkeys   = * - keys
hand    .word k_ret-1,k_ret-1,k_down-1,k_up-1,k_right-1,k_left-1
        .word k_bs-1,k_del-1,k_home-1,k_clr-1
        .word k_end-1,k_pgup-1,k_pgdn-1
        .word k_save-1,k_load-1,k_new-1,k_quit-1,k_code-1

; Tastencode in ASCII-Zeichen umwandeln
; Der Tastencode kommt im Register A an,
; das Ergebnis steht danach wieder in A.
; Ergebnis 0: Taste ohne Zeichen, wird ignoriert
p2a     cmp #TAB
        beq p2a_ok              ; CTRL+I = Tabulator
        cmp #$20
        bcc p2a_no
        cmp #$41
        bcc p2a_ok              ; $20-$40 unveraendert
        cmp #$5b
        bcc p2a_lo              ; $41-$5A = Kleinbuchstaben
        cmp #$5e
        beq p2a_pi              ; Pfeil hoch -> |
        cmp #$5f
        beq p2a_bt              ; Pfeil links -> `
        cmp #$60
        bcc p2a_ok              ; $5B-$5D  [ \ ]
        cmp #$a9
        beq p2a_us              ; SHIFT+Pfund-Taste -> _
        cmp #$db
        beq p2a_lb              ; SHIFT+Plus-Taste -> {
        cmp #$dd
        beq p2a_rb              ; SHIFT+Minus-Taste -> }
        cmp #$de
        beq p2a_ca              ; SHIFT+Pfeil hoch -> ^
        cmp #$c1
        bcc p2a_no
        cmp #$db
        bcs p2a_no
        and #$7f                ; $C1-$DA = Grossbuchstaben
        rts
p2a_lo  clc
        adc #$20
p2a_ok  rts
p2a_no  lda #0
        rts
p2a_pi  lda #$7c                ; |
        rts
p2a_us  lda #$5f                ; _
        rts
p2a_ca  lda #$5e                ; ^
        rts
p2a_bt  lda #$60                ; `
        rts
p2a_lb  lda #$7b                ; {
        rts
p2a_rb  lda #$7d                ; }
        rts

; ASCII-Zeichen in Bildschirmcode umwandeln
; Das Zeichen kommt im Register A an,
; der Bildschirmcode steht danach in A. X ist danach 0.
a2s     cmp #$80
        bcs a2s_np              ; ab 128: nicht darstellbar
        tax
        lda a2stab,x
        ldx #0
        rts
a2s_np  lda #ALT_OTHER
        ldx #0
        rts

; Tabelle ASCII 0-127 -> Bildschirmcode (Ersatzzeichen aus den Optionen)
a2stab  .for i = 0, i < 128, i += 1
        .byte i < $20 ? ALT_OTHER : i < $40 ? i : i == $40 ? 0 : i < $5b ? i : i == $5c ? ALT_BACKSLASH : i == $5e ? ALT_CARET : i == $5f ? ALT_UNDERSCORE : i < $60 ? i & $1f : i == $60 ? ALT_BACKTICK : i < $7b ? i & $1f : i == $7b ? ALT_LBRACE : i == $7c ? ALT_PIPE : i == $7d ? ALT_RBRACE : i == $7e ? ALT_TILDE : ALT_OTHER
        .next

; Ist das Byte in A ein Anfangsbyte eines UTF-8 Zeichens (194 oder 195)?
; Zero-Flag gesetzt: ja, das Byte wird in u8lead gemerkt
; A, X und Y bleiben unveraendert
islead  cmp #$c3
        beq il_y
        cmp #$c2
        bne il_n
il_y    sta u8lead
il_n    rts

; Zweites Byte eines UTF-8 Zeichens pruefen (Anfangsbyte steht in u8lead)
; Das Byte kommt im Register A an.
; Carry geloescht: gueltig, A = Bildschirmcode des Zeichens
; Carry gesetzt: unbekanntes Zeichen
; Die Register X und Y bleiben unveraendert
u8map   stx u8sx
        sta u8sec
        ldx #8
um1     lda u8tab,x
        cmp u8sec
        bne um3
        lda u8lt,x
        cmp u8lead
        beq um2
um3     dex
        bpl um1
        lda u8sec
        ldx u8sx
        sec
        rts
um2     lda u8gly,x
        ldx u8sx
        clc
        rts

;                 a-Uml. o-Uml. u-Uml. A-Uml. O-Uml. U-Uml. sz     <<     >>
; Anfangsbytes:
u8lt    .byte     $c3,   $c3,   $c3,   $c3,   $c3,   $c3,   $c3,   $c2,   $c2
; zweite Bytes:
u8tab   .byte     $a4,   $b6,   $bc,   $84,   $96,   $9c,   $9f,   $ab,   $bb
; Bildschirmcodes dazu (siehe Optionen oben)
u8gly   .byte ALT_AE_KL, ALT_OE_KL, ALT_UE_KL, ALT_AE_GR, ALT_OE_GR, ALT_UE_GR, ALT_SZ, ALT_LAQUO, ALT_RAQUO

; ---------------------------------------------------------------------
;  Text aendern
; ---------------------------------------------------------------------
newtext lda #<BUF               ; leerer Text: Gap ueber den ganzen Speicher
        sta gs
        lda #>BUF
        sta gs+1
        lda #<BUFEND
        sta cur
        sta top
        lda #>BUFEND
        sta cur+1
        sta top+1
        lda #0                  ; Endemarke 0 hinter dem Text
        sta BUFEND
        jmp setgap

; Markierung 0 an den Anfang des Gap setzen (wenn es einen gibt)
setgap  lda gs
        cmp cur
        bne +
        lda gs+1
        cmp cur+1
        beq sg_rt
+       lda #0
        ldy #0
        sta (gs),y
sg_rt   rts

; Textanfang nach p holen
; (steht vor dem Cursor nichts, beginnt der Text am Cursor)
tstart  lda #<BUF
        sta p
        lda #>BUF
        sta p+1
        lda gs
        cmp #<BUF
        bne +
        lda gs+1
        cmp #>BUF
        bne +
        lda cur
        sta p
        lda cur+1
        sta p+1
+       rts

; Steht p am Textanfang?  Zero-Flag gesetzt: ja
isbeg   lda gs
        cmp #<BUF
        bne ib_buf
        lda gs+1
        cmp #>BUF
        bne ib_buf
        lda p                   ; Text beginnt am Cursor
        cmp cur
        bne +
        lda p+1
        cmp cur+1
+       rts
ib_buf  lda p
        cmp #<BUF
        bne +
        lda p+1
        cmp #>BUF
+       rts

; Zeichen in den Text einfuegen (in den Gap vor dem Cursor)
; Das Zeichen kommt im Register A an
insert  sta chr                 ; Zeichen zwischenspeichern
        lda gs                  ; Gap leer: Speicher voll
        cmp cur
        bne ins_ok
        lda gs+1
        cmp cur+1
        bne ins_ok
        jsr stclear
        #msg m_full
        lda #1
        sta statshow
        rts
ins_ok  lda top                 ; top auf dem Cursor: zeigt danach
        cmp cur                 ; auf das neue Zeichen
        bne ins_st
        lda top+1
        cmp cur+1
        bne ins_st
        lda gs
        sta top
        lda gs+1
        sta top+1
ins_st  lda chr
        ldy #0
        sta (gs),y
        #inc16 gs
        jmp setgap


; Speicherblock nach oben verschieben
; Quelle: Adresse in p, Ziel: Adresse in q
; Laenge: sz Bytes
; Kopiert von hinten, damit nichts verloren geht
moveup  ldx sz+1
        clc
        txa
        adc p+1
        sta p+1
        clc
        txa
        adc q+1
        sta q+1
        inx
        ldy sz
        beq mu3
        dey
        beq mu2
mu1     lda (p),y
        sta (q),y
        dey
        bne mu1
mu2     lda (p),y
        sta (q),y
mu3     dey
        dec p+1
        dec q+1
        dex
        bne mu1
        rts

; Speicherblock nach unten verschieben
; Quelle: Adresse in p, Ziel: Adresse in q
; Laenge: sz Bytes
; Kopiert von vorne, damit nichts verloren geht
movedown
        ldy #0
        ldx sz+1
        beq md2
md1     lda (p),y
        sta (q),y
        iny
        bne md1
        inc p+1
        inc q+1
        dex
        bne md1
md2     ldx sz
        beq md4
md3     lda (p),y
        sta (q),y
        iny
        dex
        bne md3
md4     rts

; ---------------------------------------------------------------------
;  Cursorbewegung
; ---------------------------------------------------------------------
k_ret   lda #LF
        jmp insert

k_bs    lda cur                 ; Backspace
        sta p
        lda cur+1
        sta p+1
        jsr isbeg
        beq kb_rt               ; am Textanfang nichts zu tun
        jsr k_left              ; ein Zeichen zurueck (auch ganzer Umlaut)
        jmp k_del               ; und dieses Zeichen loeschen
kb_rt   rts

; Zeichen unter dem Cursor loeschen (der Gap wird groesser)
; ein UTF-8 Umlaut wird komplett geloescht (beide Bytes)
k_del   ldy #0
        lda (cur),y
        beq kx_rt               ; am Textende nichts zu tun
        ldx #1                  ; X = Laenge des Zeichens in Bytes
        jsr islead
        bne kx_go
        iny
        lda (cur),y
        jsr u8map
        bcs kx_go
        ldx #2
kx_go   lda top                 ; top auf oder hinter dem Cursor:
        cmp cur                 ; wandert mit (wie beim Verschieben)
        lda top+1
        sbc cur+1
        bcc kx_del
        txa
        clc
        adc top
        sta top
        bcc kx_del
        inc top+1
kx_del  txa                     ; Zeichen dem Gap zuschlagen
        clc
        adc cur
        sta cur
        bcc kx_rt
        inc cur+1
kx_rt   rts

; Cursor ein Zeichen nach links (UTF-8 Umlaut = ein Zeichen)
k_left  lda cur
        sta p
        lda cur+1
        sta p+1
        jsr isbeg
        beq kl_rt               ; schon am Textanfang
        #prv p
        jsr isbeg               ; steht davor noch ein Byte?
        beq kl_go
        lda p                   ; q = vorheriges Byte
        sta q
        lda p+1
        sta q+1
        #prv p                  ; p = Byte davor
        ldy #0
        lda (p),y
        jsr islead              ; Anfangsbyte?
        bne kl_one
        ldy #0
        lda (q),y
        jsr u8map               ; und gueltiges zweites Byte?
        bcc kl_go               ; ja: Cursor vor das ganze Zeichen
kl_one  lda q                   ; sonst nur ein Byte zurueck
        sta p
        lda q+1
        sta p+1
kl_go   jmp moveto
kl_rt   rts

; Cursor ein Zeichen nach rechts (UTF-8 Umlaut = ein Zeichen)
k_right ldy #0
        lda (cur),y
        beq kr_rt               ; schon am Textende
        ldx #1                  ; X = Laenge des Zeichens in Bytes
        jsr islead
        bne kr_go
        iny
        lda (cur),y
        jsr u8map
        bcs kr_go
        ldx #2
kr_go   txa                     ; Ziel = Cursor + Laenge
        clc
        adc cur
        sta p
        lda cur+1
        adc #0
        sta p+1
        jmp moveto
kr_rt   rts

k_home  jsr rowstart
        jmp moveto

k_clr   jsr tstart
        jmp moveto

k_end   lda #<BUFEND
        sta p
        lda #>BUFEND
        sta p+1
        jmp moveto

; Gap und Cursor an die Textstelle p schieben
; Die Zeichen dazwischen wandern auf die andere Seite des Gap.
; top wird mitgefuehrt, wenn es in diesem Bereich liegt.
moveto  lda p                   ; mt = Ziel
        sta mt
        lda p+1
        sta mt+1
        lda mt
        cmp cur
        bne mt_go
        lda mt+1
        cmp cur+1
        bne mt_go
        rts                     ; Ziel = Cursor: nichts zu tun
mt_go   sec                     ; gsz = Groesse des Gap
        lda cur
        sbc gs
        sta gsz
        lda cur+1
        sbc gs+1
        sta gsz+1
        lda mt                  ; Ziel hinter dem Cursor?
        cmp gs
        lda mt+1
        sbc gs+1
        bcs mt_up
; Ziel vor dem Gap: Text mt..gs nach hinten vor den Cursor
        sec                     ; sz = gs - mt
        lda gs
        sbc mt
        sta sz
        lda gs+1
        sbc mt+1
        sta sz+1
        sec                     ; Cursor um sz nach vorne
        lda cur
        sbc sz
        sta cur
        lda cur+1
        sbc sz+1
        sta cur+1
        lda mt
        sta p
        lda mt+1
        sta p+1
        lda cur
        sta q
        lda cur+1
        sta q+1
        jsr moveup
        lda top                 ; top im verschobenen Bereich?
        cmp mt
        lda top+1
        sbc mt+1
        bcc mt_d1
        lda top
        cmp gs
        lda top+1
        sbc gs+1
        bcs mt_d1
        clc                     ; dann um den Gap weiter hinten
        lda top
        adc gsz
        sta top
        lda top+1
        adc gsz+1
        sta top+1
mt_d1   lda mt
        sta gs
        lda mt+1
        sta gs+1
        jmp setgap
; Ziel hinter dem Cursor: Text cur..mt nach vorne an gs
mt_up   sec                     ; sz = mt - cur
        lda mt
        sbc cur
        sta sz
        lda mt+1
        sbc cur+1
        sta sz+1
        lda cur
        sta p
        lda cur+1
        sta p+1
        lda gs
        sta q
        lda gs+1
        sta q+1
        jsr movedown
        lda top                 ; top im verschobenen Bereich?
        cmp cur
        lda top+1
        sbc cur+1
        bcc mt_u1
        lda top
        cmp mt
        lda top+1
        sbc mt+1
        bcs mt_u1
        sec                     ; dann um den Gap weiter vorne
        lda top
        sbc gsz
        sta top
        lda top+1
        sbc gsz+1
        sta top+1
mt_u1   clc                     ; gs um sz weiter
        lda gs
        adc sz
        sta gs
        lda gs+1
        adc sz+1
        sta gs+1
        lda mt                  ; Cursor = Ziel
        sta cur
        lda mt+1
        sta cur+1
        jmp setgap

k_pgdn  lda #20
        sta cnt2
-       jsr k_down
        dec cnt2
        bne -
        rts

k_pgup  lda #20
        sta cnt2
-       jsr k_up
        dec cnt2
        bne -
        rts

k_down  jsr rowstart
        jsr calccol             ; ccol = Spalte des Cursors
        lda ccol
        sta tmp                 ; gewuenschte Spalte merken (tmp)
        jsr nextrow
        bcs kd_rt               ; letzte Zeile
        jmp movecol
kd_rt   rts

k_up    jsr rowstart
        jsr calccol
        lda ccol
        sta tmp
        jsr isbeg
        beq ku_rt               ; schon in der ersten Zeile
        jsr prevrow
        jmp movecol
ku_rt   rts

; Cursor in der Zeile ab p auf die Spalte tmp setzen
; (oder davor, wenn die Zeile kuerzer ist)
; Ein Tabulator oder UTF-8 Umlaut wird nicht in der Mitte getroffen
movecol lda #0
        sta mcol                ; mcol = bisherige Spalte
        ldx #0
        jmp mc_lp
mc_zero #gapjmp p, mc_lp        ; Gap: dahinter weiterlesen
        jmp moveto              ; Textende
mc_lp   lda p                   ; q = Anfang des Zeichens
        sta q
        lda p+1
        sta q+1
        lda (p,x)
        beq mc_zero
        cmp #LF
        beq mc_dn
        #inc16 p
        cmp #TAB
        beq mc_tab
        jsr islead              ; Anfang eines UTF-8 Zeichens?
        bne mc_1
        #pk p
        jsr u8map
        bcs mc_1
        #skip2 p                ; zweites Byte gehoert zum Zeichen
mc_1    lda mcol
        clc
        adc #1                  ; ein Zeichen: 1 Spalte
        jmp mc_chk
mc_tab  lda mcol
        clc
        adc #TABW               ; Tabulator: TABW Spalten
mc_chk  cmp tmp
        beq mc_adv
        bcs mc_bk               ; ueber der gewuenschten Spalte: stop
mc_adv  sta mcol
        jmp mc_lp
mc_bk   lda q                   ; Cursor vor dieses Zeichen
        sta p
        lda q+1
        sta p+1
mc_dn   jmp moveto

; Spalte des Cursors am Bildschirm berechnen
; r = Anfang der Zeile, Ergebnis in ccol
calccol lda r
        sta q
        lda r+1
        sta q+1
        ldx #0
        ldy #0                  ; Y = Spalte
cc_lp   lda q+1                 ; fertig, wenn q den Cursor erreicht hat
        cmp cur+1
        bcc cc_c
        bne cc_dn
        lda q
        cmp cur
        bcs cc_dn
cc_c    lda (q,x)
        #nxt q
        cmp #TAB
        bne cc_n
        tya
        clc
        adc #TABW               ; Tabulator: TABW Spalten
        tay
        jmp cc_lp
cc_n    jsr islead              ; Anfang eines UTF-8 Zeichens?
        bne cc_1
        lda (q,x)
        jsr u8map
        bcs cc_1
        #nxt q                  ; zweites Byte gehoert zum Zeichen
cc_1    iny
        jmp cc_lp
cc_dn   sty ccol
        rts

; ---------------------------------------------------------------------
;  Zeilenlogik. Eine Bildschirmzeile endet nach LF oder nach 40 Zeichen.
; ---------------------------------------------------------------------
; Naechste Bildschirmzeile suchen
; p zeigt vorher auf den Anfang einer Zeile
; und danach auf den Anfang der naechsten Zeile
; Ein Tabulator zaehlt TABW Spalten, ein UTF-8 Umlaut eine Spalte
; Carry gesetzt: Textende erreicht (letzte Zeile)
nextrow ldx #0
        ldy #0                  ; Y = Spalte in der Zeile
nr1     lda (p,x)
        beq nr_zero
        #inc16 p
        cmp #LF
        beq nr_t
        cmp #TAB
        beq nr_tb
        jsr islead              ; Anfang eines UTF-8 Zeichens?
        bne nr_c
        #pk p
        jsr u8map
        bcs nr_c                ; nein, einzelnes Byte
        #skip2 p                ; zweites Byte gehoert zum Zeichen
nr_c    iny                     ; normales Zeichen: 1 Spalte weiter
        jmp nr_chk
nr_tb   tya                     ; Tabulator: TABW Spalten weiter
        clc
        adc #TABW
        tay
nr_chk  cpy #40
        bcc nr1                 ; Zeile noch nicht voll
nr_t    #norm p                 ; Zeilenanfang nie auf dem Gap
        clc
        rts
nr_zero #gapjmp p, nr1          ; Gap: dahinter weiterlesen
        sec                     ; Textende
        rts

; Anfang der Textzeile suchen (nach dem letzten LF)
; p zeigt vorher auf eine Stelle in der Zeile
; und danach auf den Zeilenanfang
linestart
ls1     jsr isbeg
        beq ls3
        #prv p
        ldy #0
        lda (p),y
        cmp #LF
        bne ls1
        #nxt p
ls3     rts

; Anfang der Bildschirmzeile mit dem Cursor suchen
; Danach zeigt p auf diesen Zeilenanfang
rowstart
        lda cur
        sta p
        lda cur+1
        sta p+1
        jsr linestart
rs_lp   lda p
        sta r
        lda p+1
        sta r+1
        jsr nextrow
        bcs rs_dn
        lda cur
        cmp p
        lda cur+1
        sbc p+1
        bcc rs_dn               ; Cursor liegt davor
        jmp rs_lp
rs_dn   lda r
        sta p
        lda r+1
        sta p+1
        rts

; Vorherige Bildschirmzeile suchen
; p zeigt vorher auf den Anfang einer Zeile
; und danach auf den Anfang der Zeile davor
prevrow lda p
        sta q
        lda p+1
        sta q+1
        #prv p
        jsr linestart
pw      lda p
        sta r
        lda p+1
        sta r+1
        jsr nextrow
        bcs pw_dn
        lda p
        cmp q
        bne pw
        lda p+1
        cmp q+1
        bne pw
pw_dn   lda r
        sta p
        lda r+1
        sta p+1
        rts

; ---------------------------------------------------------------------
;  Bildschirmausgabe
; ---------------------------------------------------------------------
fixtop  lda cur                 ; erste sichtbare Textstelle (top) nie hinter dem Cursor
        cmp top
        lda cur+1
        sbc top+1
        bcs +
        jsr rowstart
        lda p
        sta top
        lda p+1
        sta top+1
+       rts

; Zeile und Spalte des Cursors am Bildschirm bestimmen
; (Variablen crow und ccol)
; Ist der Cursor nicht sichtbar, wird der Text
; verschoben (top = erste sichtbare Textstelle)
findcursor
        jsr fixtop
fc_again
        lda top
        sta p
        lda top+1
        sta p+1
        lda #0
        sta crow
fc_loop lda p
        sta r
        lda p+1
        sta r+1
        jsr nextrow
        bcs fc_found
        lda cur
        cmp p
        lda cur+1
        sbc p+1
        bcc fc_found
        inc crow
        lda crow
        cmp #TROWS
        bne fc_loop
        jsr rowstart            ; Cursor unten sichtbar machen
        lda #TROWS-1
        sta cnt
fc_up   jsr isbeg
        beq fc_set
        jsr prevrow
        dec cnt
        bne fc_up
fc_set  lda p
        sta top
        lda p+1
        sta top+1
        jmp fc_again
fc_found
        jmp calccol             ; Spalte des Cursors berechnen

draw    lda top
        sta p
        lda top+1
        sta p+1
        lda #0
        sta drow
        ldx #0
dr_row  ldy drow
        lda rowlo,y
        sta sc
        lda rowhi,y
        sta sc+1
        ldy #0
        jmp dr_ch
dr_zero #gapjmp p, dr_ch         ; Gap: dahinter weiterlesen
        jmp dr_fill             ; Textende
dr_ch   lda (p,x)
        beq dr_zero
        #inc16 p
        cmp #LF
        beq dr_fill
        cmp #TAB
        beq dr_tab
        jsr islead              ; Anfang eines UTF-8 Zeichens?
        bne dr_a2s
        #pk p
        jsr u8map               ; Bildschirmcode des Zeichens holen
        bcs dr_lone
        pha
        #skip2 p                ; zweites Byte gehoert zum Zeichen
        pla
        jmp dr_put
dr_lone lda u8lead              ; einzelnes Byte: normale Darstellung
dr_a2s  jsr a2s
dr_put  sta (sc),y
        iny
        cpy #40
        bne dr_ch
        beq dr_next
dr_tab  lda #TABW               ; Tabulator als Leerzeichen zeigen
        sta tcnt
        lda #$20
dt_lp   sta (sc),y
        iny
        cpy #40
        bcs dr_next             ; Zeile voll
        dec tcnt
        bne dt_lp
        jmp dr_ch
dr_fill lda #$20
-       cpy #40
        bcs dr_next
        sta (sc),y
        iny
        bne -
dr_next inc drow
        lda drow
        cmp #TROWS
        beq +
        jmp dr_row
+       ldy crow                ; Cursor = invertiertes Zeichen
        lda rowlo,y
        sta sc
        lda rowhi,y
        sta sc+1
        ldy ccol
        lda (sc),y
        eor #$80
        sta (sc),y
        rts

rowlo   .for i = 0, i < 25, i += 1
        .byte <(SCREEN+i*40)
        .next
rowhi   .for i = 0, i < 25, i += 1
        .byte >(SCREEN+i*40)
        .next

; ---------------------------------------------------------------------
;  Infozeile: freien Textspeicher anzeigen (Spalten 27-37)
;  Rot, wenn weniger als 1000 Bytes frei sind (WARN)
; ---------------------------------------------------------------------
showfree
        sec                     ; frei = Groesse des Gap
        lda cur
        sbc gs
        sta sz
        sta freel
        lda cur+1
        sbc gs+1
        sta sz+1
        sta freeh
        jsr todec
        ldy #0
-       lda m_free,y
        beq +
        jsr a2s
        sta INFO+27,y
        iny
        bne -
+       ldx #0
-       lda numbuf,x
        sta INFO+33,x
        inx
        cpx #5
        bne -
        lda #TEXTCOL            ; Farbe: normal oder Warnung
        ldx freeh
        cpx #>WARN
        bcc iw
        bne ic
        ldx freel
        cpx #<WARN
        bcs ic
iw      lda #WARNCOL
ic      ldx #10
-       sta $d800+24*40+27,x
        dex
        bpl -
        rts

; Zahl sz (0-65535) als 5 Zeichen nach numbuf schreiben,
; fuehrende Nullen werden Leerzeichen
todec   ldx #0                  ; 5 Dezimalstellen bestimmen
dg_nx   lda #'0'
        sta numbuf,x
dg_sub  sec
        lda sz
        sbc pwlo,x
        tay
        lda sz+1
        sbc pwhi,x
        bcc dg_dn
        sta sz+1
        sty sz
        inc numbuf,x
        jmp dg_sub
dg_dn   inx
        cpx #5
        bne dg_nx
        ldx #0                  ; fuehrende Nullen durch Leerzeichen ersetzen
-       lda numbuf,x
        cmp #'0'
        bne +
        lda #$20
        sta numbuf,x
        inx
        cpx #4
        bne -
+       rts

pwlo    .byte <10000, <1000, <100, <10, <1
pwhi    .byte >10000, >1000, >100, >10, >1

; ---------------------------------------------------------------------
;  Statuszeile (invertiert)
; ---------------------------------------------------------------------
stclear ldx #39
        lda #$a0
-       sta STAT,x
        dex
        bpl -
        lda #0
        sta stcol
        rts

stputc  jsr a2s                 ; Zeichen im Register A ausgeben
        ora #$80
        ldx stcol
        cpx #40
        bcs +
        sta STAT,x
        inc stcol
+       rts

stprint ldy #0                  ; Text ausgeben, Adresse steht in p, Ende = 0
-       lda (p),y
        beq +
        jsr stputc
        iny
        bne -
+       rts

drawhelp
        jsr stclear
        #msg m_help
        rts

confirm jsr getkey              ; J oder Y = Ja (Carry-Bit gesetzt)
        cmp #$4a
        beq cf_y
        cmp #$59
        beq cf_y
        clc
        rts
cf_y    sec
        rts

; ---------------------------------------------------------------------
;  Neu / Ende / ASCII-Code
; ---------------------------------------------------------------------
k_new   jsr stclear
        #msg m_new
        jsr confirm
        bcc +
        jsr newtext
+       rts

k_quit  jsr stclear
        #msg m_quit
        jsr confirm
        bcc +
        lda #$37
        sta $01
        jmp $fce2               ; Neustart des C64
+       rts

k_code  jsr stclear
        #msg m_code
        lda #0
        sta tmp2                ; Anzahl Ziffern
kc_lp   jsr getkey
        cmp #$0d
        beq kc_done
        cmp #$03
        beq kc_no
        cmp #$14
        beq kc_bs               ; DEL: letzte Ziffer loeschen
        cmp #'0'
        bcc kc_lp
        cmp #'9'+1
        bcs kc_lp
        ldx tmp2
        cpx #5
        bcs kc_lp               ; mehr als 5 Ziffern gibt es nicht
        sta dbuf,x
        inc tmp2
        jsr stputc
        jmp kc_lp
kc_bs   lda tmp2                ; keine Ziffer vorhanden
        beq kc_lp
        dec tmp2
        dec stcol               ; Ziffer auf dem Bildschirm loeschen
        ldx stcol
        lda #$a0
        sta STAT,x
        jmp kc_lp
kc_no   rts

; RETURN: aus den Ziffern den Wert (16 Bit) berechnen
kc_done lda tmp2
        beq kc_no
        lda #0
        sta uval
        sta uval+1
        tax
kd_lp   asl uval                ; Wert x 10
        rol uval+1
        bcs kc_no
        lda uval
        sta u2
        lda uval+1
        sta u2+1                ; u2 = Wert x 2
        asl uval
        rol uval+1
        bcs kc_no
        asl uval
        rol uval+1
        bcs kc_no
        clc                     ; x8 + x2
        lda uval
        adc u2
        sta uval
        lda uval+1
        adc u2+1
        sta uval+1
        bcs kc_no
        lda dbuf,x              ; plus die Ziffer
        sec
        sbc #'0'
        clc
        adc uval
        sta uval
        bcc +
        inc uval+1
        beq kc_no               ; Ueberlauf ueber 65535
+       inx
        cpx tmp2
        beq +
        jmp kd_lp
+
; Wert in UTF-8 Bytes umwandeln (ubuf, ulen)
        lda uval+1
        bne kc_ge256
        lda uval
        beq kc_no               ; 0 gibt es nicht
        cmp #$0d
        beq kc_no               ; CR wird beim Laden ignoriert
        cmp #128
        bcs kc_two
        sta ubuf                ; bis 127: ein Byte (ASCII)
        lda #1
        sta ulen
        bne kc_put
kc_ge256 cmp #$08
        bcc kc_two              ; bis 2047: zwei Bytes
        cmp #$d8
        bcc kc_three
        cmp #$e0
        bcs kc_three
        rts                     ; $D800-$DFFF sind kein Zeichen
kc_three
        lda uval+1              ; ab 2048: drei Bytes
        lsr
        lsr
        lsr
        lsr
        ora #$e0
        sta ubuf
        jsr hi6                 ; mittlere 6 Bit
        sta ubuf+1
        lda uval
        and #$3f
        ora #$80
        sta ubuf+2
        lda #3
        sta ulen
        bne kc_put
kc_two  lda uval+1
        asl
        asl
        sta u2
        lda uval
        lsr
        lsr
        lsr
        lsr
        lsr
        lsr
        ora u2
        ora #$c0
        sta ubuf
        lda uval
        and #$3f
        ora #$80
        sta ubuf+1
        lda #2
        sta ulen
; Platz pruefen, dann alle Bytes einfuegen (nie nur ein Teil)
kc_put  sec                     ; Platz = Groesse des Gap
        lda cur
        sbc gs
        sta u2
        lda cur+1
        sbc gs+1
        bne kp_ok               ; mehr als 255 Bytes frei
        lda u2
        cmp ulen
        bcc kp_full
kp_ok   ldx #0
kp_lp   stx ucnt
        lda ubuf,x
        jsr insert
        ldx ucnt
        inx
        cpx ulen
        bne kp_lp
        rts
kp_full jsr stclear
        #msg m_full
        lda #1
        sta statshow
        rts

; Bits 6-11 des Wertes uval als UTF-8 Folgebyte ($80-$BF) in A
hi6     lda uval+1
        asl
        asl
        sta u2
        lda uval
        lsr
        lsr
        lsr
        lsr
        lsr
        lsr
        ora u2
        and #$3f
        ora #$80
        rts

; ---------------------------------------------------------------------
;  Dateien
; ---------------------------------------------------------------------
; Dateinamen abfragen (bleibt gespeichert)
; gnp = Adresse des Hinweistexts (Save file: / Load file:)
; CRSR hoch/runter: Laufwerk 8-11 waehlen
; Name $ zeigt das Inhaltsverzeichnis, danach erneute Abfrage
; Carry-Bit gesetzt: abgebrochen
getname jsr stclear
        lda gnp                 ; Hinweistext ausgeben
        sta p
        lda gnp+1
        sta p+1
        jsr stprint
        ldy #0
-       cpy flen
        beq +
        lda fname,y
        jsr stputc
        iny
        bne -
+       jsr gn_drv              ; Laufwerk rechts anzeigen
gn_lp   jsr getkey
        cmp #$0d
        beq gn_ok
        cmp #$03                ; STOP: abbrechen
        bne +
        sec
        rts
+
        cmp #$14
        beq gn_bs
        cmp #$11
        beq gn_dn               ; CRSR runter: naechstes Laufwerk
        cmp #$91
        beq gn_up               ; CRSR hoch: vorheriges Laufwerk
        cmp #$20
        bcc gn_lp
        cmp #$60
        bcs gn_lp
        ldx flen
        cpx #16
        bcs gn_lp
        sta fname,x
        inc flen
        jsr stputc
        jmp gn_lp
gn_bs   lda flen
        beq gn_lp
        dec flen
        dec stcol
        ldx stcol
        lda #$a0
        sta STAT,x
        jmp gn_lp
gn_dn   inc device
        lda device
        cmp #12
        bcc +
        lda #8
        sta device
+       jsr gn_drv
        jmp gn_lp
gn_up   dec device
        lda device
        cmp #8
        bcs +
        lda #11
        sta device
+       jsr gn_drv
        jmp gn_lp
gn_ok   lda flen
        beq gn_no
        cmp #1                  ; Name $ = Inhaltsverzeichnis
        bne gn_ret
        lda fname
        cmp #'$'
        bne gn_ret
        lda #0
        sta flen
        jsr showdir
        bcc +
        jsr getkey              ; Fehlermeldung lesen lassen
+       jmp getname
gn_ret  clc
        rts
gn_no   sec
        rts

; "Drive n" rechts in der Statuszeile anzeigen (Spalten 32-39)
gn_drv  ldy #0
-       lda m_drv,y
        beq +
        jsr gd_put
        bne -
+       lda device
        cmp #10
        bcc gd_1
        lda #'1'                ; zweistellig: 10, 11
        jsr gd_put
        lda device
        sec
        sbc #10
gd_1    clc
        adc #'0'
        jsr gd_put
        lda #$a0                ; Rest leeren
-       cpy #8
        bcs +
        sta STAT+32,y
        iny
        bne -
+       rts
gd_put  jsr a2s
        ora #$80
        sta STAT+32,y
        iny
        rts

; ---------------------------------------------------------------------
;  Inhaltsverzeichnis lesen
; ---------------------------------------------------------------------
; Verzeichnis ($) des Laufwerks oeffnen, Ladeadresse ueberlesen
; Carry gesetzt: Fehler (Meldung steht in der Statuszeile)
diropen lda #0
        jsr SETNAM
        jsr open15
        bcs do_err
        lda #2
        ldx device
        ldy #0
        jsr SETLFS
        lda #1
        ldx #<m_dollar
        ldy #>m_dollar
        jsr SETNAM
        jsr OPEN
        jsr drvstat             ; Laufwerk bereit?
        lda msgbuf
        cmp #'0'
        bne do_bad
        lda msgbuf+1
        cmp #'0'
        bne do_bad
        lda #0
        sta deof
        ldx #2
        jsr CHKIN
        jsr dgetb               ; Ladeadresse (2 Bytes)
        jsr dgetb
        clc
        rts
do_bad  jsr closeall
        jsr stclear
        jsr showdrv
        sec
        rts
do_err  jsr CLALL
        jsr stclear
        #msg m_dev
        lda #1
        sta statshow
        sec
        rts

; Ein Byte des Verzeichnisses lesen (nach dem Ende immer 0)
dgetb   lda deof
        bne db_z
        jsr CHRIN
        pha
        jsr READST
        sta deof                ; nicht 0: das war das letzte Byte
        pla
        rts
db_z    lda #0
        rts

; Eine Zeile des Verzeichnisses lesen
; dnum = Zahl am Zeilenanfang (Bloecke), lbuf/llen = Text der Zeile
; Carry gesetzt: Ende des Verzeichnisses
dline   jsr dgetb               ; Verkettung: 0 0 = Ende
        sta tmp
        jsr dgetb
        ora tmp
        beq dl_end
        jsr dgetb               ; Zahl (Bloecke)
        sta dnum
        jsr dgetb
        sta dnum+1
        ldy #0
dl_lp   jsr dgetb               ; Text bis zur 0
        beq dl_ok
        cpy #40
        bcs dl_lp               ; zu lang: Rest ueberlesen
        sta lbuf,y
        iny
        bne dl_lp
dl_ok   sty llen
        clc
        rts
dl_end  sec
        rts

; Inhaltsverzeichnis im Textbereich anzeigen (seitenweise)
; Carry gesetzt: Fehler (Meldung steht in der Statuszeile)
showdir jsr diropen
        bcc +
        rts
+       lda #0
        sta drow2
sd_lp   jsr dline
        bcs sd_end
        lda drow2
        cmp #TROWS
        bcc sd_row
        jsr sd_more             ; Seite voll: auf Taste warten
        bcs sd_stop
        lda #0
        sta drow2
sd_row  jsr sd_line
        inc drow2
        jmp sd_lp
sd_end  lda drow2               ; restliche Zeilen leeren
        cmp #TROWS
        bcs sd_stop
        jsr sd_clr
        inc drow2
        bne sd_end
sd_stop jsr closeall
        clc
        rts

; Seite voll: Hinweis zeigen, auf Taste warten
; Carry gesetzt: STOP gedrueckt
sd_more jsr CLRCHN
        jsr stclear
        #msg m_more
        jsr getkey
        pha
        ldx #2
        jsr CHKIN
        pla
        cmp #$03
        beq +
        clc
        rts
+       sec
        rts

; Zeile drow2 leeren, sc zeigt danach auf die Zeile
sd_clr  ldy drow2
        lda rowlo,y
        sta sc
        lda rowhi,y
        sta sc+1
        ldy #39
        lda #$20
-       sta (sc),y
        dey
        bpl -
        rts

; Verzeichniszeile in Zeile drow2 ausgeben: Zahl, Leerzeichen, Text
sd_line jsr sd_clr
        lda dnum
        sta sz
        lda dnum+1
        sta sz+1
        jsr todec
        ldx #0
-       lda numbuf,x            ; fuehrende Leerzeichen weglassen
        cmp #$20
        bne +
        inx
        bne -
+       ldy #0
-       lda numbuf,x            ; Ziffern (Bildschirmcode = ASCII)
        sta (sc),y
        iny
        inx
        cpx #5
        bne -
        iny
        lda #0
        sta drev
        ldx #0
sl_lp   cpx llen
        beq sl_rt
        cpy #40
        bcs sl_rt
        lda lbuf,x
        cmp #$12                ; Invers ein (Kopfzeile)
        bne +
        lda #$80
        sta drev
        bne sl_nx
+       stx dx
        jsr dchr
        ldx dx
        ora drev
        sta (sc),y
        iny
sl_nx   inx
        jmp sl_lp
sl_rt   rts

; Zeichen aus dem Verzeichnis in Bildschirmcode umwandeln
; (Namen wie in der Dateiabfrage: ohne SHIFT = Grossbuchstaben)
dchr    cmp #$a0                ; geschuetztes Leerzeichen
        bne +
        lda #$20
+       cmp #$c1                ; mit SHIFT: Kleinbuchstaben
        bcc +
        cmp #$db
        bcs +
        and #$7f
        ora #$20
+       jmp a2s

; Verzeichnis nach dem Dateinamen durchsuchen (fuer das Speichern)
; dfree = freie Bloecke, dok = 1 wenn diese Angabe gefunden wurde
; dold = Bloecke der alten Datei, dfound = 1 wenn es sie gibt
; Carry gesetzt: Fehler (Meldung steht in der Statuszeile)
dirscan lda #0
        sta dfound
        sta dok
        sta dold
        sta dold+1
        jsr diropen
        bcs ds_rt
        jsr dline               ; Kopfzeile ueberlesen
        bcs ds_end
ds_lp   jsr dline
        bcs ds_end
        jsr ds_line
        jmp ds_lp
ds_end  jsr closeall
        clc
ds_rt   rts

; Eine Zeile pruefen: ohne Anfuehrungszeichen = BLOCKS FREE,
; sonst den Namen in Anfuehrungszeichen mit fname vergleichen
ds_line ldx #0
-       cpx llen
        beq ds_nq
        lda lbuf,x
        cmp #'"'
        beq ds_q
        inx
        bne -
ds_nq   lda dnum
        sta dfree
        lda dnum+1
        sta dfree+1
        lda #1
        sta dok
        rts
ds_q    inx                     ; erstes Zeichen des Namens
        ldy #0
-       cpy flen
        beq ds_e
        cpx llen
        bcs ds_no
        lda lbuf,x
        cmp fname,y
        bne ds_no
        inx
        iny
        bne -
ds_e    cpx llen
        bcs ds_no
        lda lbuf,x
        cmp #'"'
        bne ds_no
        lda dnum
        sta dold
        lda dnum+1
        sta dold+1
        lda #1
        sta dfound
ds_no   rts

; Bloecke fuer den Text berechnen (254 Bytes je Block) -> dneed
needblk sec                     ; Laenge = Speicher - frei
        lda cur
        sbc gs
        sta u2
        lda cur+1
        sbc gs+1
        sta u2+1
        sec
        lda #<(BUFEND-BUF)
        sbc u2
        sta blen
        lda #>(BUFEND-BUF)
        sbc u2+1
        sta blen+1
        lda #0
        sta blen+2
        .if CRLF
        jsr tstart              ; jedes LF wird als CR+LF gespeichert
nb_c    ldx #0
        lda (p,x)
        beq nb_b
        cmp #LF
        bne nb_n
        inc blen
        bne nb_n
        inc blen+1
        bne nb_n
        inc blen+2
nb_n    #nxt p
        jmp nb_c
nb_b
        .endif
        lda #0
        sta dneed
        sta dneed+1
nb_lp   lda blen
        ora blen+1
        ora blen+2
        beq nb_dn
        inc dneed
        bne +
        inc dneed+1
+       lda blen+2              ; Rest hoechstens 254: fertig
        bne nb_sub
        lda blen+1
        bne nb_sub
        lda blen
        cmp #255
        bcc nb_dn
nb_sub  sec
        lda blen
        sbc #254
        sta blen
        lda blen+1
        sbc #0
        sta blen+1
        lda blen+2
        sbc #0
        sta blen+2
        jmp nb_lp
nb_dn   lda dneed               ; eine leere Datei braucht 1 Block
        ora dneed+1
        bne +
        inc dneed
+       rts

; Name fuer den Loeschbefehl bereitstellen: S0:name
setscratch
        lda #'S'
        sta fbuf
        lda #'0'
        sta fbuf+1
        lda #':'
        sta fbuf+2
        ldx #0
-       cpx flen
        beq +
        lda fname,x
        sta fbuf+3,x
        inx
        bne -
+       txa
        clc
        adc #3
        ldx #<fbuf
        ldy #>fbuf
        jmp SETNAM

; Dateiname bereitstellen: name,S,W oder name,S,R
; Im Register A steht 'W' (schreiben) oder 'R' (lesen)
setfile pha
        ldx #0
-       cpx flen
        beq +
        lda fname,x
        sta fbuf,x
        inx
        bne -
+       lda #','
        sta fbuf,x
        inx
        lda #'S'
        sta fbuf,x
        inx
        lda #','
        sta fbuf,x
        inx
        pla
        sta fbuf,x
        inx
        txa
        ldx #<fbuf
        ldy #>fbuf
        jmp SETNAM

; Umbenennen-Befehl bereitstellen: R0:name=TE64.TMP
setrename
        lda #'R'
        sta fbuf
        lda #'0'
        sta fbuf+1
        lda #':'
        sta fbuf+2
        ldx #0
-       cpx flen
        beq +
        lda fname,x
        sta fbuf+3,x
        inx
        bne -
+       txa
        clc
        adc #3
        tax
        lda #'='
        sta fbuf,x
        inx
        ldy #0
-       lda m_tmp,y
        beq +
        sta fbuf,x
        inx
        iny
        bne -
+       txa
        ldx #<fbuf
        ldy #>fbuf
        jmp SETNAM

; Hilfsnamen TE64.TMP als Dateinamen einsetzen (Name wird gemerkt)
usetmp  ldx #15
-       lda fname,x
        sta fsave,x
        dex
        bpl -
        lda flen
        sta flsave
        ldx #0
-       lda m_tmp,x
        beq +
        sta fname,x
        inx
        bne -
+       stx flen
        rts

; gemerkten Dateinamen wieder einsetzen
usename ldx #15
-       lda fsave,x
        sta fname,x
        dex
        bpl -
        lda flsave
        sta flen
        rts

; Kommandokanal 15 des Laufwerks oeffnen
; Vorher SETNAM aufrufen (setzt den Dateinamen)
; Carry gesetzt: Fehler
open15  lda #15
        ldx device
        ldy #15
        jsr SETLFS
        jsr OPEN
        bcs o15e
        jsr READST
        bne o15e
        clc
        rts
o15e    sec
        rts

; Meldung des Laufwerks lesen und in msgbuf ablegen
; (endet mit 0)
drvstat ldx #15
        jsr CHKIN
        ldy #0
-       jsr CHRIN
        cmp #$0d
        beq +
        sta msgbuf,y
        iny
        cpy #38
        bcc -
+       lda #0
        sta msgbuf,y
        jmp CLRCHN

showdrv ldy #0
-       lda msgbuf,y
        beq +
        jsr stputc
        iny
        bne -
+       lda #1
        sta statshow
        rts

closeall
        lda #2
        jsr CLOSE
        lda #15
        jsr CLOSE
        jmp CLRCHN

dev_err jsr CLALL
        jsr stclear
        #msg m_dev
        lda #1
        sta statshow
        rts

; Speichern mit Platzpruefung:
;  genug Platz fuer alte und neue Datei: unter TE64.TMP schreiben,
;    nur wenn das klappt, alte Datei loeschen und umbenennen
;  Platz reicht nur, wenn die alte Datei weg ist: direkt ueberschreiben
;  Platz reicht gar nicht: nichts loeschen, Meldung Disk full
k_save  lda #<m_sname
        sta gnp
        lda #>m_sname
        sta gnp+1
        jsr getname
        bcc +
        rts
+       jsr dirscan             ; freie Bloecke und alte Datei
        bcc +
        rts                     ; Laufwerk nicht bereit (Meldung steht)
+       jsr needblk             ; Bloecke fuer den Text
        lda dfound
        bne ks_old
        lda dok                 ; keine alte Datei
        beq ks_plain
        jsr fitfree
        bcs ks_plain
        bcc ks_full
ks_old  lda dok                 ; alte Datei vorhanden
        beq ks_safe             ; Platz unbekannt: sicher speichern
        jsr fitfree
        bcs ks_safe
        jsr fitboth
        bcs ks_plain
ks_full jsr stclear
        #msg m_dfull
        lda #1
        sta statshow
        rts

; direkt speichern: alte Datei loeschen, dann schreiben
ks_plain
        jsr setscratch
        jsr open15
        bcc +
        jmp dev_err
+       lda #15                 ; Kanal schliessen: Fehlerzustand
        jsr CLOSE               ; (z.B. 62 beim Loeschen) verwerfen
        jsr CLRCHN
        jsr wrtext
        bcc +
        jmp dev_err
+       jsr stclear
        jmp showdrv

; sicher speichern ueber die Hilfsdatei TE64.TMP
ks_safe jsr usetmp
        jsr scratch             ; alte Hilfsdatei loeschen
        bcs ks_dev
        jsr wrtext              ; Text in die Hilfsdatei
        bcs ks_dev
        lda msgbuf
        cmp #'0'
        bne ks_werr
        lda msgbuf+1
        cmp #'0'
        bne ks_werr
        jsr usename
        jsr scratch             ; alte Datei loeschen
        bcs ks_dev
        jsr setrename           ; Hilfsdatei umbenennen
        jsr open15
        bcs ks_dev
        jsr drvstat
        lda #15
        jsr CLOSE
        jsr CLRCHN
        jsr stclear
        jmp showdrv
ks_werr jsr stclear             ; Schreibfehler zeigen,
        jsr showdrv             ; Hilfsdatei loeschen,
        jsr scratch             ; alte Datei bleibt erhalten
        jmp usename
ks_dev  jsr usename
        jmp dev_err

; Datei fname loeschen (Ergebnis wird verworfen)
; Carry gesetzt: Laufwerk nicht bereit
scratch jsr setscratch
        jsr open15
        bcs +
        lda #15
        jsr CLOSE
        jsr CLRCHN
        clc
+       rts

; Reicht der freie Platz?  Carry gesetzt: ja
fitfree lda dfree
        cmp dneed
        lda dfree+1
        sbc dneed+1
        rts

; Reicht der Platz, wenn die alte Datei geloescht wird?  Carry gesetzt: ja
fitboth clc
        lda dfree
        adc dold
        sta u2
        lda dfree+1
        adc dold+1
        sta u2+1
        bcs +
        lda u2
        cmp dneed
        lda u2+1
        sbc dneed+1
+       rts

; Text in die Datei fname schreiben, Meldung danach in msgbuf
; Carry gesetzt: Laufwerk nicht bereit
wrtext  lda #0
        jsr SETNAM
        jsr open15              ; Kommandokanal fuer die Meldung
        bcc +
        rts
+       lda #2
        ldx device
        ldy #2
        jsr SETLFS
        lda #'W'
        jsr setfile
        jsr OPEN
        ldx #2
        jsr CHKOUT
        jsr tstart
sv_lp   ldx #0
        lda (p,x)
        beq sv_end              ; Endemarke
        .if CRLF
        cmp #LF
        bne +
        lda #$0d
        jsr CHROUT
        lda #LF
+
        .endif
        jsr CHROUT
        #nxt p
        jmp sv_lp
sv_end  jsr CLRCHN
        lda #2
        jsr CLOSE
        jsr drvstat
        lda #15
        jsr CLOSE
        jsr CLRCHN
        clc
        rts

k_load  lda #<m_lname
        sta gnp
        lda #>m_lname
        sta gnp+1
        jsr getname
        bcc +
        rts
+       lda #0
        jsr SETNAM
        jsr open15
        bcc +
        jmp dev_err
+       lda #2
        ldx device
        ldy #2
        jsr SETLFS
        lda #'R'
        jsr setfile
        jsr OPEN
        jsr drvstat
        lda msgbuf
        cmp #'0'
        bne ld_bad
        lda msgbuf+1
        cmp #'0'
        beq ld_ok
ld_bad  jmp ld_err
ld_ok
        jsr newtext
        lda #0
        sta toobig
        ldx #2
        jsr CHKIN
ld_lp   jsr CHRIN
        sta chr
        jsr READST
        sta tmp
        lda chr
        beq ld_nx               ; NUL und CR ueberspringen
        cmp #$0d
        beq ld_nx
        lda gs                  ; Gap voll: Datei zu gross
        cmp cur
        bne ld_st
        lda gs+1
        cmp cur+1
        bne ld_st
        lda #1
        sta toobig
        jmp ld_fin
ld_st   lda chr
        ldy #0
        sta (gs),y
        #inc16 gs
ld_nx   lda tmp
        beq ld_lp               ; Status 0: Datei noch nicht zu Ende
ld_fin  jsr setgap
        jsr closeall
        jsr k_clr               ; Cursor an den Textanfang
        lda cur
        sta top
        lda cur+1
        sta top+1
        jsr stclear
        lda toobig
        beq +
        #msg m_big
        jmp ld_end
+       #msg m_loaded
ld_end  lda #1
        sta statshow
        rts
ld_err  jsr closeall
        jsr stclear
        jmp showdrv

; ---------------------------------------------------------------------
;  Texte (ASCII, enden mit 0) und Variablen
; ---------------------------------------------------------------------
m_help  .null "F1 Save  F3 Load  F5 New  F8 ASCII Code"
m_pg    .null "F4 PgUp  F6 PgDn  F7 Exit  "
m_free  .null " Free:"
m_sname .null " Save file: "
m_lname .null " Load file: "
m_new   .null " Clear text? (Y/N)"
m_quit  .null " Exit editor? (Y/N)"
m_code  .null " Text code (e.g. 33-126): "
m_full  .null " Memory full!"
m_loaded .null " READY."
m_big   .null " File too big - truncated!"
m_dev   .null " Drive not ready!"
m_dfull .null " Disk full! Nothing saved."
m_more  .null " More: any key   STOP: end"
m_drv   .null "Drive "
m_dollar .null "$"
m_tmp   .null "TE64.TMP"

device  .byte 8
statshow .byte 0
stcol   .byte 0
crow    .byte 0
ccol    .byte 0
drow    .byte 0
cnt     .byte 0
cnt2    .byte 0
tmp     .byte 0
tmp2    .byte 0
chr     .byte 0
toobig  .byte 0
tcnt    .byte 0
mcol    .byte 0
mt      .word 0
gsz     .word 0
gnp     .word 0
dbuf    .fill 5,0
uval    .word 0
u2      .word 0
ubuf    .fill 3,0
ulen    .byte 0
ucnt    .byte 0
u8sx    .byte 0
u8lead  .byte 0
u8sec   .byte 0
flen    .byte 0
freel   .byte 0
freeh   .byte 0
numbuf  .fill 5, 0
fname   .fill 20, 0
fbuf    .fill 32, 0
fsave   .fill 16, 0
flsave  .byte 0
deof    .byte 0
dnum    .word 0
llen    .byte 0
lbuf    .fill 40, 0
drow2   .byte 0
drev    .byte 0
dx      .byte 0
dfree   .word 0
dold    .word 0
dneed   .word 0
dfound  .byte 0
dok     .byte 0
blen    .fill 3, 0
msgbuf  .fill 40, 0
progend
