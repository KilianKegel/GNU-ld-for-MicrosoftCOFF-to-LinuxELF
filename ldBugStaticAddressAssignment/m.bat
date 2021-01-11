@echo off
rem 
rem cleanup the folder
rem 
for %%a in (*.obj *.dmp *.dis *.elf *.map *.exe) do del %%a

rem 
rem compile ALL .c files with the Microsoft C Compiler to Microsoft COFF .OBJ-modules
rem 
rem /Od disable optimizations (default)
rem /O1 maximum optimizations (favor space)
rem /c compile only, no link
rem 
cl /nologo /c /Od *.c

rem 
rem LINK (GNU ld) all those .OBJ-modules to an Linux .ELF executable in WSL (Windows Subsystem Linux) 
rem 
wsl ld --output=program.elf -Map=program.elf.map --entry="begin" *.obj

rem 
rem LINK (MSFT) all those .OBJ-modules to an COFF/PE .EXE executable on Windows
rem 
link /entry:begin /out:program.exe /map:program.exe.map *.obj /subsystem:console /LTCG:OFF

rem 
rem dump and store .OBJ module information to its respective .DMP file using the Microsoft (R) COFF/PE Dumper
rem 
for %%a in (*.obj) do dumpbin /all %%a > %%~na.dmp

rem 
rem disassemble and store .ELF executable its respective .DIS file using the GNU objdump from GNU binutils
rem 
wsl objdump -d program.elf > program_a.elf.dis
wsl objdump -s program.elf > program_d.elf.dis
rem 
rem disassemble and store .ELF executable its respective .DIS file using the GDB objdump from GNU binutils
rem 
wsl gdb program.elf < gdb.script > program_gdb.elf.dis
rem 
rem disassemble and store .EXE executable its respective .DIS file using the MSFT dumpbin
rem 
dumpbin /disasm program.exe > program_a.exe.dis
dumpbin /rawdata program.exe > program_d.exe.dis

rem 
rem disassemble to screen, anyway...
rem 
rem .ELF assembler/data
type program_a.elf.dis
type program_d.elf.dis
rem .EXE assembler/data
type program_a.exe.dis
type program_d.exe.dis
