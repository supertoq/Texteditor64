; =====================================================================
;  ASCII-Texteditor fuer den C64 
;  Copyright (c) 2026 supertoq
;  Version 1.0_a
;  
;  Ein Texteditor der in der Lage ist ASCII Code zu laden, zu editieren und zu speichern.
;  Unterstuetzt wird der 7-Bit-ASCII-Zeichensatz (ANSI X3.4-1986),
;  ausgenommen der Zeichen NUL und CR, diese werden beim Laden einer Datei bewusst ignoriert.
;  Sonderzeichen werden fuer die Darstellung auf dem C64 in passende Bildschirmcodes umgewandelt.
;
;  - Dateien werden als C64 SEQ-Dateien mit reinem ASCII gespeichert 
;    (in Windows muss die Dateiendung in .txt umbenannt werden)
;  - Zeilenende LF oder CRLF optional umstellbar
;  - Textspeicher $4000-$CEFF (ca. 36 KB), BASIC-ROM wird abgeschaltet
;  - Zeichensatz Gross/Klein wird in den RAM $3000 kopiert
;  - Jede Eingabe wird nach ASCII umgewandelt
;  - nicht verfuegbare Tasteneingaben koennen per F8 haendisch eingetragen werden
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
;        Linkspfeil-Taste            =  Unterstrich _  (ebenso SHIFT+Pfund)
;        | (Taste vor RESTORE)       =  ASCII Pipe | 
;        SHIFT+| (Taste vor RESTORE) =  ^   
;        SHIFT+:  =  [      SHIFT+;  =  ]
;
;    F8  =  ASCII-Code Eingabe (Dezimalwerte 1-127, + erweitert bis 255)
;    
;        Beispiele für Dezimalwerte:
;        126 = ~   123 = {   125 = }   96 = `   92 = \ 
;        9 = Tab   12 = Seitenumbruch(PC: CTRL+L)   27 = ESC   127 = DEL
;
;  Alternative Zeichendarstellung:
;        { } = dargestellt als invertierte Klammern ()
;         ~  = dargestellt als invertiertes Minus -
;
;
;  Editor starten - von Diskette per LOAD"TEXTEDITOR",8 und RUN
;
; =====================================================================

        .cpu "6502"

; Textcodierung: Zeichen werden 1:1 als ASCII abgelegt
        .enc "ascii"
        .cdef $00, $ff, $00

; Option:
CRLF    = 1                     ; Zeilenende: 0 = LF, 1 = CR+LF

; ---- Speicheraufteilung
BUF     = $4000                 ; Textspeicher: Anfang
BUFEND  = $cf00                 ; Textspeicher: Ende
SCREEN  = $0400
TROWS   = 23                    ; Textzeilen auf dem Bildschirm
STAT    = SCREEN+23*40          ; Statuszeile (Hilfe/Meldungen)
INFO    = SCREEN+24*40          ; Infozeile (freier Speicher)
WARN    = 1000                  ; darunter wird die Anzeige rot
WARNCOL = 10                    ; Warnfarbe (hellrot)
LF      = $0a
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
;    tmp, tmp2, tmp3  Hilfsvariablen
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
        cmp #$60
        bcc p2a_ok              ; $5B-$5F  [ \ ] _
        cmp #$a9
        beq p2a_us              ; SHIFT+Pfund-Taste -> _
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
+       #dec16 cur
        jmp delchar
kb_rt   rts

k_del   jmp delchar

k_left  lda cur+1
        cmp #>BUF
        bne +
        lda cur
        cmp #<BUF
        beq kl_rt
+       #dec16 cur
kl_rt   rts

k_right ldx #0
        lda (cur,x)
        beq kr_rt
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
; Ein Tabulator wird nicht in der Mitte getroffen
movecol ldx #0
        ldy #0                  ; Y = bisherige Spalte
mc_lp   lda (p,x)
        beq mc_dn
        cmp #LF
        beq mc_dn
        cmp #TAB
        beq mc_tab
        tya
        clc
        adc #1                  ; normales Zeichen: 1 Spalte
        jmp mc_chk
mc_tab  tya
        clc
        adc #TABW               ; Tabulator: TABW Spalten
mc_chk  cmp tmp
        beq mc_adv
        bcs mc_dn               ; ueber der gewuenschten Spalte: stop
mc_adv  tay
        #inc16 p
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
cc_lp   lda q
        cmp cur
        bne cc_c
        lda q+1
        cmp cur+1
        beq cc_dn               ; Cursor erreicht
cc_c    lda (q,x)
        #inc16 q
        cmp #TAB
        bne cc_1
        tya
        clc
        adc #TABW               ; Tabulator: TABW Spalten
        tay
        jmp cc_lp
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
; Ein Tabulator zaehlt TABW Spalten
; Carry gesetzt: Textende erreicht (letzte Zeile)
nextrow ldx #0
        ldy #0                  ; Y = Spalte in der Zeile
nr1     lda (p,x)
        beq nr_eof
        #inc16 p
        cmp #LF
        beq nr_t
        cmp #TAB
        bne nr_c
        tya                     ; Tabulator: TABW Spalten weiter
        clc
        adc #TABW
        tay
        jmp nr_chk
nr_c    iny                     ; normales Zeichen: 1 Spalte weiter
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
        jsr a2s
        sta (sc),y
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
        sta tmp                 ; Zahlenwert
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
        sec
        sbc #'0'
        sta digit
        lda tmp
        cmp #26
        bcs kc_lp               ; Wert wuerde ueber 255 gehen
        asl
        sta tmp3                ; Wert x 2
        asl
        asl                     ; Wert x 8
        clc
        adc tmp3                ; Wert x 10
        clc
        adc digit
        bcs kc_lp
        sta tmp
        inc tmp2
        lda digit
        clc
        adc #'0'
        jsr stputc
        jmp kc_lp
kc_bs   lda tmp2                ; keine Ziffer vorhanden
        beq kc_lp
        dec tmp2
        dec stcol               ; Ziffer auf dem Bildschirm loeschen
        ldx stcol
        lda #$a0
        sta STAT,x
        lda tmp                 ; Wert durch 10 teilen
        ldx #0
-       sec
        sbc #10
        bcc +
        inx
        bne -
+       stx tmp
        jmp kc_lp
kc_done lda tmp2
        beq kc_no
        lda tmp
        beq kc_no
        jmp insert
kc_no   rts

; ---------------------------------------------------------------------
;  Dateien
; ---------------------------------------------------------------------
; Dateinamen abfragen (bleibt gespeichert)
; Carry-Bit gesetzt: abgebrochen
getname jsr stclear
        #msg m_name
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

k_save  jsr getname
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

k_load  jsr getname
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
m_free  .null " Free: "
m_name  .null " File: "
m_new   .null " Clear text? (Y/N)"
m_quit  .null " Exit editor? (Y/N)"
m_code  .null " ASCII code 1-255, RETURN: "
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
tmp3    .byte 0
digit   .byte 0
chr     .byte 0
toobig  .byte 0
tcnt    .byte 0
flen    .byte 0
freel   .byte 0
freeh   .byte 0
numbuf  .fill 5, 0
fname   .fill 20, 0
fbuf    .fill 24, 0
msgbuf  .fill 40, 0
progend
