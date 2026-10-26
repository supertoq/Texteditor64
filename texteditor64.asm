; =====================================================================
;  Texteditor64 - kleiner ASCII-Texteditor fuer den C64 
;  Copyright (c) 2026 supertoq
;  Version 0
;
;  Assemblieren:   64tass -C texteditor64.asm -o TEXTEDITOR.PRG   (ohne -a)
;  Starten:        LOAD"TED64",8   dann RUN
; =====================================================================

        .cpu "6502"

; Textcodierung: Zeichen werden 1:1 als ASCII abgelegt
        .enc "ascii"
        .cdef $00, $ff, $00

BUF     = $4000                 ; Textanfang
BUFEND  = $cf00                 ; Text darf bis hier wachsen
SCREEN  = $0400
TROWS   = 23                    ; Textzeilen auf dem Bildschirm
STAT    = SCREEN+23*40          ; Statuszeile (Hilfe/Meldungen)
; ---------------------------------------------------------------------

; Code ist noch unvollständig!

; ---------------------------------------------------------------------
