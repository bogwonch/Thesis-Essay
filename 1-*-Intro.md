bytecode.  
# Introduction

In 2010 a team of researchers developed a generalized method for creating
platform independent programs (PIPs)[@Brumley2010]. A PIP is a special sort of
program which can be run on multiple different computer architectures without
modification[^1]. Unlike shell scripts or programs written for a portable
interpreter a PIP doesn’t require another program to run or compile it; rather
it runs as a native program on multiple architectures with potentially
different behaviour on each.

[^1]: For a more formal definition a PIP is a string of bytecode $b$ such that
for different machines $m_1$ and $m_2$, $b$ is a valid program if: $$m_1(b)
\not = \bot \wedge m_2(b) \not =\bot$$

To find a PIP you would have to analyze the architecture manuals for each
architecture you wanted and find the instructions in each which compiled to
identical patterns of bytecode and use them to construct your PIP. The approach
taken by the authors was to find small PIPs with a very specific form: do
nothing then jump[^2]. By ensuring each architecture jumped to a different
point and that each architecture didn’t accidentally run into a region anouther
architecture jumped into they could construct PIPs for any arbitrary program by
splitting them up into blocks of instructions specific to each architecture and
connecting them with the small PIPs.

[^2]: Consider the following example (taken from the original paper). The
dissassembly for the x86 architecture is shown above, and for the MIPS platform
bellow. $$\underbrace{\overbrace{90}^{\text{NOP}} \overbrace{eb20}^{\text{JMP}}
2a }_{\text{NOP}} \underbrace{90eb203a}_{\text{NOP}}
\underbrace{24770104}_{\text{B}}$$ The string is valid on both platforms and
has similar behaviour on both despite jumping to different locations. It is
a valid PIP for the x86 and MIPS platforms.

They go on to give in the paper a generalized algorithm for constructing these
PIPs, and say that they have a working implementation of it for creating PIPs
for the x86, ARM, and MIPS platforms, as well as the Windows, Mac, and Linux
operating systems.


## Aim of the Project

For this thesis I have implemented a small section of the PIP generation
algorithm—finding the *gadget headers*; the PIPs that link the specific code
sections together.  To generate the PIPs a list of *semantic
NOPS*[^whatsASemanticNop] and potential branch instructions has been found for
each architecture in the original paper and to extend the work of the original
paper I have analyzed two new platforms:  the Java Virtual Machine, and XMOS's
XS1.

[^whatsASemanticNop]: A semantic NOP is an instruction which has no effect, but
which might not necessarily be the *NOP* assembly instruction.  For example the
ARM instruction: `MOV r4, r4` Causes the contents of register four to be moved
into register four and as such is equivalent to an actual `NOP` instruction.
Equally the sequence of instructions: `PUSH r3` `POP r3` If equivalent to two
`NOP` instructions when taken as a whole and so is a *multi-instruction
semantic NOP*.

Unfortunately there does not seem to be a public database of these instructions
available for any architectures.  Semantic NOPs have been used in areas other
than creating PIPs, for example malware classification[@Bilar2007,@Preda2007],
but  there still appears to be no exhaustive list exists documenting them. Part
of the work required is to create one.


## Why is this interesting?

PIPs can be used for a variety of applications.  One potential application
suggested by Brumley et. al.[@Brumley2010] is for sneaking programs past
dynamic execution checkers.  Suppose two prisoners *Alice* & *Bob*, wish to
send a malicious program between themselves.  To send the message they have to
send it through a *Warden* who checks first that there communications don't
contain anything malicious and only delivers the message if its believed to be
harmless.

To sneak the program Alice and Bob use a form of
*keyed-steganography*[^pipsteg].  The program which they wish to communicate
becomes their *steg-text*, and they construct a *cover-text* by writing some
other program which doesn't contain anything malicious.   They either
pre-arrange a shared secret which is the platform that their programs should
really be run on: this forms the key.   With the cover-text and steg-text
created they create their message by generating them into a PIP where on one
platform (x86 say) it appears to run the innocuous program and on the secret
key platform (ARM for the sake of argument) it runs the program they really
wish to communicate.  Alice hands the warden the program and tells him that it
is for the innocuous architecture[^piparchs].  The warden runs the program and
sees it isn't something he would want to restrict and delivers it.  In fact
unless he is aware that it has been in constructed in this way he may not even
check any other architectures as for most platforms it will appear to be
garbage just like any normal executable.

[^pipsteg]: which the authors[@Brumley2010] call *execution-based
steganography*. 

[^piparchs]: if they were using ELF they wouldn't even need to do that—it's
part of the header in the file[@SysVElf].

Another application is *exfiltration protection*[^exfiltration].  Here the idea
is that to protect its software from theft a secret agency could make
a modification to an existing platform (the JVM or another virtual machine
would be a good choice here) and compile their program for this modified
platform. They then create another program for the unmodified platform which
does something else; maybe it phones home, maybe it destroys itself from the
computer it's running on.  They create a PIP out of these two programs and now
if the program is stolen and the exfiltrator isn't aware of the PIP nature (or
exactly what modifications were made to the architecture) they're not going to
be able to run the program they removed.

[^exfiltration]: Exfiltration is military term meaning the removal of
a resource from enemy control.  In the context of PIPs were talking about
taking programs from protected PCs; kind of like DRM.

Microcode offers another neat way to use PIPs.  Suppose an attacker manages to
compromise a system in such a way that they can alter the microcode of the
processor, such as the recent HP printer attack amongst
others[@PrintMe2011,@Scythale2007]. Now suppose that
as well as the microcode update they also modify an existing program[^modwhich]
so that on the compromised system it gives a backdoor or acts maliciously, but
on another (say one which is trying to forensically work out what is wrong with
the printer) it acts normally.  Brumley et. al. go on to point
out[@Brumley2010] that if this was done by Intel and the PIP was a preexisting
and digitally signed application then it is a particularly scary prospect.
Merely signing the program would be insufficient protect a user it would not
check if the machine it was executing on had been modified.

[^modwhich]: In the PIP paper[@Brumley2010] they suggest `ls`.

PIPs can also be included in shellcode and viruses.  For shellcode the idea is
that you can write it once and use it anywhere.  For viruses the idea is that
if you could get the virus on a disk that is mounted on multiple architectures
(say an NTFS share or USB key) then you can attack any platform you're plugged
into.

Another application for PIPs is to create actual platform independant programs.
The idea here is compile a program for multiple architectures and create a PIP
out of them.  You'd get a program that behaved the same but ran on multiple
architectures.  This could be useful, for example, if you have a network of
computers (some Linux x86 based, some ARM based) and you want to run a server
hosting all the programs to share between them you don't have to maintain
multiple versions.

The problem is that although PIPs could be used to write architecture
independant programs there are more elegant solutions available than relying on
the intersection of instruction sets between architectures.  There are a couple
of preexisting systems for doing this such as Apple's *Universal Binary* or the
*FatELF*[@FatELF] format.  Another problem is that for some operating systems
this just wouldn't work: Linux normally uses the ELF format[@SysVElf] which has
a flag in the header which specifies exactly what architecture the binary was
compiled for.  If it doesn't match the architecture of the machine it's being
run on the loader refuses to run it[^elfflag].

[^elfflag]: Of course there is nothing to stop you flipping the flag to some
other value with `elfedit` utility from the GNU Binutils.

Collberg et. al. in their paper *A Taxononmy of Obfuscating
Transformations*[@Collberg1997] describe different methods for hiding the
structure of a program.  They give many different transforms but three are of
particualar interest: adding dead code, adding redundant transforms, and
outlining[^outlining] sections of code. These three are of interest because
they describe what a PIP is doing, namely adding redundant `NOP`s and
transforms which don't alter the state of the program before jumping to the
actual code.

[^outlining]: Outlining is the opposite of inlining.  For inlining we take
a function call and replace it with the functions code inserted into the main
program verbatim.  For outlining we take a block of code inside a function and
make a function call out of it.  We might do inlining to skim a couple of jump
instructions from our program at the expense of a longer program; but outlining
(especially of sections only run once) just adds to the spaghetti nature of the
code.

Whilst adding the `NOP` instructions isn't a particularly
*resilient*[^resilient] transformation (a program could replace or remove them)
they are potent[^potent] especially if they're combined with multi-instruction
semantic NOPs where the state of the program does change only to be reversed
later.  The jumps added by the PIPs act to outline blocks of code.  If your
using just one PIP at the start of the program then it isn't that obfuscating
but in a situation where you're outlining every single instruction with a PIP
like structure and possibly embedding different behaviour if it is run on
a different architecture (such as Java or Thumb mode on an ARM chip) this has
the potential to be massively obfuscating.

[^resilient]: Resilience is a measure of how easy it is to de-obfuscate
a transform.  It is usually measured in terms of the time and space the
deobfuscator has to run.

[^potent]: Potency measures how confusing for a human the transform is. For
example self-modifying code is a very potent transform, but renaming the jump
targets isn't.

Interestingly papers, such as [@Christodorescu2005,@Christodorescu2005:2], even
describe obfuscation techniques where they unobfuscate the adding of semantic
NOPs using a novel (and patented [@Christodorescu2010]) tool called *Hammock*.
Hammock appears to be interesting because rather than using a catalogue of
pre-known semantic-nops it finds them by analyzing whether sequences of code
have any net effect on the state of the machine.  They find it to be a very
slow transform to de-obfuscate (implying adding NOPs is a potent obfuscation
technique) but the removal is quick once they have been found.

Semantic-nops are another interesting aspect of the PIP problem.  Semantic-nops
are important for PIPs as they give you multiple ways of doing nothing—so there
is a greater chance of finding an overlap between different architectures but
they turn up in other places too.  Many people [@Christodorescu2005,
@Owens2011, @Bruschi2007,] have suggested using semantic-nops as an obfuscating
technique.  Wartell et al suggest using them as part of a heuristic for
diffenentiating between code and data for disassembled programs[@Wartell2011].
The GNU Assembler has a short list of efficient, low power semantic-nop[^gas_nops]
instructions it uses to pad instruction sequences to
cache-lines[@GAS:i386aligncode].

[^gas_nops]: A comment above the function[@GAS:i386aligncode] notes that most
of the instructions used as part of the semantic-nop sequences by the assembler
arn't infact assemblable with the assembler.


## What is the Challenge?

The original PIP paper[@Brumley2010] contains an anecdote where the effort
required to create platform independant programs is described as requiring:

> "a large, flat space to spread out the architecture reference manuals, and an
> ample supply of caffeine.  Do not underrate the second part.

Brumley et al go on to note that:

> even the most caffeinated approaches have only been met with limited success;

For this thesis we're not trying to fully generate platform independant
programs; rather we're just trying to find the headers that enable them.  To do
this we need two things:  a list of semantic-nop and jump instructions for each
architecture we're interested in, and a method for combining them to form the
headers.

Finding the semantic-nops and jump instructions in theory is quite easy.  You
can go through the architecture manual making notes of the all the
instructructions which you're interested in (checking that they don't alter the
state of the processor in any surprising way) before assembling them to get the
bytecode.  



## Summary

For this project I aim to: 

  * Study the architectures for a variety of platforms (including x86, AARCH32,
    XS1, and the JVM) with a view to finding semantic-nops.
  * Create a database of semantic-nop instructions that is publicly available.
  * Use constraint-programming techniques to create an algorithm for finding 
    PIP headers for various architectures.
  * Produce a database of Platform Independant Program headers.  

