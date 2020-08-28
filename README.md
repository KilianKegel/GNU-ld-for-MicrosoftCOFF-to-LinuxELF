# GNU-ld-for-MicrosoftCOFF-To-LinuxELF

# Introduction

While implementing support for LINUX x86_64 to the 
[**Torito C Library**](https://github.com/KilianKegel/torito-C-Library#torito-c-library) 
it turned out, that the **GNU** linker **ld** doesn't sufficiently understand the Microsoft COFF file format for .OBJ modules.

All .LIB and .OBJ modules created with the latest version of Visual Studio 2019 VS2019
are taken and processed by **GNU ld** (`GNU ld (GNU Binutils for Ubuntu) 2.34`) without any complaint, 
but the created .ELF image does not run at all, for many of the same reasons.

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
But only step (1), (2) and (15) are truly required.

### Build Target
Build target is .ELF x86_64 only.

To rebuild all the binaries, disassemblies and .OBJ file infos just invoke `m.bat` in each folder.

# .BSS bug
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
