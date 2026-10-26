# C64 ASCII Texteditor 
A C64 ASCII text editor that supports a minimal set of basic characters (ANSI X3.4-1986+).  
  
With this text editor, you can load, edit, and save text files from Windows or Linux on the C64.   
The files can then be opened in any standard text editor on a PC.  

Readable:  
!"#$%&'()*+,-./ 
0123456789:;<=>? 
@ABCDEFGHIJKLMNO 
PQRSTUVWXYZ[] 
abcdefghijklmno 
pqrstuvwxyz{|}   
(Non-displayable characters are shown as inverted periods)  
  
Writable:  
!"#$%&'()*+,-./ 
0123456789:;<=>? 
@ABCDEFGHIJKLMNO 
PQRSTUVWXYZ[\]^_ 
`abcdefghijklmno 
pqrstuvwxyz{|}~    
(plus all other ASCII codes entered as decimal values)  
  
-----  

The program can be assembled as follows:  
```
64tass -C texteditor64.asm -o TEXTEDITOR.PRG 
```  

  
