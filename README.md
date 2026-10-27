# C64 ASCII Texteditor 
A text editor capable of loading, editing, and saving ASCII text.  
  
The editor supports the 7-bit ASCII character set (ANSI X3.4-1986), with the exception of the NUL and CR characters, which are deliberately ignored when loading a file.  
Special characters are converted to suitable C64 screen codes for display.  
  
### Features
  
- Files are saved as C64 SEQ files containing plain ASCII text.  
  (On Windows, the file extension must be changed to `.txt`.)
- Optional line endings: LF or CRLF.
- Text buffer at `$4000–$CEFF` (approximately 36 KB); BASIC ROM is switched off.
- The uppercase/lowercase character set is copied to RAM at `$3000`.
- All keyboard input is converted to ASCII.
- Characters that cannot be entered directly via the keyboard can be entered manually using F8.  
- Codes above 127: They are not part of ASCII. Input is possible, but display is not.
- Umlauts in PC files are displayed as an inverted full stop.  
   
### ANSI X3.4-1986 characters
```
!"#$%&'()*+,-./ 
0123456789:;<=>? @  
ABCDEFGHIJKLMNO  
PQRSTUVWXYZ[\]^_ `  
abcdefghijklmno   
pqrstuvwxyz {|}~   
```  
  
### Keyboard controls:
    Cursor keys    Move cursor       HOME      Start of line  
    DEL            Backspace         CLR       Start of text  
    SHIFT+DEL      Delete (INST)     F2        End of text  
    RETURN         New line          F4 / F6   Page up / down  
  
    F1  Save   F3  Load   F5  New   F7  Quit  
  
    F8  Allows any ASCII code to be inserted (decimal values 1–127, extended up to 255)  
    Examples of decimal values:  
     126 = ~   123 = {   125 = }   96 = `   92 = \  
      9 = Tab   12 = Form feed (PC: CTRL+L)   27 = ESC   127 = DEL  
  
    Alternative character representation:  
        { } = displayed as inverted parentheses ()  
         ~  = displayed as an inverted minus sign -  

    Direct character input on the C64 keyboard:  
        Pound key           = Backslash  
        Left-arrow key      = Underscore _ (also SHIFT+Pound key)  
        SHIFT+| (key before RESTORE) = ^  
        SHIFT+: = [      SHIFT+; = ]  
        | = ASCII pipe character |  
  
Start the program from disk using LOAD"TEXTEDITOR",8 and RUN.

### Useful Information:
PETSCII-Codes
```  
https://www.c64-wiki.de/wiki/PETSCII  
```  
### ANSI X3.4
```  
https://en.wikipedia.org/wiki/ASCII  
```  
  
   
