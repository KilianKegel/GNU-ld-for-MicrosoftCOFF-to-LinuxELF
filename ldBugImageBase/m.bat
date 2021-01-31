@echo off
cl /Zi /nologo /c /O1 *.c
dumpbin /nologo /disasm ibase0.obj > ibase0.dis
dumpbin /nologo /all ibase0.obj > ibase0.dmp
dumpbin /nologo /disasm ibase1.obj > ibase1.dis
dumpbin /nologo /all ibase1.obj > ibase1.dmp
link /nologo /entry:begin /out:program.exe /map:program.exe.map *.obj /subsystem:console /LTCG:OFF 