@echo off

del *.obj *.exe *.elf *.map *.dis *.dmp
echo compiling for baremetal Linux...                           & cl /TC /DLINUXTARGET=1 /DUSEPRINTF4OUTPUT=0 /nologo /c /O1 /GS- /Ob0 /FoBareCode4Linux.obj /DBREAKORNOP=__debugbreak() main.c
echo compiling for baremetal Windows...                         & cl /TC /DLINUXTARGET=0 /DUSEPRINTF4OUTPUT=0 /nologo /c /O1 /GS- /Ob0 /FoBareCode4Windo.obj /DBREAKORNOP=__nop()        main.c
echo compiling and linking Windows console WinConsole.EXE ...   & cl /TC /DLINUXTARGET=0 /DUSEPRINTF4OUTPUT=1 /nologo    /O1 /GS- /Ob0 /FoWinConsole.obj     /DBREAKORNOP=__nop()        main.c

echo link baremetal Linux ^"program.elf^"
wsl ld --defsym=__ImageBase=0x400000   --output=program.elf -Map=program.elf.map --entry="main" BareCode4Linux.obj
echo link baremetal Windows ^"program.exe^"
link /nologo /subsystem:console /out:program.exe /map:program.exe.map  /entry:main  /LTCG:OFF BareCode4Windo.obj

rem
rem disassemble the BareCode*.OBJ to *.dis
rem
for %%a in (BareCode4*.obj) do dumpbin /disasm %%a > %%a.dis
rem
rem DUMP (/no disassemble) the BareCode*.OBJ to *.dmp
rem
for %%a in (BareCode4*.obj) do dumpbin /all %%a > %%a.dmp


rem 
rem disassemble and store .ELF executable its respective .DIS file using the GNU objdump from GNU binutils
rem 
wsl objdump -d -M intel program.elf > program_a.elf.dis
wsl objdump -s program.elf > program_d.elf.dis

rem 
rem disassemble and store programBinPatch.ELF executable its respective .DIS file using the GNU objdump from GNU binutils
rem 
wsl objdump -d -M intel programBinPatch.elf > programBinPatch_a.elf.dis
wsl objdump -s programBinPatch.elf > programBinPatch_d.elf.dis

rem 
rem disassemble and store .ELF executable its respective .DIS file using the GDB objdump from GNU binutils
rem 
	rem wsl gdb program.elf < gdb.script > program_gdb.elf.dis
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