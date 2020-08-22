@echo off
rem 
rem cleanup the folder
rem 
for %%a in (*.obj *.dmp *.dis *.elf *.map) do del %%a

rem 
rem compile ALL .c files with the Microsoft C Compiler to Microsoft COFF .OBJ-modules
rem 
cl /nologo /c /Gw /Gy /O1 /Gu *.c

rem 
rem LINK (GNU ld) all those .OBJ-modules to an Linux .ELF executable in WSL (Windows Subsystem Linux) 
rem 
wsl ld --output=program.elf -Map=program.map --entry="begin" *.obj

rem 
rem dump and store .OBJ module information to its respective .DMP file using the Microsoft (R) COFF/PE Dumper
rem 
for %%a in (*.obj) do dumpbin /all %%a > %%~na.dmp

rem 
rem disassemble and store .ELF executable its respective .DIS file using the GNU objdump from GNU binutils
rem 
wsl objdump -d program.elf > program.dis

rem 
rem disassemble to screen, anyway...
rem 
type *.dis