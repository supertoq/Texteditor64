; =====================================================================
;  ASCII-Texteditor fuer den C64 
;  Copyright (c) 2026 supertoq
;  Version 1.0_d
;  
;  Ein Texteditor der in der Lage ist ASCII Code zu laden, zu editieren und zu speichern.
;  Unterstuetzt wird der 7-Bit-ASCII-Zeichensatz (ANSI X3.4-1986),
;  ausgenommen der Zeichen NUL und CR, diese werden beim Laden einer Datei bewusst ignoriert.
;  ANSI Sonderzeichen werden fuer die Darstellung auf dem C64 in passende Bildschirmcodes umgewandelt.
;  
;  - Dateien werden als C64 SEQ-Dateien mit reinem ASCII gespeichert 
;    (in Windows muss die Dateiendung in .txt umbenannt werden)
;  - Zeilenende LF oder CRLF optional umstellbar
;  - Textspeicher $4000-$CEFF (ca. 36 KB), BASIC-ROM wird abgeschaltet
;  - Programmspeicherverbrauch 5 kB
;  - Zeichensatz Gross/Klein wird in den RAM $3000 kopiert
;  - Jede Eingabe wird nach ASCII umgewandelt
;  - nicht verfuegbare Tasteneingaben koennen per F8 haendisch eingetragen werden
;  - Deutsche UTF-8 Umlaute werden als invertierter Buchstabe angezeigt, keine Umwandlung im Text
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
;        { } = dargestellt als invertierte Klammern ()
;         ~  = dargestellt als invertiertes Minus -
;        UTF-8 Umlaute = dargestellt als invertiertes Zeichen      
;
;  Editor starten - von Diskette per LOAD"TEXTEDITOR",8 und RUN
;
; =====================================================================

        .cpu "6502"

; Textcodierung: Zeichen werden 1:1 als ASCII abgelegt
        .enc "ascii"
        .cdef $00, $ff, $00

; Option:
CRLF    = 0                     ; Zeilenende: 0 = LF, 1 = CR+LF

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
;    tend   Textende (Adresse hinter dem letzten Zeichen)
;    top    erste Textstelle, die oben am Bildschirm steht
;    p, q, r  Zeiger auf Textstellen (Hilfsvariablen)
;    sc     Zeiger auf eine Stelle im Bildschirmspeicher
;    sz     Anzahl Bytes, die beim Verschieben von Text betroffen sind
;    crow   Zeile des Cursors am Bildschirm
;    ccol   Spalte des Cursors am Bildschirm
;    tmp, tmp2, tcnt, mcol, u8sx  Hilfsvariablen
;    LF     Zeilenvorschub, das Zeilenende-Zeichen (Code 10)
; ---------------------------------------------------------------------

; ---- Zeropage
cur     = $22                   ; Cursorposition im Text
tend    = $24                   ; Textende (danach folgt eine 0)
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

dec16   .macro
        lda \1
        bne _skip
        dec \1+1
_skip   dec \1
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
        jsr info
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
; der Bildschirmcode steht danach in A
a2s     cmp #$20
        bcc a2s_np
        cmp #$40
        bcc a2s_rt              ; $20-$3F
        bne a2s_1
        lda #0                  ; @
        rts
a2s_1   cmp #$5b
        bcc a2s_rt              ; A-Z
        cmp #$5f                ; Unterstrich _ 
        beq +
        cmp #$60
        bcs a2s_2
        and #$1f                ; [ \ ] ^  (\ = eigenes Zeichen $1C)
        rts
+       lda #$64                ; _ als Grafikzeichen
        rts
a2s_2   cmp #$60                ; Backtick `
        bne +
        lda #$a7                ; ` als invertiertes Apostroph '
        rts
+       cmp #$61
        bcc a2s_np
        cmp #$7b
        bcs a2s_3
        and #$1f                ; a-z
        rts
a2s_3   cmp #$7b
        bne +
        lda #$a8                ; { als invertiertes (
        rts
+       cmp #$7c
        bne +
        lda #$5d                ; | als Grafikzeichen (senkrechter Strich)
        rts
+       cmp #$7d
        bne +
        lda #$a9                ; } als invertiertes )
        rts
+       cmp #$7e
        bne a2s_np
        lda #$ad                ; ~ als invertiertes -
        rts
a2s_np  lda #$ae                ; nicht darstellbar: invertierter Punkt
a2s_rt  rts

; Zweites Byte eines UTF-8 Umlauts pruefen (nach dem Anfangsbyte 195)
; Das Byte kommt im Register A an.
; Carry geloescht: gueltig, A = Bildschirmcode des Umlauts
; Carry gesetzt: kein Umlaut
; Die Register X und Y bleiben unveraendert
u8map   stx u8sx
        ldx #6
um1     cmp u8tab,x
        beq um2
        dex
        bpl um1
        ldx u8sx
        sec
        rts
um2     lda u8gly,x
        ldx u8sx
        clc
        rts

; Zweite Bytes:   a-Uml. o-Uml. u-Uml. A-Uml. O-Uml. U-Uml. scharfes s
u8tab   .byte     $a4,   $b6,   $bc,   $84,   $96,   $9c,   $9f
; Bildschirmcodes (invertierte Buchstaben a o u A O U B)
u8gly   .byte     $81,   $8f,   $95,   $c1,   $cf,   $d5,   $c2

; ---------------------------------------------------------------------
;  Text aendern
; ---------------------------------------------------------------------
newtext lda #<BUF
        sta cur
        sta top
        sta tend
        lda #>BUF
        sta cur+1
        sta top+1
        sta tend+1
setsent ldy #0                  ; Endemarke 0 hinter den Text
        tya
        sta (tend),y
        rts

; Zeichen in den Text einfuegen
; Das Zeichen kommt im Register A an
insert  sta chr                 ; Zeichen zwischenspeichern
        lda tend+1
        cmp #>BUFEND
        bcc ins_ok
        jsr stclear
        #msg m_full
        lda #1
        sta statshow
        rts
ins_ok  sec                     ; Bytes hinter dem Cursor zaehlen (sz)
        lda tend
        sbc cur
        sta sz
        lda tend+1
        sbc cur+1
        sta sz+1
        ora sz
        beq ins_st
        lda cur                 ; Rest um 1 nach oben schieben
        sta p
        lda cur+1
        sta p+1
        clc
        lda cur
        adc #1
        sta q
        lda cur+1
        adc #0
        sta q+1
        jsr moveup
ins_st  lda chr
        ldy #0
        sta (cur),y
        #inc16 cur
        #inc16 tend
        jmp setsent

delchar ldx #0                  ; Zeichen unter dem Cursor loeschen
        lda (cur,x)
        beq dl_rt               ; am Textende nichts zu tun
        sec                     ; Bytes hinter dem Cursor zaehlen (sz)
        lda tend
        sbc cur
        sta sz
        lda tend+1
        sbc cur+1
        sta sz+1
        #dec16 sz
        lda cur
        clc
        adc #1
        sta p
        lda cur+1
        adc #0
        sta p+1
        lda cur
        sta q
        lda cur+1
        sta q+1
        jsr movedown
        #dec16 tend
        jmp setsent
dl_rt   rts

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

k_bs    lda cur+1               ; Backspace
        cmp #>BUF
        bne +
        lda cur
        cmp #<BUF
        beq kb_rt
+       jsr k_left              ; ein Zeichen zurueck (auch ganzer Umlaut)
        jmp k_del               ; und dieses Zeichen loeschen
kb_rt   rts

; Zeichen unter dem Cursor loeschen
; ein UTF-8 Umlaut wird komplett geloescht (beide Bytes)
k_del   ldy #0
        lda (cur),y
        cmp #$c3
        bne kx_one
        iny
        lda (cur),y
        jsr u8map
        bcs kx_one
        jsr delchar             ; erstes Byte
kx_one  jmp delchar             ; (zweites) Byte

; Cursor ein Zeichen nach links (UTF-8 Umlaut = ein Zeichen)
k_left  lda cur+1
        cmp #>BUF
        bne +
        lda cur
        cmp #<BUF
        beq kl_rt
+       #dec16 cur
        ldy #0
        lda (cur),y
        jsr u8map               ; ist es ein zweites Umlaut-Byte?
        bcs kl_rt
        lda cur+1               ; steht davor noch ein Byte?
        cmp #>BUF
        bne kl_chk
        lda cur
        cmp #<BUF
        beq kl_rt
kl_chk  #dec16 cur
        ldy #0
        lda (cur),y
        cmp #$c3                ; davor das Anfangsbyte: Cursor bleibt dort
        beq kl_rt
        #inc16 cur              ; sonst doch nur ein Byte zurueck
kl_rt   rts

; Cursor ein Zeichen nach rechts (UTF-8 Umlaut = ein Zeichen)
k_right ldy #0
        lda (cur),y
        beq kr_rt
        #inc16 cur
        cmp #$c3
        bne kr_rt
        lda (cur),y             ; folgt ein zweites Umlaut-Byte?
        jsr u8map
        bcs kr_rt
        #inc16 cur
kr_rt   rts

k_home  jsr rowstart
        lda p
        sta cur
        lda p+1
        sta cur+1
        rts

k_clr   lda #<BUF
        sta cur
        lda #>BUF
        sta cur+1
        rts

k_end   lda tend
        sta cur
        lda tend+1
        sta cur+1
        rts

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
        lda p+1
        cmp #>BUF
        bne +
        lda p
        cmp #<BUF
        beq ku_rt               ; schon in der ersten Zeile
+       jsr prevrow
        jmp movecol
ku_rt   rts

; Cursor in der Zeile ab p auf die Spalte tmp setzen
; (oder davor, wenn die Zeile kuerzer ist)
; Ein Tabulator oder UTF-8 Umlaut wird nicht in der Mitte getroffen
movecol lda #0
        sta mcol                ; mcol = bisherige Spalte
mc_lp   ldy #0
        lda (p),y
        beq mc_dn
        cmp #LF
        beq mc_dn
        ldx #1                  ; X = Laenge des Zeichens in Bytes
        cmp #TAB
        beq mc_tab
        cmp #$c3                ; Anfang eines UTF-8 Umlauts?
        bne mc_1
        iny
        lda (p),y
        jsr u8map
        bcs mc_1
        ldx #2                  ; Umlaut: zwei Bytes
mc_1    lda mcol
        clc
        adc #1                  ; ein Zeichen: 1 Spalte
        jmp mc_chk
mc_tab  lda mcol
        clc
        adc #TABW               ; Tabulator: TABW Spalten
mc_chk  cmp tmp
        beq mc_adv
        bcs mc_dn               ; ueber der gewuenschten Spalte: stop
mc_adv  sta mcol
mc_inc  #inc16 p
        dex
        bne mc_inc
        jmp mc_lp
mc_dn   lda p
        sta cur
        lda p+1
        sta cur+1
        rts

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
        #inc16 q
        cmp #TAB
        bne cc_n
        tya
        clc
        adc #TABW               ; Tabulator: TABW Spalten
        tay
        jmp cc_lp
cc_n    cmp #$c3                ; Anfang eines UTF-8 Umlauts?
        bne cc_1
        lda (q,x)
        jsr u8map
        bcs cc_1
        #inc16 q                ; zweites Byte gehoert zum Zeichen
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
        beq nr_eof
        #inc16 p
        cmp #LF
        beq nr_t
        cmp #TAB
        beq nr_tb
        cmp #$c3                ; Anfang eines UTF-8 Umlauts?
        bne nr_c
        lda (p,x)
        jsr u8map
        bcs nr_c                ; nein, einzelnes Byte
        #inc16 p                ; zweites Byte gehoert zum Zeichen
nr_c    iny                     ; normales Zeichen: 1 Spalte weiter
        jmp nr_chk
nr_tb   tya                     ; Tabulator: TABW Spalten weiter
        clc
        adc #TABW
        tay
nr_chk  cpy #40
        bcc nr1                 ; Zeile noch nicht voll
nr_t    clc
        rts
nr_eof  sec
        rts

; Anfang der Textzeile suchen (nach dem letzten LF)
; p zeigt vorher auf eine Stelle in der Zeile
; und danach auf den Zeilenanfang
linestart
ls1     lda p+1
        cmp #>BUF
        bne ls2
        lda p
        cmp #<BUF
        beq ls3
ls2     #dec16 p
        ldy #0
        lda (p),y
        cmp #LF
        bne ls1
        #inc16 p
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
        #dec16 p
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
fc_up   lda p+1
        cmp #>BUF
        bne +
        lda p
        cmp #<BUF
        beq fc_set
+       jsr prevrow
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
dr_ch   lda (p,x)
        beq dr_fill
        #inc16 p
        cmp #LF
        beq dr_fill
        cmp #TAB
        beq dr_tab
        cmp #$c3                ; Anfang eines UTF-8 Umlauts?
        bne dr_a2s
        lda (p,x)
        jsr u8map               ; Bildschirmcode des Umlauts holen
        bcs dr_lone
        #inc16 p                ; zweites Byte gehoert zum Zeichen
        jmp dr_put
dr_lone lda #$c3                ; einzelnes Byte: normale Darstellung
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
        bne dr_row
        ldy crow                ; Cursor = invertiertes Zeichen
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
info    sec
        lda #<BUFEND
        sbc tend
        sta sz
        sta freel
        lda #>BUFEND
        sbc tend+1
        sta sz+1
        sta freeh
        ldx #0                  ; 5 Dezimalstellen bestimmen
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
+       ldy #0
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
kc_put  lda tend
        clc
        adc ulen
        sta u2
        lda tend+1
        adc #0
        cmp #>BUFEND
        bcc kp_ok
        bne kp_full
        lda u2
        bne kp_full
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
+
gn_lp   jsr getkey
        cmp #$0d
        beq gn_ok
        cmp #$03
        beq gn_no
        cmp #$14
        beq gn_bs
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
gn_ok   lda flen
        beq gn_no
        clc
        rts
gn_no   sec
        rts

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

k_save  lda #<m_sname
        sta gnp
        lda #>m_sname
        sta gnp+1
        jsr getname
        bcc +
        rts
+       jsr setscratch          ; alte Datei gleichen Namens loeschen
        jsr open15
        bcc +
        jmp dev_err
+       lda #15                 ; Kanal schliessen: Fehlerzustand
        jsr CLOSE               ; (z.B. 62 beim Loeschen) verwerfen
        jsr CLRCHN
        lda #0
        jsr SETNAM
        jsr open15              ; Kommandokanal frisch oeffnen
        bcc +
        jmp dev_err
+       lda #2
        ldx device
        ldy #2
        jsr SETLFS
        lda #'W'
        jsr setfile
        jsr OPEN
        ldx #2
        jsr CHKOUT
        lda #<BUF
        sta p
        lda #>BUF
        sta p+1
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
        #inc16 p
        jmp sv_lp
sv_end  jsr CLRCHN
        lda #2
        jsr CLOSE
        jsr drvstat
        lda #15
        jsr CLOSE
        jsr CLRCHN
        jsr stclear
        jmp showdrv

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
        bne ld_err
        lda msgbuf+1
        cmp #'0'
        bne ld_err
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
        lda tend+1
        cmp #>BUFEND
        bcc ld_st
        lda #1
        sta toobig
        jmp ld_fin
ld_st   lda chr
        ldy #0
        sta (tend),y
        #inc16 tend
ld_nx   lda tmp
        beq ld_lp               ; Status 0: Datei noch nicht zu Ende
ld_fin  jsr setsent
        jsr closeall
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
gnp     .word 0
dbuf    .fill 5,0
uval    .word 0
u2      .word 0
ubuf    .fill 3,0
ulen    .byte 0
ucnt    .byte 0
u8sx    .byte 0
flen    .byte 0
freel   .byte 0
freeh   .byte 0
numbuf  .fill 5, 0
fname   .fill 20, 0
fbuf    .fill 24, 0
msgbuf  .fill 40, 0
progend
