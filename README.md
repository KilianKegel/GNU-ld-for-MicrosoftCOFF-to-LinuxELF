# GNU-ld-for-MicrosoftCOFF-To-LinuxELF

* [History](https://github.com/KilianKegel/GNU-ld-for-MicrosoftCOFF-to-LinuxELF#history)

# Introduction

While implementing support for LINUX x86_64 to the 
[**Torito C Library**](https://github.com/KilianKegel/torito-C-Library#torito-c-library) 
it turned out, that the **GNU** linker **ld** doesn't sufficiently understand the Microsoft COFF file format for .OBJ modules.

All .LIB and .OBJ modules created with the latest version of Visual Studio 2019 VS2019
are taken and processed by **GNU ld** (`GNU ld (GNU Binutils for Ubuntu) 2.34`) without any complaint, 
but the created .ELF image does not run at all, for many of the same reasons metioned below.

During my comprehensive exploration I found that
* placement of uninitialized data (global variables not explicitly set to 0) in .BSS section
  creates accesses to faulty addresses for data
* modules translated without the compiler switches `/Gw` and `/Gy`
    * `/Gw[-]` separate global variables for linker
    * `/Gy[-]` separate functions for linker
  creates accesses to faulty addresses for data and code
* modules translated with code optimization enabled creates accesses to faulty addresses for data


### Build Environment

* Windows 10 64
* VS2019 
* Windows Subystem Linux (WSL2) running a Ubuntu 20.04 image

The build platform was installed following this recipe:
https://github.com/KilianKegel/HowTo-setup-an-UEFI-Development-PC#howto-setup-an-uefi-development-pc
But only step (1), (2) and (16) are truly required.

### Build Target
Build target is .ELF x86_64 only.

To rebuild all the binaries, disassemblies and .OBJ file infos just invoke `m.bat` in each folder.

# ```__ImageBase``` bugs

There were two (2) bugs found related to the Microsoft ```__ImageBase``` addressing model.

With optimization setting enabled (```/O1```, ```/O2```) the code generator
of the Microsoft C compiler *may use* the ```__ImageBase``` relative addressing method,
if special program characteristics were met.

1. [```ADDR32NB``` INITIALIZATION W/ ```__ImageBase```](https://github.com/KilianKegel/GNU-ld-for-MicrosoftCOFF-to-LinuxELF/tree/buildupBUGImageBase#addr32nb-initialization-w-__imagebase)
2. [```ADDR32NB``` OFFSET MISCALCULATION](https://github.com/KilianKegel/GNU-ld-for-MicrosoftCOFF-to-LinuxELF/tree/buildupBUGImageBase#addr32nb-offset-miscalculation)

### General description

In the **Optimization Manual** ([Optimizing subroutines in assembly language](https://www.agner.org/optimize/))
Agner Fog describes that Microsoft-specific addressing method: https://www.agner.org/optimize/optimizing_assembly.pdf#page=23

The Microsoft Linker LINK.EXE injects the symbol ```__ImageBase``` at link time if required.
In the sample below the RVA (relative virtual address) of 0x140000000 is assigned to ```__ImageBase```.

![file ldBugImageBase\PNG\map.png not found](ldBugImageBase/PNG/map.png)

At program runtime ```__ImageBase``` points to the [`MZ-EXE-Header`](ldBugImageBase/PNG/ProcMemDumpWindows.txt).\
(NOTE: Due to [Address space layout randomization -- ASLR](https://en.wikipedia.org/wiki/Address_space_layout_randomization)
the runtime ```__ImageBase``` is relocated to a different address as assigned at link time.)

The references to image-relative addressed symbols 
that could be observed, use a ```[base + index*scale + disp]``` style indexed register-indirect addressing method descriped
here: https://www.amd.com/system/files/TechDocs/24592.pdf#page=50

The compiler uses the relocation type ```IMAGE_REL_AMD64_ADDR32NB```
([`The Common Language Infrastructure Annotated Standard`](https://books.google.de/books?id=50PhgS8vjhwC&pg=PA755&lpg=PA755&dq=REL32+ADDR32NB&source=bl&ots=v0Fv0kz3pR&sig=ACfU3U3WLFskN3kb94ktZ7ZnomEPHMf-pg&hl=en&sa=X&ved=2ahUKEwibycnIsd7uAhUDolwKHTslAaEQ6AEwB3oECAwQAg#v=onepage&q=REL32%20ADDR32NB&f=false),
http://www.m4b.io/goblin/goblin/pe/relocation/constant.IMAGE_REL_AMD64_ADDR32NB.html).
in the .OBJ module:

![file ldBugImageBase\PNG\DumpbinAllADDR32NB.png not found](ldBugImageBase/PNG/DumpbinAllADDR32NB.png)
[complete listing](ldBugImageBase/BareCode4Windo.obj.dmp#L130)

### Listings
[Sourcecode of the demonstration program](ldBugImageBase/main.c)\
[Disassembly of the .EXE executable](ldBugImageBase/program_a.exe.dis)\
[Disassembly of the .ELF executable](ldBugImageBase/program_a.elf.dis)\
[Section dump of the .EXE executable](ldBugImageBase/program_d.exe.dis)\
[Section dump of the .ELF executable](ldBugImageBase/program_d.elf.dis)\
[Disassembly of the binPatched .ELF executable](ldBugImageBase/programBinPatch_a.elf.dis)

## ```ADDR32NB``` INITIALIZATION W/ ```__ImageBase```

Erroneous image base inclusion into ```ADDR32NB``` offset relocation.

This source code implements the test scenario: [`main.c`](ldBugImageBase/main.c)\
The program copies into a predefined string "1234" at centerposition the string "AB". "AB" and its length
were accessed through arrays using indices. Doing so the Microsoft C compiler generates ```__ImageBase``` memory accesses.

[The complete source code of the C file can be found here](ldBugImageBase/main.c)

Stepping through the program in the windows debuggger makes more clear, what the program is expected to
do on machine level -- and what's going wrong in Linux:
```
00007FF6576C1000  mov         qword ptr [rsp+8],rbx  
00007FF6576C1005  mov         qword ptr [rsp+10h],rbp  
00007FF6576C100A  mov         qword ptr [rsp+20h],rsi  
00007FF6576C100F  push        rdi  
00007FF6576C1010  sub         rsp,20h  

--> BREAKORNOP
00007FF6576C1014  nop

--> while (1 == deadloopvar);
00007FF6576C1015  mov         eax,dword ptr [7FF6576C3000h]
00007FF6576C101B  cmp         eax,1
00007FF6576C101E  je          00007FF6576C1015

-->  tsc = __rdtsc();
00007FF6576C1020  rdtsc

--> if (tsc/*TSC is never, never 0*/)
00007FF6576C1022  shl         rdx,20h
00007FF6576C1026  or          rax,rdx  
00007FF6576C1029  je          00007FF6576C1088  

00007FF6576C102B  xor         edi,edi  
    
--> load __ImageBase to EBP
00007FF6576C102D  lea         rbp,[7FF6576C0000h]

--> MZ-EXE header at Windows runtime
    0x00007FF6576C0000  4d 5a 90 00 03 00 00 00 04 00 00 00 ff ff 00 00  MZ..........ÿÿ..       
    0x00007FF6576C0010  b8 00 00 00 00 00 00 00 40 00 00 00 00 00 00 00  ¸.......@.......
    0x00007FF6576C0020  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
    0x00007FF6576C0030  00 00 00 00 00 00 00 00 00 00 00 00 b8 00 00 00  ............¸...
    0x00007FF6576C0040  0e 1f ba 0e 00 b4 09 cd 21 b8 01 4c cd 21 54 68  ..º..´.Í!¸.LÍ!Th
    0x00007FF6576C0050  69 73 20 70 72 6f 67 72 61 6d 20 63 61 6e 6e 6f  is program canno
    0x00007FF6576C0060  74 20 62 65 20 72 75 6e 20 69 6e 20 44 4f 53 20  t be run in DOS 
    0x00007FF6576C0070  6d 6f 64 65 2e 0d 0d 0a 24 00 00 00 00 00 00 00  mode....$.......

00007FF6576C1034  xor         ebx,ebx  

--> load address of buffer
00007FF6576C1036  lea         rsi,[7FF6576C3004h]

    0x00007FF6576C3004  31 32 33 34 00 00 00 00 00 00 00 00 03 00 00 00  1234............
    0x00007FF6576C3014  00 00 00 00 00 20 6c 57 f6 7f 00 00 00 00 00 00  ..... lWö.......
    0x00007FF6576C3024  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
    0x00007FF6576C3034  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
    0x00007FF6576C3044  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
    0x00007FF6576C3054  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
    0x00007FF6576C3064  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
    0x00007FF6576C3074  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................

--> load address of STRING0 in stringTable
00007FF6576C103D  mov         rcx,qword ptr [rbx+rbp+3018h]

    RBX	0000000000000000    Index 0
    RBP	00007FF6576C0000	__ImageBase

    rbx+rbp+3018h
    
    stringTable:
    0x00007FF6576C3018  00007ff6576C2000 0000000000000000  . .Øö...........
    0x00007FF6576C3028  0000000000000000 0000000000000000  ................
    0x00007FF6576C3038  0000000000000000 0000000000000000  ................
    0x00007FF6576C3048  0000000000000000 0000000000000000  ................
    0x00007FF6576C3058  0000000000000000 0000000000000000  ................
    0x00007FF6576C3068  0000000000000000 0000000000000000  ................
    0x00007FF6576C3078  0000000000000000 0000000000000000  ................


    RCX 00007FF6576C2000	

    STRING0:
    0x00007FF6576C2000  41 42 00 00 00 00 00 00 f4 63 23 60 00 00 00 00  AB......ôc#`....
    0x00007FF6576C2010  0d 00 00 00 70 00 00 00 20 20 00 00 20 06 00 00  ....p...  .. ...
    0x00007FF6576C2020  00 00 00 00 00 10 00 00 cf 00 00 00 2e 74 65 78  ........Ï....tex
    0x00007FF6576C2030  74 24 6d 6e 00 00 00 00 00 20 00 00 20 00 00 00  t$mn..... .. ...
    0x00007FF6576C2040  2e 72 64 61 74 61 00 00 20 20 00 00 70 00 00 00  .rdata..  ..p...
    0x00007FF6576C2050  2e 72 64 61 74 61 24 7a 7a 7a 64 62 67 00 00 00  .rdata$zzzdbg...
    0x00007FF6576C2060  90 20 00 00 1c 00 00 00 2e 78 64 61 74 61 00 00  . .......xdata..
    0x00007FF6576C2070  00 30 00 00 20 00 00 00 2e 64 61 74 61 00 00 00  .0.. ....data...

00007FF6576C1045  mov         r8b,byte ptr [rcx]  
00007FF6576C1048  test        r8b,r8b  
00007FF6576C104B  je          00007FF6576C1075  
00007FF6576C104D  mov         eax,5  

--> load sizeof(STRING0) from sizeTable
00007FF6576C1052  sub         eax,dword ptr [rbx+rbp+3010h]

    [rbx+rbp+3010h] 00007FF6576C3010
    0x00007FF6576C3010  03 00 00 00 00 00 00 00 00 20 6c 57 f6 7f 00 00  ......... lWö...
    0x00007FF6576C3020  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
    0x00007FF6576C3030  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
    0x00007FF6576C3040  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
    0x00007FF6576C3050  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
    0x00007FF6576C3060  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
    0x00007FF6576C3070  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................

00007FF6576C1059  cdq  
00007FF6576C105A  sub         eax,edx  
00007FF6576C105C  sar         eax,1  
00007FF6576C105E  movsxd      rdx,eax  
00007FF6576C1061  add         rdx,rsi  
00007FF6576C1064  inc         rcx  

--> write "AB" to buffer "1234" @ "23"
00007FF6576C1067  mov         byte ptr [rdx],r8b

    0x00007FF6576C3004  31 41 33 34 00 00 00 00 00 00 00 00 03 00 00 00  1A34............ 
    0x00007FF6576C3014  00 00 00 00 00 20 6c 57 f6 7f 00 00 00 00 00 00  ..... lWö.......
    0x00007FF6576C3024  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
    0x00007FF6576C3034  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
    0x00007FF6576C3044  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
    0x00007FF6576C3054  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
    0x00007FF6576C3064  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
    0x00007FF6576C3074  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
  
        .
        .
        .

00007FF6576C10CE  ret
```
[complete listing](ldBugImageBase/PNG/TipoeThroughWindows.txt)
## Linking for Linux

As already said above, the Microsoft compiler and linker uses the symbol ```__ImageBase```
for the adressing scheme, that the linker artificially injects at link time.

The **GNU ld** needs ```__ImageBase``` to get  assigned as a command line parameter:
```
--defsym=__ImageBase=0x400000
```

0x400000 is the load address and is equal to ```__executable_start``` from
the default **GNU ld** link script https://github.com/KilianKegel/torito-LINK/blob/main/main.c#L1339.

### **Microsoft LINK.EXE** vs. **GNU ld**

**Microsoft LINK.EXE** initialized ```IMAGE_REL_AMD64_ADDR32NB``` relocations as those
were a *displacement* to ```__ImageStart```, while the base register is previously initialized
with ```__ImageStart```.
```
        .
        .
        .
    mov rcx,qword ptr [rbx+rbp+3018h]       ; RBP == __ImageBase, RBX == 0 -> index 0
        .                                   ; 0x3018 displacement of STRING0 in stringTable
        .
    sub eax,dword ptr [rbx+rbp+3010h]
        .
        .
        .
```
**GNU ld** initialized ```IMAGE_REL_AMD64_ADDR32NB``` relocations as those
were a *complete 32 bit address*. The base register (here ```RBP```) is assumed to be initialized previously to ZERO.
```
        .
        .
        .
    mov rcx,qword ptr [rbx+rbp+403068h]     ; RBP == 0, RBX == 0 -> index 0
        .                                   ; 0x403068 load address of STRING0 in stringTable in Linux
        .
    sub eax,dword ptr [rbx+rbp+403058h]
        .
        .
        .
```
![file ldBugImageBase\PNG\DiffELFEXE.png not found](ldBugImageBase/PNG/DiffELFEXE.png)\
[complete diff view](ldBugImageBase/PNG/DiffELFEXE.pdf)\
[complete .ELF disassembly](ldBugImageBase/program_a.elf.dis)\
[complete .EXE disassembly](ldBugImageBase/program_a.exe.dis)

Doing so **GNU ld**-linked programs could only run in the lower half 32Bit address space,
and ```__ImageBase```has to be initialized to zero.\
Instead **Microsoft LINK.EXE**-linked programs can run in the entire 64Bit address space.

The entire issue in one image:
![file ldBugImageBase/PNG/DumpbinAllADDR32NBDiffELFEXEbw.png not found](ldBugImageBase/PNG/DumpbinAllADDR32NBDiffELFEXEbw.png)

## ```ADDR32NB``` offset miscalculation
Beside the erroneous image base inclusion into ```ADDR32NB``` offset relocation,
the ```ADDR32NB``` offset calculation itself is wrong:
![file ldBugImageBase\PNG\DiffELFPatch.png not found](ldBugImageBase/PNG/DiffELFPatch.png)

### Explanation
The [```.data```](ldBugImageBase/program_d.elf.dis#L26)/[```.data```](ldBugImageBase/program_d.exe.dis#L37) contains
four (4) data objects from the sample program mentioned above :
[test](buildupBUGImageBase#listings)

1.  ```deadloopvar``` at offset 0
    [see listing](ldBugImageBase/program_a.elf.dis#L14)

2.  ```buffer``` at offset 4
    [see listing](ldBugImageBase/program_a.elf.dis#L24)

3.  ```sizeTable``` at offset 0x10
    [see listing](ldBugImageBase/program_a.elf.dis#L31)

4.  ```stringTable``` at offset 0x18
    [see listing](ldBugImageBase/program_a.elf.dis#L25)

 
The [**GNU ld** ```.data```](program_d.elf.dis#L26)/[```RAW DATA #3```] section 
# STATIC ADDRESS ASSIGNMENT bug
## THIS BUG IS SOLVED WITH BINUTILS 2.36 FROM 2021-01-24

Statically assigned addresses are assigned wrongly.
This is true for *initialized* variables in the .DATA sections and
for *non-initialized* variables in the .BSS sections.

All .MAP .OBJ and .DIS (disassembler) were stored [here](https://github.com/KilianKegel/GNU-ld-for-MicrosoftCOFF-to-LinuxELF/tree/master/ldBugStaticAddressAssignment)

From the the source code below the ``` if()``` condition should never reach
the ```__debugbreak()```.

[`main.c`](https://github.com/KilianKegel/GNU-ld-for-MicrosoftCOFF-to-LinuxELF/blob/master/ldBugStaticAddressAssignment/main.c)
```c
//main.c

typedef struct _SAMPLESTRUCT
{
    char* pinitializedVar;      // pointer to "initialized variable" in .DATA
    char* pnon_initialVar;      // pointer to "non-initialized variable" in .BSS

}SAMPLESTRUCT;

SAMPLESTRUCT Struct;            // prototype of structure

//
// initialized variables
//
char initdummy = 0xAA;          // this is begin of .DATA
char initializedVar  = 0x55;    // at &initdummy + 1 (sizeof(char))
//
// non-initialized variables
//
char non_initdummy;             // this is begin of .BSS
char non_initialVar;            // at &non_initdummy + 1 (sizeof(char))

void begin(void)
{
    //static volatile int i = 0x99;         // dead loop for Windows version
    //while (0x99 == i)
    //    ;

    __debugbreak();             // break for GDB for initial break after RUN command
    if (&initializedVar != Struct.pinitializedVar)
        __debugbreak();         // should never reach this INT3/TRAP

    if (&non_initialVar != Struct.pnon_initialVar)
        __debugbreak();         // should never reach this INT3/TRAP
    
    outp(0x80, 0x12);
}

SAMPLESTRUCT Struct =           // instance  of structure
{
    &initializedVar,
    &non_initialVar
};
```

But in the LD-linked .ELF version the structure elements were assigned with faulty addresses
and the programm runs in the INT3/TRAP in the ``` if()``` condition :

![file ldBugStaticalAddressAssignmentLDError.png not found](ldBugStaticalAddressAssignmentLDError.png)

Instead in the LINK.EXE-linked .EXE version the structure elements were assigned correctly :

![file ldBugStaticalAddressAssignmentLINKEXEOkay.png not found](ldBugStaticalAddressAssignmentLINKEXEOkay.png)

# .BSS bug
## THIS BUG IS SOLVED WITH BINUTILS 2.36 FROM 2021-01-24
The .BSS bug is, that non-initialized global variables
were accessed through a wrong address, when linked with **ld** to an .ELF image.

![file bssbug.png not found](bssbug.png)

Both, `getaddr1()` and `getaddr2()` just return the address of **`var`**, that
is set to 0x403014 by the linker **ld**. But on the left side in folder **`ldBugDemo0`**
`getaddr1()` uses 0x403013 instead. This only happens, if **`var`** is a *"Common symbol"*,
that means it is defined and *not initialized (to 0)* in the same .C file:

```c
    //getaddr1.c
    char var;           // in ldBugDemo0
```

Instead, if **`var`** is initialized to 0 (it is also placed in .BSS) or defined outside
in `var.c` also `getaddr1()` gets the right address 0f 0x403014.

![file bssbugMAP.png not found](bssbugMAP.png)

**Checking the .DMP file makes me believe, that the 8-digit number describes the size of the
variable, but is accidentally subtracted from the real address.**

![file bssbugDMP.png not found](bssbugDMP.png)

### Demonstration of the .BSS bug
The test is composed of a few .C files only. 
The only thing that is modified to demonstrate
the .BSS bug is the declaration/definition/initialization of **`var`**
int the different directories: 
[**`ldBugDemo0`**](https://github.com/KilianKegel/GNU-ld-for-MicrosoftCOFF-to-LinuxELF/tree/master/ldBugDemo0), 
[**`ldBugDemo1`**](https://github.com/KilianKegel/GNU-ld-for-MicrosoftCOFF-to-LinuxELF/tree/master/ldBugDemo1) and 
[**ldBugDemo2``**](https://github.com/KilianKegel/GNU-ld-for-MicrosoftCOFF-to-LinuxELF/tree/master/ldBugDemo2).

1. [`main.c`](https://github.com/KilianKegel/GNU-ld-for-MicrosoftCOFF-to-LinuxELF/blob/master/ldBugDemo0/main.c) for ldBugDemo0, ldBugDemo1 and ldBugDemo2 always the same

```c
    //main.c
    extern void* getaddr1(void);
    extern void* getaddr2(void);

    void begin(void) 
    {
        getaddr1();
        getaddr2();
    }
```

2. ldBugDemo0/[`getaddr1.c`](https://github.com/KilianKegel/GNU-ld-for-MicrosoftCOFF-to-LinuxELF/blob/master/ldBugDemo0/getaddr1.c), 
ldBugDemo1/[`getaddr1.c`](https://github.com/KilianKegel/GNU-ld-for-MicrosoftCOFF-to-LinuxELF/blob/master/ldBugDemo1/getaddr1.c), 
ldBugDemo2/[`getaddr1.c`](https://github.com/KilianKegel/GNU-ld-for-MicrosoftCOFF-to-LinuxELF/blob/master/ldBugDemo2/getaddr1.c), modified 
declaration/definition/initialization of **`var`** for ldBugDemo0, ldBugDemo1 and ldBugDemo2

```c
    //getaddr1.c
    char var;           // in ldBugDemo0
    char var = 0;       // in ldBugDemo1
    extern char var;    // in ldBugDemo2
    void* getaddr1(void)
    {
        return &var;
    }
```

3. [`getaddr2.c`](https://github.com/KilianKegel/GNU-ld-for-MicrosoftCOFF-to-LinuxELF/blob/master/ldBugDemo0/getaddr2.c) for ldBugDemo0, ldBugDemo1 and ldBugDemo2 always the same

```c
    //getaddr2.c
    extern char var;

    void* getaddr2(void)
    {
        return &var;
    }
```
4. [`var.c`](https://github.com/KilianKegel/GNU-ld-for-MicrosoftCOFF-to-LinuxELF/blob/master/ldBugDemo2/var.c) for ldBugDemo2 only

```c
    //var.c
    char  var;
```

# OPTIMIZATION bug
## THIS BUG IS SOLVED WITH BINUTILS 2.36 FROM 2021-01-24
The optimization bug was seen when accessing structures. 
In this specific occurence it appears with compiler optimization enabled
and it disappears with optimization disabled, Microsoft C compiler switch `/Od`.

### Demonstration of the OPTIMIZATION bug
The structure `Struct[0]` is initialized wrongly by optimized code in `opti_O1.c`
and it is initialized correctly with code optimization disabled in `opti_Od.c`.

1. [`main.c`](https://github.com/KilianKegel/GNU-ld-for-MicrosoftCOFF-to-LinuxELF/blob/master/ldBugStruct0/main.c)

```c
    //main.c
    #include "struct.h"

    extern SAMPLESTRUCT Struct[2];
    extern int opti_Od(void);
    extern int opti_O1(void);

    void begin(void)
    {
        opti_Od();
        opti_O1();
    }
```
2. [`opti_O1.c`](https://github.com/KilianKegel/GNU-ld-for-MicrosoftCOFF-to-LinuxELF/blob/master/ldBugStruct0/opti_O1.c)

```c
    //opti_O1.c
    #include "struct.h"

    extern SAMPLESTRUCT Struct[2];

    int opti_O1(void** rsp)
    {

        Struct[0].c = 0x12;
        Struct[0].s = 0x2233;
        Struct[0].i = 0x44445555;
        Struct[0].ll = 0x8888888899999999;

        return -1;
    }
```
3. [`opti_Od.c`](https://github.com/KilianKegel/GNU-ld-for-MicrosoftCOFF-to-LinuxELF/blob/master/ldBugStruct0/opti_Od.c)

```c
    //opti_O1.c
    #include "struct.h"

    extern SAMPLESTRUCT Struct[2];

    int opti_Od(void** rsp)
    {

        Struct[0].c = 0x11;
        Struct[0].s = 0x2222;
        Struct[0].i = 0x44444444;
        Struct[0].ll = 0x8888888888888888;

        return -1;
    }
```

3. [`struct.c`](https://github.com/KilianKegel/GNU-ld-for-MicrosoftCOFF-to-LinuxELF/blob/master/ldBugStruct0/struct.c)

```c
        //struct.c
        #include "struct.h"

        SAMPLESTRUCT Struct[2] = { 1 /* force to .DATA, prevent .BSS placement*/};
```

4. [`struct.h`](https://github.com/KilianKegel/GNU-ld-for-MicrosoftCOFF-to-LinuxELF/blob/master/ldBugStruct0/struct.h)

```c
    //struct.h
    typedef struct _SAMPLESTRUCT
    {
        char c;
        short s;
        int i;
        long long ll;
    }SAMPLESTRUCT;
```

To ease demonstration there are extra comments added to the original 
[disassembly](https://github.com/KilianKegel/GNU-ld-for-MicrosoftCOFF-to-LinuxELF/blob/master/ldBugStruct0/program.elf.dis)
 of the .ELF file below:

```as

program.elf:     file format elf64-x86-64


Disassembly of section .text$mn:

0000000000401000 <begin>:
  401000:   48 83 ec 28             sub    $0x28,%rsp
  401004:   48 c7 05 25 20 00 00    movq   $0x1,0x2025(%rip)        # 403034 <Struct+0x1c>
  40100b:   01 00 00 00
  40100f:   e8 4c 00 00 00          callq  401060 <opti_Od>
  401014:   e8 07 00 00 00          callq  401020 <opti_O1>
  401019:   48 83 c4 28             add    $0x28,%rsp
  40101d:   c3                      retq   
  40101e:   66 90                   xchg   %ax,%ax

0000000000401020 <opti_O1>:
  401020:   b8 33 22 00 00          mov    $0x2233,%eax
  401025:   c6 05 ed 1f 00 00 12    movb   $0x12,0x1fed(%rip)       # 403019 <Struct+0x1>
                                                                    # Struct[0].c = 0x12; opti_O1.c(9)
                                                                    # byte write 0x12 -> 0x403019 ERRONEOUS ADDRESS!!!
  40102c:   66 89 05 e7 1f 00 00    mov    %ax,0x1fe7(%rip)        .# 40301a <Struct+0x2>
                                                                    # Struct[0].s = 0x2233; opti_O1.c(10)
                                                                    # word write 0x2233 -> 0x40301A CORRECT ADDRESS
  401033:   48 b8 99 99 99 99 88    movabs $0x8888888899999999,%rax
  40103a:   88 88 88 
  40103d:   48 89 05 dc 1f 00 00    mov    %rax,0x1fdc(%rip)        # 403020 <Struct+0x8>
                                                                    # Struct[0].ll = 0x8888888899999999; opti_O1.c(12)
                                                                    # qword write 0x8888888899999999 -> 0x403020 CORRECT ADDRESS
  401044:   83 c8 ff                or     $0xffffffff,%eax
  401047:   c7 05 cf 1f 00 00 55    movl   $0x44445555,0x1fcf(%rip) # 403020 <Struct+0x8>
  40104e:   55 44 44                                                # Struct[0].i = 0x44445555;     opti_Od.c(11)
                                                                    # dword write 0x44445555 -> 0x403020 ERRONEOUS ADDRESS!!!
  401051:   c3                      retq   
  401052:   66 2e 0f 1f 84 00 00    nopw   %cs:0x0(%rax,%rax,1)
  401059:   00 00 00 
  40105c:   0f 1f 40 00             nopl   0x0(%rax)

0000000000401060 <opti_Od>:
  401060:   48 89 4c 24 08          mov    %rcx,0x8(%rsp)
  401065:   b8 10 00 00 00          mov    $0x10,%eax
  40106a:   48 6b c0 00             imul   $0x0,%rax,%rax
  40106e:   48 8d 0d a3 1f 00 00    lea    0x1fa3(%rip),%rcx        # 403018 <Struct>
  401075:   c6 04 01 11             movb   $0x11,(%rcx,%rax,1)      # Struct[0].c = 0x11;   opti_Od.c(9)
                                                                    # byte write 0x11 -> 0x403018
  401079:   b8 10 00 00 00          mov    $0x10,%eax
  40107e:   48 6b c0 00             imul   $0x0,%rax,%rax
  401082:   48 8d 0d 8f 1f 00 00    lea    0x1f8f(%rip),%rcx        # 403018 <Struct>
  401089:   ba 22 22 00 00          mov    $0x2222,%edx
  40108e:   66 89 54 01 02          mov    %dx,0x2(%rcx,%rax,1)     # Struct[0].s = 0x2222; opti_Od.c(10)
                                                                    # word write 0x2222 -> 0x40301A
  401093:   b8 10 00 00 00          mov    $0x10,%eax
  401098:   48 6b c0 00             imul   $0x0,%rax,%rax
  40109c:   48 8d 0d 75 1f 00 00    lea    0x1f75(%rip),%rcx        # 403018 <Struct>
  4010a3:   c7 44 01 04 44 44 44    movl   $0x44444444,0x4(%rcx,%rax,1)# Struct[0].i = 0x44444444;      opti_Od.c(11)
  4010aa:   44 
                                                                    # dword write 0x44444444 -> 0x40301C
  4010ab:   b8 10 00 00 00          mov    $0x10,%eax
  4010b0:   48 6b c0 00             imul   $0x0,%rax,%rax
  4010b4:   48 8d 0d 5d 1f 00 00    lea    0x1f5d(%rip),%rcx        # 403018 <Struct>
  4010bb:   48 ba 88 88 88 88 88    movabs $0x8888888888888888,%rdx
  4010c2:   88 88 88 
  4010c5:   48 89 54 01 08          mov    %rdx,0x8(%rcx,%rax,1)    # Struct[0].ll = 0x8888888888888888; opti_Od.c(12)
                                                                    # qword write 0x8888888888888888 -> 0x403020
  4010ca:   b8 ff ff ff ff          mov    $0xffffffff,%eax
  4010cf:   c3                      retq   
```

[Comparing](optimizationDMP.html) the .OBJ modules of [`opti_O1.c`](https://github.com/KilianKegel/GNU-ld-for-MicrosoftCOFF-to-LinuxELF/blob/master/ldBugStruct0/opti_O1.c)
and [`opti_Od.c`](https://github.com/KilianKegel/GNU-ld-for-MicrosoftCOFF-to-LinuxELF/blob/master/ldBugStruct0/opti_Od.c)
makes me believe, that there is something wrong in the RELOCATION section regarding REL32, REL32_1 and REL32_4. Maybe 
relocation types are not yet implemented.

![file optimizationDMP.png not found](optimizationDMP.png)


## History
### 20210131
* new bug: *__ImageBase not injected*
### 20210112
* issues officially solved by H.J. Lu (hongjiu.lu@intel.com)
* https://sourceware.org/bugzilla/show_bug.cgi?id=27171
### 20210110
* new bug: *static address assignment bug*
### 20201018
* inital version of https://github.com/KilianKegel/torito-LINK
### 20200916 
* issues officially solved by H.J. Lu (hongjiu.lu@intel.com)
* https://sourceware.org/bugzilla/show_bug.cgi?id=26583
### 20200915
* fix implemented https://github.com/KilianKegel/binutils-for-Torito-C-Library into
  current *binutils 2.35* 
### 20200908 
* issues reported at https://sourceware.org/bugzilla and accepted by H.J. Lu (hongjiu.lu@intel.com)
 

