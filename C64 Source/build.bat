::------------------------------------
::modify the path of kickass as needed
::------------------------------------

java -jar c:\KickAss.jar SL.asm -afo

java -jar c:\KickAss.jar SD.asm

java -jar c:\KickAss.jar SS.asm -o SSIO.prg :io=true

rename SS.sym SSIO.sym

java -jar c:\KickAss.jar SS.asm -o SS.prg :io=false