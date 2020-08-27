@echo off
rem 
rem cleanup the folder
rem 
for %%a in (*.obj *.dmp *.dis *.elf *.map *.exe) do del %%a

rem 
rem compile ALL .c files with the Microsoft C Compiler to Microsoft COFF .OBJ-modules
rem 
rem /Gu[-] ensure distinct functions have distinct addresses
rem /Gw[-] separate global variables for linker
rem /Gy[-] separate functions for linker    /GS[-] enable security checks
rem /GL[-] enable link-time code generation
rem 
cl /nologo /c /Gw /Gy /Od /Gu /GL- *.c

rem 
rem LINK (GNU ld) all those .OBJ-modules to an Linux .ELF executable in WSL (Windows Subsystem Linux) 
rem 
wsl ld --output=program.elf -Map=program.elf.map --entry="begin" *.obj

rem 
rem LINK (MSFT) all those .OBJ-modules to an COFF/PE .EXE executable on Windows
rem 
link /entry:begin /out:program.exe /map:program.exe.map *.obj /subsystem:native /LTCG:OFF

rem 
rem dump and store .OBJ module information to its respective .DMP file using the Microsoft (R) COFF/PE Dumper
rem 
for %%a in (*.obj) do dumpbin /all %%a > %%~na.dmp

rem 
rem disassemble and store .ELF executable its respective .DIS file using the GNU objdump from GNU binutils
rem 
wsl objdump -d program.elf > program.elf.dis

rem 
rem disassemble and store .EXE executable its respective .DIS file using the MSFT dumpbin
rem 
dumpbin /disasm program.exe > program.exe.dis

rem 
rem disassemble to screen, anyway...
rem 
type *.dis