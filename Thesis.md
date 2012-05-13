% Platform Independent Programs
% Joseph Hallett\thanks{With thanks to Dr. Daniel Page for supervising the project and to Will Williams and Jake Longo for listening to me rant about PIPs and bytecode all year.}
% \today


Executive Summary
=================

*Platform Independent Programs* (PIPs) are a new type of program whose bytecode can be run on multiple architectures without modification.  It works by exploiting overlaps in machine code formats between architectures to create small sequences of code called PIP headers that jump to different places depending on which architecture runs them.  By chaining the PIP headers with jumps to platform specific code you can construct whole programs that run on multiple architectures.  

I created a database of semantic NOP instructions for the ARM, MIPS, X86 and XS1 architectures and used it to find PIP headers for the ARM, MIPS and X86 platforms and to show the technique is also possible on XS1.  I looked at the steganographic properties of PIPs and the occurrences of PIP headers in non PIP programs.  I determined that using repeated PIP headers would lead to a PIP that was easily distinguished from a non PIP by statistical methods.  I suggested other methods to create PIPs that couldn't be detected by a signature based scheme by using metamorphism, encryption, and microcode updates.  I created an example shellcode using a PIP header that highlighted the need for some form of static analysis to be introduced to the PIP header generation routine to fully utilize PIPs.



Introduction
============

Constructing PIPs
-----------------

In 2010 a team of researchers developed a generalised method for creating Platform Independent Programs (PIPs)[@Cha:2010uh]. A PIP is a special sort of program which can be run on multiple different computer architectures without modification. Unlike shell scripts or programs written for a portable interpreter; a PIP does not require another program to run or compile it; rather it runs as a native program on multiple architectures with potentially different behaviour on each.

A more formal definition a PIP is a string of byte-code $b$ such that for different machines $m_1$ and $m_2$, $b$ is a valid program if: 

$$m_1(b) \not = \bot \wedge m_2(b) \not =\bot.$$

To construct a PIP one must analyse the instruction sets of each architecture and find instructions which compile to identical patterns of byte-code. The approach taken by the authors in [@Cha:2010uh] was to find small PIPs with a very specific form: do nothing then jump. By ensuring each architecture jumped to a different point and that each architecture did not accidentally run into a region another architecture jumped into; they could construct PIPs for any arbitrary program by splitting them up into blocks of instructions specific to each architecture and connecting them with the small PIPs.

Consider the following example (taken from [@Cha:2010uh]). The disassembly for the X86 architecture is shown above, and for the MIPS platform bellow. 

$$\underbrace{\overbrace{90}^{\text{NOP}} \overbrace{eb20}^{\text{JMP}}
2a }_{\text{NOP}} \underbrace{90eb203a}_{\text{NOP}}
\underbrace{24770104}_{\text{B}}$$ 

The string is valid on both platforms and has similar behaviour on both despite jumping to different locations.  In fact this is a valid PIP for the X86, MIPS and ARM architectures.  If we disassemble the pattern with the Radare2 reverse engineering framework[@radare] we can see that it disassembles to:

 Architecture  Disassembly
 ------------  ----------------------------------------------------------------------------
 X86           nop; jmp 0x100000023; sub dl, [eax+0x243a20eb]; ja 0x10000000c; ???
 ARM           bcs 0x10083ae48; bcc 0x10083ae4c; streq r7, [r1], #-1828
 MIPS          slti zero,s1,-5232; xori zero,s1,0xeb90; b 0x10001dc9c

 : Disassembly of an example PIP header from [@Cha:2010uh]

For the X86 architecture it is a NOP instruction then a jump instruction.  The rest wont be executed (though some of it is valid X86 code) as the unconditional jump will have moved the program counter along.  For the ARM architecture it is starts with two conditional jumps.  The first tests if the processor's carry flag is set, and the next checks if the carry flag is not set.  One of these two instructions will be executed so one of the two jumps will be taken.  For MIPS architecture the first two instructions write the result of the operation back to register zero.  On the MIPS architecture any writes to register zero are discarded and the `slti` and `xori` can not cause any errors to occur.  This means the first two instructions are equivalent to a `NOP` instruction.  The third instruction is a MIPS branch instruction, so the sequence for a MIPS computer is equivalent to do nothing and jump.

Since for each of the X86, ARM, and MIPS architectures the byte-code is equivalent to do nothing and jump; the instruction is a valid PIP.

They go on to give a generalised algorithm for constructing these PIPs, and say that they have a working implementation of it for creating PIPs for the X86, ARM, and MIPS platforms, as well as the Windows, Mac, and Linux operating systems.


Aim Of The Project
------------------

For this thesis I have implemented a section of the PIP finding algorithm: the section for finding the *gadget headers*; the PIPs that link the specific code sections together.  To generate the PIPs a list of *semantic NOPs*[^whatsASemanticNop] and potential branch instructions has been found for each architecture in the original paper and to extend the work of the original paper I have also analysed a new platform: XMOS XS1.

[^whatsASemanticNop]: A semantic NOP is an instruction which has no effect, but
which might not necessarily be the *NOP* assembly instruction.  For example the
ARM instruction: `MOV r4, r4` Causes the contents of register four to be moved
into register four and as such is equivalent to an actual `NOP` instruction.
Equally the sequence of instructions: `PUSH r3` `POP r3` If equivalent to two
`NOP` instructions when taken as a whole and so is a *multi-instruction
semantic NOP*.

Unfortunately there does not seem to be a public database of these instructions available for *any* architectures.  Semantic NOPs have been used in areas other than creating PIPs, for example malware classification[@Bilar:2007uu][@Preda:2007ky], but  there still appears to be no exhaustive list exists documenting them. Part of the work required is to create one. 

Applications Of PIPs
--------------------

PIPs can be used for a variety of applications.  One potential application suggested by Brumley et. al.[@Cha:2010uh] is for sneaking programs past dynamic execution checkers.  Suppose two prisoners *Alice* & *Bob*, wish to send a malicious program between themselves.  To send the message they have to send it through a *Warden* who checks first that there communications don't contain anything malicious and only delivers the message if its believed to be harmless. 

Steganography is the science of hiding information[@Gordon:vw].  It has been used in parallel with cryptography to hide messages in seemingly innocuous documents[@Saamuson:wt], to circumvent bans on cryptography[@Owens:2002uq], and to implement watermarking[@Wayner:2009vw]. To sneak the program Alice and Bob use a form of *keyed-steganography*[^PIPsteg].   The program which they wish to communicate becomes their *steg-text*, and they construct a *cover-text* by writing some other program which does not contain anything malicious.   They either pre-arrange a shared secret which is the platform that their programs should really be run on: this forms the key.   With the cover-text and steg-text created they create their message by generating them into a PIP where on one platform (X86 say) it appears to run the innocuous program and on the secret key platform (ARM for the sake of argument) it runs the program they really wish to communicate.  Alice hands the warden the program and tells him that it is for the innocuous architecture[^PIParchs].  The warden runs the program and sees it is not something he would want to restrict and delivers it.  In fact unless he is aware that it has been in constructed in this way he may not even check any other architectures as for most platforms it will appear to be garbage just like any normal executable. 

A more real world example of this is to consider the relationship between computers (usually using an X86 processor) and modern smart phones (which often use ARM processors) running *apps*.  The computer often stores backups of the applications used on the smartphone.  Apple's iTunes program, for example, stores all the mobile applications associated with a user in it is library folder as zip-compressed archives.  Suppose an attacker were to construct a program which was a lignite application on the ARM platform but when run on X86 behaved as a form of malware. The computer might have some form of anti-malware software, but unless it knows to scan the mobile applications as potential X86 viruses rather than the ARM ones they identify themselves as (and which are not ARM malware) then the anti-malware program might miss the dangerous code.

[^PIPsteg]: which the authors[@Cha:2010uh] call *execution-based steganography*. 

[^PIParchs]: if they were using ELF they would not even need to do that—it is part of the header in the file[@mancx:th].

Another application is *exfiltration protection*.  Exfiltration is military term meaning the removal of a resource from enemy control.  In the context of PIPs this probably involves taking programs from protected PCs; kind of like DRM. The idea is that to protect its software from theft a secret agency could make a modification to an existing platform (the JVM or another virtual machine would be a good choice here) and compile their program for this modified platform. They then create another program for the unmodified platform which does something else; maybe it phones home, maybe it destroys itself from the computer it is running on.  They create a PIP out of these two programs and now if the program is stolen and the exfiltrator is not aware of the PIP nature (or exactly what modifications were made to the architecture) they cannot execute the program they removed.

Microcode offers another interesting way to use PIPs.  Suppose an attacker manages to compromise a system in such a way that they can alter the microcode of the processor, such as the recent HP printer attack amongst others[@Cui:vx][@Scythale:tk]. Now suppose that as well as the microcode update they also modify an existing program, Brumley et. al. suggest `ls`, so that on the compromised system it gives a backdoor or acts maliciously, but on another (say one which is trying to forensically work out what is wrong with the printer) it acts normally.  Brumley et. al. point out[@Cha:2010uh] that if this was done by Intel and the PIP was a preexisting and digitally signed application: it is a particularly scary prospect. Merely signing the program would be insufficient protect a user it would not check if the machine it was executing on had been modified. 

PIPs could also be used to create platform independent shell code to take advantage of buffer overflows on software ported between different architectures and operating systems.  As well as developing PIPs to create architecture independent programs, Brumley et. al.[@Cha:2010uh] extended the basic technique to create operating system programs.  For operating system independent programs they exploited overlaps in calling conventions and interrupts to develop PIPs which could be valid programs on multiple systems.  Brumley et. al. give an example remote bind-shell shell code for multiple architectures at the end of their paper [@Cha:2010uh].

Another application for PIPs is to create actual platform independent programs. The idea here is to compile a program for multiple architectures and create a PIP out of them.  You would get a program that behaved the same but ran on multiple architectures.  This could be useful, for example, if you have a network of computers (some Linux X86 based, some ARM based) and you want to run a server hosting all the programs to share between them you don't have to maintain multiple versions.


Other Approaches To Program Obfuscation
---------------------------------------

The problem is that although PIPs could be used to write architecture independent programs, there are more elegant solutions available than relying on the intersection of instruction sets between architectures.  There are several preexisting systems for doing this such as Apple's *Universal Binary* or the *FatELF*[@Icculus:vl] format.  Another problem is that for some operating systems this just would not work: Linux normally uses the ELF format[@mancx:th] which has a flag in the header which specifies exactly what architecture the binary was compiled for.  If it does not match the architecture of the machine it is being run on, then the loader refuses to run it[^elfflag].

[^elfflag]: Of course there is nothing to stop you flipping the flag to some other value with `elfedit` utility from the GNU Binutils.

Collberg et. al. [@Collberg:1997vt] describe different methods for hiding the structure of a program.  They give many different transforms but three are of particular interest: adding dead code, adding redundant transforms, and outlining[^outlining] sections of code. 

These three are of interest because they describe what a PIP is doing, namely adding redundant NOPs and transforms which don't alter the state of the program before jumping to the actual code.

[^outlining]: Outlining is the opposite of inlining.  For inlining we take a function call and replace it with the functions code inserted into the main program verbatim.  For outlining we take a block of code inside a function and make a function call out of it.  We might do inlining to skim a couple of jump instructions from our program at the expense of a longer program; but outlining (especially of sections only run once) just adds to the spaghetti nature of the code.

Whilst adding the `NOP` instructions is not a particularly *resilient*[^resilient] transformation (a program could replace or remove them) they are potent[^potent] especially if they are combined with multi-instruction semantic NOPs where the state of the program does change only to be reversed later.  The jumps added by the PIPs act to outline blocks of code.  If you're using just one PIP at the start of the program then it is not that obfuscating but in a situation where you're outlining every single instruction with a PIP like structure and possibly embedding different behaviour if it is run on a different architecture (such as Java or Thumb mode on an ARM chip) this has the potential to be massively obfuscating.

[^resilient]: Resilience is a measure of how easy it is to deobfuscate a transform.  It is usually measured in terms of the time and space the deobfuscator has to run.

[^potent]: Potency measures how confusing for a human the transform is. For example self-modifying code is a very potent transform, but renaming the jump targets is not.

Interestingly papers, such as [@Christodorescu:2005vh][@Christodorescu:2005vf], even describe obfuscation techniques where they deobfuscate the addition of semantic NOPs using a novel (and patented [@Christodorescu:2009wo]) tool called *Hammock*. Hammock appears to be interesting because rather than using a catalogue of pre-known semantic NOPs it finds them by analysing whether sequences of code have any net effect on the state of the machine.  They find it to be a very slow transform to deobfuscate (implying adding NOPs is a potent obfuscation technique) but the removal is quick once they have been found.

Semantic NOPs are another interesting aspect of the PIP problem.  Semantic NOPs are important for PIPs as they give you multiple ways of doing nothing—so there is a greater chance of finding an overlap between different architectures but they turn up in other places too.  Many people [@Christodorescu:2005vh][@Owens:2011um][@Bruschi:2007dn] have suggested using semantic NOPs as an obfuscating technique.  Wartell et. al.[@Wartell:2011ji] suggest using them as part of a heuristic for differentiating between code and data for disassembled programs. The GNU Assembler has a short list of efficient, low power semantic NOP[^gas_nops] instructions it uses to pad instruction sequences to cache-lines[@Anonymous:td].

[^gas_nops]: A comment above the function[@Anonymous:td] notes that most of the instructions used as part of the semantic NOP sequences by the assembler are not in fact assemblable's with the assembler.


What Is The Challenge?
----------------------

The original PIP paper[@Cha:2010uh] contains an anecdote where the effort required to create platform independent programs is described as requiring:

> "a large, flat space to spread out the architecture reference manuals, and an ample supply of caffeine.  Do not underrate the second part."

Brumley et al go on to note that:

> "even the most caffeinated approaches have only been met with limited success;"

For this thesis we are not trying to fully generate platform independent programs; rather we are just trying to find the headers that enable them.  To do this we need two things:  a list of semantic NOP And jump instructions for each architecture we are interested in, and a method for combining them to form the headers.

Finding the semantic NOPs and jump instructions in theory is quite easy. You can go through the architecture manual making notes of the all the instructions which you're interested in (checking that they don't alter the state of the processor in any surprising way) before assembling them to get the bytecode.  For some architectures it *is* easy—the instruction sets are small and everything in the instruction set is accessible through a standard assembler. 

The MIPS architecture[@MIPSTechnologiesInc:2011ta] is a good example of a platform which it is easy to find semantic NOPs.  A short RISC instruction set, a limited number of status-altering instructions and a register that discards any value written to it make it and ideal platform for writing semantic NOPs.  Several million single instruction semantic NOPs can be found with minimal effort. The Intel X86 architecture[@IntelCorporation:1997ta] is completely different however.  There are a large number of instructions here including multiple forms of the same instructions which the assembler is free to pick between.  All arithmetic instructions alter status flags.  Worse still there are some assembly instructions that can not be assembled by the GNU tool chain[@Anonymous:td]. It is considerably harder to find semantic NOPs for the X86 architecture.

Once we know the form of the instructions we want to assemble we need to compile and disassemble them to get the bytecode, and store them in a database.  Once we have them in an indexable format we need to search for the patterns that overlap and find all the PIP headers.  There are significant problems associated with finding these PIP headers.  For platforms like ARM[@Seal:2000vd] and MIPS[@MIPSTechnologiesInc:2011ta] instructions are all compiled to be of fixed length (four bytes).  In this case we could find  short PIPs by comparing the lists of NOP instructions for one architecture and jump instructions for the other.  We could extend them to arbitrary lengths by finding the NOPs which do nothing on both architectures and padding to the length required.  

In practice however this approach doesn't work.  Variable length instruction sets, such as X86[^X86instructions], mean you need to combine instructions together to get them to the length you require.  If there were only a few identifiable patterns of semantic NOPs and jump instructions then this approach might be feasible but the numbers become huge.  For example on many architectures there is an unconditional jump instruction.  If this instruction takes a thirty-two bit address to jump to then there are $2^{32}$, over four billion, possible forms of this instruction to check.  And this is just one instruction.  On X86 it even has more than one compiled form.  Conditional jumps exasperate the problem further.  For a conditional jump you need two (or more!) jump instructions, so that means $2^{64}$ possible variants to check which is huge. 

[^X86instructions]: For example the instruction `NOP` compiles to `[0x90]`, but the `movsldup xmm0,xmm1` instruction becomes `[0xF3, 0x0F, 0x12, 0xC1]`. 

The MIPs architecture demonstrates well nether issue.  With the MIPS architecture you have a register called zero which discards any value written to it.  This offers great opportunities for finding semantic NOPs, but it also presents further problems with the size of patterns you can find.  The `ADDI` instruction, for example, is used to add a sixteen bit number to a register and then write back to another one.  MIPS registers are represented in an instruction using five bits and it doesn't matter which of them we use (so long as we write back to zero).  A sixteen bit immediate, plus a five bit register means twenty-one bits we don't care about in this instruction, and over two million permutations of this single instruction. Even if we use tricks to reduce the problem size we still have problems.  Even restricting the search to a small subset of the possible patterns the amount of memory required to store them is large—hundreds of gigabytes.  If we want to be able to detect when there are PIPs in a file we need to be able to search these files; again computationally expensive. 

Detecting PIPs is another difficult problem.  There is currently no data as to how often these patterns occur in regular files.  Since the instruction sequences used in PIPs are valid for multiple architectures a PIP instruction sequences could turn up in a program without being part of some malicious behaviour.  Data for how often PIPs turn up in normal code is needed before any statistical model for detecting them can be made. 

This data does not currently exist.




Technical Basis
===============

To construct PIPs three tasks need to be accomplished: find the instructions that can be used to form semantic NOPs; chain them together with jump instructions to create the potential PIPs for a given architecture; finally compare the potential PIPs for each architecture to see if any of them exist in both architectures.  These are the PIPs we are interested in.

Computer Architecture Background
--------------------------------

To construct PIPs instructions must be assembled and the bytecode examined.  Processors fetch instructions in a binary format, a string of 1s and 0s, which we call bytecode.  Each architecture has its own specific form of bytecode; that is to say if `1010100101` means add two registers on one architecture then there are no guarantees that this pattern means the same thing on another—or even that the other has registers to add together.  

Every instruction a processor wishes to offer has to be mapped to a sequence of bytecode[^bytecode_not_true].  Some architectures, such as ARM[@Seal:2000vd] MIPS[@MIPSTechnologiesInc:2011ta] and X86[@IntelCorporation:1997ta], are register based (they expect data to be used in calculations to be stored in special pieces of memory called registers) and the instructions take arguments saying exactly which registers to use.  Others, such as the JVM[@Lindholm:2012wy], are stack based (they expect arguments to operations to be stored in a data structure called a stack where the top one or two items are the operands to most instructions. 

[^bytecode_not_true]:  This is true in general but slightly oversimplified.  The X86 and ARM instruction sets both feature special instructions which can change how sequential pieces of bytecode are decoded.  For example the ARM architecture[@Seal:2000vd] can switch to decoding the THUMB or JVM instruction sets by using the `BX` instruction (which has the bytecode of `e12fff10`).  X86[@IntelCorporation:1997ta] offers similar a similar mechanism for turning on or off feature sets which can alter how instructions are decoded.

Different architectures offer different sorts of instructions.  The X86 achitecture offers a large number of instructions which can do many different things such as AES encryption and arithmetic[@refX86].  The ARM architecture[@Seal:2000vd], however, is much smaller—it doesn't have a division instruction.  The XS1 architecture[@May:ua] has several instructions for concurrency and communicating over ports which are not present on other architectures.  To make matters more complex the length of instructions also varies on an architecture by architecture basis:  MIPS and ARM instructions are always four bytes long but the X86 and JVM instruction sets use a variable length instruction size.


When a processor wishes to execute a program (formed of bytecode) it *fetches* the instruction (or instructions if the processor is superscalar) to be run, *decodes* what the instruction is to do before *executing* it and *writing back* the result.  For this project we are targeting the decode stage.  We are trying to find bytecode that decodes to legitimate instructions for multiple processors, and then using this bytecode to make arbitrary programs.




Semantic NOPs
-------------

Formally a semantic NOP is an instruction that has no net effect on the state of the processor other than moving the program counter to the next instruction.  A semantic NOP is functionally equivalent to the `NOP` opcode (which often is a synonym for a low-power semantic NOP). Specifically if the outcome of the machine executing an instruction is functionally equivalent to the machine executing the `NOP` instruction, independent of the state of the machine[^ienoflags], then it is a semantic NOP.

[^ienoflags]: e.g. the instruction would always behave as a `NOP` instruction even if a conditional execution flag was set differently.

For example on the ARM architecture[@Seal:2000vd] the `NOP` instruction is assembled into the bytecode `e1a00000`.  The instruction `mov r0, r0` is also assembled to `e1a00000`.  Because they have the same bytecode we can see that these two instructions are actually the same.  The designers of the architecture chose to replace the `NOP` instruction with a functionally equivalent one in the bytecode format.  This is done (amongst other reasons) to compress the instruction set.  Here the `mov r0, r0` instruction is the `NOP` instruction as well as being functionally equivalent to it, but the designers of the architecture could have chosen differently.  The instruction `mov r1, r1` is functionally equivalent to the `NOP` command as well but the bytecode to represent it is `e1a01001` which is different to the `NOP` instruction.  This means that `mov r1, r1` is a semantic NOP—it has the same behaviour as the `NOP` instruction and a different bytecode.

The instruction `movgt pc, r2` however would not be a semantic NOP instruction.  Here the instruction will behave as a NOP instruction unless the greater than flags are set when it will move the contents of register two into the program counter.  This isn't a semantic NOP because though it will behave like a `NOP` instruction some of the time it might not do.  If a programmer had added this instruction knowing that the greater than flags would never be set when this instruction was executed then it would be very similar to a semantic NOP but more often called *dead code*[@Collberg:1997vt].  

There is another sort of semantic NOP we have used: a multi-instruction semantic NOP.  This is a sequence of instructions that may alter the state of the machine, but will reverse any change they make by the end of the sequence; they are a redundant transform.  For example the sequence `ADD r0,r0,#1`, `SUB r0,r0,#1` is a redundant transform as any change to the state of the machine (specifically register zero) is undone by the second instruction[^notonX86].  We call sequences like this semantic NOPs as well though more care must be taken when using these as if the machine were to handle an interrupt whilst executing one the state of the machine might be altered unpredictably.

[^notonX86]: On the X86 architecture[@IntelCorporation:1997ta], however, this wouldn't be a semantic NOP as arithmetic operations alter status flags as well as the registers they operate on[@refxasmnet:vu].


Searching for the semantic NOPs is book work.  You take the architecture manual and search through it; making a notes of the mnemonic, arguments and whether any exceptions could be raised or flags overwritten.  For simple instruction sets (like ARM or MIPS) this can be done in a couple of hours; but for complex instruction sets this can be an arduous process[^X86ref].

[^X86ref]: Resources such as the *X86 Opcode and Instruction Reference* [@refX86] are invaluable for discovering what each instruction actually does in a clear format.

Once you have found the instructions you want to use for a semantic NOP you have to deal with the problem of scale: there are a lot of them.  Here you have two concerns: for a list of semantic NOPs you want clarity of instruction and to be easily able to identify assembled and disassembled forms.  An easy way to do this is to store the bytecode with the assembly instructions used to generate it.  A problem with this approach, however, is that the lists can become large.  An alternative to this is to introduce *don't care* bytes into the compiled forms. 

Consider this example:  a simple semantic NOP for the MIPS architecture is `addiu zero,t0,0`. It has the (big-endian) compiled form of `25000000`. Another semantic NOP is `addiu zero,t0,1` which compiles to `25000001`.  But for this instruction so long as you write back to the `zero` register the instruction is always a semantic NOP.  Looking at the architecture manual[@MIPSTechnologiesInc:2011ta] there are no exceptions that can be raised by it so its safe to use as a semantic NOP.  The manual lists describes the instruction `addiu rt,rs,immediate` as:

$$GPR[rt] \gets GPR[rs] + immediate$$
$$\mathtt{\overbrace{0010\;01}^\text{opcode}
\overbrace{\cdot\cdot\;\cdot\cdot\cdot}^\text{rs}
\overbrace{0\;0000}^\text{rt}\; \overbrace{\cdot\cdot\cdot\cdot\;
\cdot\cdot\cdot\cdot\; \cdot\cdot\cdot\cdot\;
\cdot\cdot\cdot\cdot}^\text{immediate}}$$

If we were going to enumerate every possible combination of operands for this single instruction we would get around two-million[^2million] possible semantic NOPs just from this single instruction.  Whilst for a database this is desirable to accurately describe every possible semantic NOP, for generating PIPs this becomes a problem.  To generate the PIPs we need to combine them with other semantic NOPs and jump instructions.  By working with the representation with *don't cares*[^dontcareshex] we can dramatically cut the number of permutations of instructions.  This is important when the numbers of semantic NOPs becomes huge, and the instructions are shorter (i.e. with X86) as the running time to find them can become excessive.

[^2million]: There are twenty-one free bits in the instruction, so there are $2^{21}$ possible enumerations; which is 2,097,152 in real numbers.

[^dontcareshex]: Actually you end up using the hexadecimal notation because it works better with disassembler tools. For this instruction ends up being stored as $\mathtt{2[4567][2468ace]0\cdot\cdot\cdot\cdot}$ which has twenty-eight possible enumerations not including don't cares.  This turns out to give a good balance between wanting a short list of instructions and a readable format.


Generating PIPs
---------------

Once we have the list of semantic NOPs we then need a list of possible jump instructions.  We generate this list the same way we find the semantic NOPs: enumerating the possible operations and then generalising by introducing *don't care* symbols[^dontcare].  Again multibyte jumps are possible on some architectures (such as ARM) by  exploiting conditional execution.

[^dontcare]: A *don't care* symbol represents a bit or byte of the instruction set whose value we don't care about.  For example the X86 short jump instruction could be represented in byte-code as `eb..` where `.` is the don't care symbol.  We care that it is a jump instruction, which the `eb` encodes; but we might not care where it jumps to so we can represent the destination with *don't cares*.

Once you have the two sets—semantic NOPs and jumps—for the architecture you can proceed as follows:  pick a length of the PIP pattern you want to find, add a jump instruction on the end of the PIP.  Subtract the length of the jump instruction from the pattern length and then for every possible semantic NOP add it to the start of the PIP.  If it has not made the PIP too long, output it as a possible PIP before trying to add another semantic NOP onto the pattern. Finally pad any output PIPs to the required length with don't cares if it is not long enough.  Pseudo code for this process is given below in a python-esque language.


~~~~ { language="python" caption="Algorithm used to generate PIPs" }
def generate_possible_nop_jump_patterns(length, nop_list, jump_list):
	for jump in jump_list:
		pattern = [jump]
		for PIP in pad_with_nops(pattern, length, nop_list):
			PIP = pad_with_dont_cares(PIP, length)
			print PIP
			
def pad_with_nops(pattern, length, nop_list):
	if length(pattern) < length:
		yield pattern
		for nop in nop_list:
			pattern = nop : pattern
			for each PIP in pad_with_nops(pattern, length, nop_list):
				yield PIP			
~~~~


Once we have done this for multiple architectures we can try and find PIPs which are valid for two or more architectures.   To do this we find the PIPs in each architecture which have equivalent forms and produce a new PIP from them which forces some of the don't-cares to actualy values if one of the PIPs demands it.

~~~~ { language="haskell" caption="Method used for removing \emph{don't-cares} from potential PIP headers" }
-- Equality with don't cares
(~=~) :: Nibble -> Nibble -> Bool
'.' ~=~ _   = True
x   ~=~ '.' = True
x   ~=~ y   = x == y

-- Do two PIPs match?
matches :: PIP -> PIP -> Bool
x `matches` y = and $ zipWith (~=~) x y

-- Resolve two PIPs to remove don't cares if required
resolve :: PIP -> PIP -> PIP
resolve = zipWith resolve'
  where
    resolve' x y
     | x == y    = x
     | x == '.'  = y
     | y == '.'  = x
     | otherwise = error "Resolving unresolvable characters"

{- Given two sets of PIPs, produce a third containing 
   the valid PIPs for both architectures -}
findPIPs :: [PIP] -> [PIP] -> [PIP]
findPIPs PIPs1 PIPs2 = 
	[ resolve x y
	| x <- PIPs1                            
	, y <- PIPs2                                      
	, x `matches` y
	]
~~~~

These PIPs are the ones we particularly interested in.  We can repeat the process again to find PIPs for multiple architectures if we like by using the generated set of PIPs as one of the input sets.


An Alternative Approach
-----------------------

The approach taken here to find the PIPs is similar to the one taken by Cha et al[@Cha:2010uh] to find their gadget headers (though they do not give a specific algorithm for this section).  However alternative approaches are also possible.  A good area to provide an alternative method for is the semantic nop section.

As described earlier; adding dead or garbage code is an established obfuscation technique, and it is in current use in several metamorphic codes such as Evol, ZMist, Regswap and MetaPHOR[@Borello:2008vx].  Identifying dead code sequences is a technique already used by several anti virus tools as part of their toolchains.  These can be leveraged to finding semantic NOPs by getting them to output the offending sequences.[^actually_it_cant]

[^actually_it_cant]: Actually this does not work quite as described.  A really simple and often used trick to implement dead code insertion is to introduce unreachable code that looks as if it could be reached (i.e. by placing a conditional jump that is always taken just before it).  This unreachable code might not necessarily have no net effect on the program execution but because it will never be run it does not matter anyway.  From the point of view of a metamorphic virus this is an attractive technique because of the greater freedom of content inside the dead-code segment; and so many more variants of the malware.  For PIPs this technique is not useful (or rather implementing the always-taken-jump before the dead code is what we are trying to do rather than the writing dead-code).  Coverage tools such as *gcov* can be used to find unreachable code such as this.[@Administrator:ul] For finding semantic NOPs more advanced tricks need to be used.

One approach to identify these semantic NOP based sequences is to use signatures[^whats_a_signature], but this requires the semantic NOPs to have been previously identified.  An alternative scheme, used by the SAFE tool[@Christodorescu:2006vz], is to find the semantic NOPs is to try and analyze sections of code and see if there would be any net change in the state of a machine if they were to run them.  This is similar to simulation but has the added challenge of being able to tell if *any* input would cause a change of state rather than just the single input that is simulated. 

[^whats_a_signature]: Have a big list of *signatures*; see if any match the bit of code you're looking at.

To do this you need to keep track of all the variables and what transformations are applied to them over the course of the program. Calculations like this become unfeasible quickly and there are no guarantees that they will find any semantic NOP regions.  The other problem with this strategy for finding semantic NOPs is that the regions of code can be very large.  For the purposes of this project it is preferable that any patterns found be short; so actually just using the architecture manual and hand picking, as it were, one or two instruction sequences to form the semantic NOPs is preferable.  Also for the sequences of only one or two instructions it is quite easy to find every possible semantic NOP pattern.

Because of the increased complexity and running time of this method I did it by hand instead.  This had the advantage of being simple, easy and ensured I did not miss any details, such as side effects or missing instructions.  For finding the PIPs I believe this was the better method in this case.



Malware Detection Methods
-------------------------

Given that we can use PIPs to create programs with steganography it would be helpful to be able to distinguish PIP from non-PIP.  Malware detection gives a set of methods to accomplish this.

Using the detection notion defined in [@Preda:2007ky] we define a malware detector as the following.  Given the set of every possible program $\mathbb{P}$ there is a subset $\mathbb{M}$ that have malicious behaviour.  $$\mathbb{M\subset P}$$ For some of the programs in $\mathbb{M}$ we have a signature $s$ which is formed in some way from the program.  A detector $D$ is a function that given a $p\in\mathbb{P}$, and a signature $s$ says true if the signature was formed from that program and false otherwise.  The 

We can evaluate the detector and a set of signatures by seeing how well it can distinguish malware from non-malware.  The false-negative rate is the percentage of all the malware which the detector fails to report as being malware.  The false-positive rate is the percentage of all non-malware detector incorrectly reports as being malware.  Depending on the where the malware detector is being used the false positive and negative rate can be tweaked to requirements by altering the set of signatures and how they are generated.  The approach of detecting malware by its appearance is popular; however in general detecting whether a program is malware by appearance is an undecidable problem [@Cohen:1987wt][@Shyamasundar:2010tl]. 

There are several different approaches to generating malware signatures.  One approach is to use a section of the malware itself to form a signature.  To do this they give a regular expression that specifies a sequence of byte or instruction sequences that are considered malicious.  If the malicious sequences of code are seen in a program the malware detector reports it as malware.  To avoid these techniques new forms of *polymorphic* and *metamorphic* malware have been developed which use self modifying code and encryption to hide these signatures from signature based detectors[@Christodorescu:2005vf].

Other approaches to getting and evading signatures have been developed.  One approach to avoiding signature matching is to randomize the order of some expressions[@Borello:2008vx][@Christodorescu:2005vf].  To counter these obfuscations approaches which use control flow patterns as signatures have been developed[@Bonfante:2007th].  The idea is that whilst some sub-expressions may be rearranged the algorithms themselves cannot be so dramatically changed.  These approaches have been relatively successful at detecting polymorphic malware [@Kang:2011bs][@Bruschi:vb].  Another approach is to use model checking to try and identify sections of code that copy the instruction sequences to different locations or which use suspicious parts of the Windows API[@Kinder:2005hu].  To counter these improved protections more techniques have been developed.  One approach to detecting malware is to simulate it and see if it does anything suspicious.  To counter this malware authors have taken to putting in NP-HARD problems into their code so that any simulator also has to solve a problem such as 3-SAT[@Moser:2007cd]—this slows detection.

Various toolchains have been developed to aid detecting malware.  The Binary Analysis Platform[@Brumley:wn] is one such platform which works by reduction to an intermediary language.  It offers support for as well as malware detection; automatic exploit generation[@Avgerinos:vo], signature generation, and formal verification.  Other platforms, such as CodeSurfer[@Balakrishnan:2005tx], are built on top of IDA Pro[@HexRays:up].  CodeSurfer works with IDA to provide more representations of a program;  the idea is that these extra-representations allow an analyst to reason about what a piece of malware does.



Components
==========

 * I used the GNU compiler toolchains[@Binutils:2006tc] for ARM, MIPS, X86 to assemble lists of semantic NOPs.
 * I used the XMOS toolchain to assemble lists of semantic NOPs for the XS1 architecture.
 * I used the Jasmine assembler[@Meyer:1996vx] to explore writing semantic NOPs for the JVM.
 * I used the Radare 2 framework[@radarenopcodeorg:vw] to write semantic NOPs and jumps with don't care bytes for ARM, MIPS and X86 as well as to verify the PIPs at the end.  I also used its JVM dissasembler and assembler to explore the JVM for creating PIPs.
 * I used Ruby and Haskell to write various tools to create the PIPs.
 * I refered to the architecture manuals for ARM[@Seal:2000vd], MIPS[@MIPSTechnologiesInc:2011ta], X86[@IntelCorporation:1997ta] and XS1[@May:ua] extensively throughout the project but also made use of the ARM and Thumb Instruction Set Quick Reference Card[@Limited:vc] and X86 Opcode reference[@refX86].


Execution
=========

Semantic NOPs
-------------

  Architecture  Semantic NOPs Identified
  ------------  ------------------------
  ARM           187,879
  MIPS          18,958,336
  X86           1,266
  XS1           792

  : Semantic NOP sequences identified per architecture.

Around nineteen million semantic NOP sequences for the ARM, MIPS, X86 and XS1 architectures were identified and stored in a database of the form:

$$\text{\textsc{Semantic-NOPs}}\left( 
\text{\underline{architecture}}, 
\text{instruction prefix}, 
\text{instruction suffix},
\text{\underline{bytecode prefix}},
\text{\underline{bytecode suffix}}
\right)$$


By using prefix and suffixes we can separate certain multi-instruction semantic NOPs from the rest.  Some multi-instruction semantic NOPs can be written with more semantic NOPs within them and by using this prefix and suffix form we can distinguish the bit which needs to go first from the bit which must come at the end.

For example consider these entries from the database:

Architecture  Instruction Prefix  Instruction Suffix  Bytecode Prefix  Bytecode Suffix
------------  ------------------  ------------------  ---------------  ---------------
X86           PUSH %rax           POP %rax            50               58
X86           NOP                                     90

The bytecode `90` is a semantic NOP—the `nop` instruction.  Equally the sequence `push %rax; pop %rax` is a semantic NOP sequence with bytecode `5058`.  For the `push`-`pull` sequence we can place any code in between the `push` and the `pull`.  If that sequence is a semantic NOP too then the sequence as a whole is a semantic NOP as well.  So `509058` is a semantic NOP; as is `50909058`; or ever `5050905858`.

Looking at the numbers found in Table 5.1 the MIPS architecture is by far the easiest to find semantic NOPs for.  The MIPS register zero (which discards all writes to it) enables any instruction to be easily converted to a semantic NOP just by writing back to register zero.  Furthermore there are four different instructions in the MIPS architecture which take a sixteen bit immediate value as an operand and can be used without triggering an exception[@MIPSTechnologiesInc:2011ta]: `addiu`, `andi`, `ori` and `slti`.  These can all be used to generate semantic NOPs; but more importantly give us sixteen free bits for when we are trying to find the PIPs.

ARM is the next easiest (though there are a hundredth of what can be found for MIPS).  The ARM7 architecture supports conditional execution which helps for finding semantic NOPs.  Conditional execution is implemented by having four bits encode a conditional flag and one bit used to indicate that the system flags should be updated[@Seal:2000vd].  If the flag is matched then the command is executed else the command becomes a NOP.  We have less registers than MIPS and while we have three instructions which can be used with immediate values (`add`, `sub` and `eor`) they only use an eight-bit value (as well as input to a barrel shifter).

X86 has significantly less semantic NOPs than ARM or MIPS.  One reason for this is a lack of instructions that don't alter the state of the processor in some way: all the arithmetic instructions update flags inside the processor.  There are no instructions we can use with an immediate value to write a semantic NOP.  The XS1 architecture has a similar number of semantic NOPS to X86 for similar reasons.  There are less registers than X86 and only a limited number of instructions that take an immediate value that can be used for writing semantic NOPs.

### The JVM

The JVM is an interesting architecture but very different from all the others I looked at.  The JVM is a virtual stack based architecture[@Lindholm:2012wy].  Stack based architectures don't use registers like the X86 ARM or MIPS architectures, but rather expect most of their instructions operands to be on a stack in memory.  Some JVM instructions do take arguments passed as part of the bytecode instruction; such as the `goto` and `goto_w` instructions which take the two or four byte address to go to as an argument.  Most do not however and most JVM instructions are only one byte long.  Within functions the JVM imposes some strict rules about the size of the stack and constants available.  If the size of the stack exceeds the limit imposed then an exception is triggered.

This leads to some problems with trying to find semantic NOPs for the JVM.  Most JVM NOPs that can be found are multi-instruction.  There is a `nop` instruction (`00`), but in general to write a semantic NOP for the JVM you need to push and pull values on and off the stack.  There are JVM instructions for rearranging the stack which can be used to create semantic NOPs—the `swap` instruction (`5f`) could be issued twice but even this only works if you know the type of the top two elements of the stack and can be sure they are the same type.  Unless you know something of the program you're adding these kinds of semantic NOPs too you can very easily end up triggering an exception from misuse of the stack. 

Another problem with the JVM is from the complexity from chaining together the instructions.  If you ignore the problems associated with limited stack space and assume an unlimited amount of stack then you still have to cope with the problems of enumerating.  Specifically you need to find a sequence of instructions such that the stack is unchanged overall; but since most of the instructions take from the stack and add back to it you can use most of them so long as you pop (perhaps using the `pop` (`57`) or `pop_2` (`58`) instructions) any additional values back off at the end and make sure there are enough useless values on the stack initially so as not to alter any pre-existing ones.  Any dead-code program will work, which unfortunately means that there are many and they can be very long.  An interesting side point here is that there are quite a lot of tools out there to detect Java dead code sequences: such as DCD[@Vermat:wk] and UCD[@Spieler:uz].  The JDK hotspot compiler can optimize dead code sequences away[@Goetz:ua].  It would be an interesting problem to see how rare dead code sequences are in regular compiled code (i.e. programs from Java code rather than handwritten JVM bytecode).  Dead code elimination is a common optimization, and I would suspect the answer is not often. 


PIPs
----

 *Architecture*  ARM LE              ARM BE              MIPS LE              MIPS BE              X86
 --------------  ------------------  ------------------  ------------------   ------------------  ------------------
 ARM LE                              $6.6\times10^{4}$   0                    $2.6\times10^{5}$   0
 ARM BE          $6.6\times10^{4}$                       $2.6\times10^{5}$    0                   $7.0\times10^{4}$
 MIPS LE         0                   $2.6\times10^{5}$                        $1.0\times10^{6}$   0
 MIPS BE         $2.6\times10^{5}$   0                   $1.0\times10^{6}$                        $2.8\times10^{5}$
 X86             0                   $7.0\times10^{4}$   0                    $2.8\times10^{5}$

 : Four byte PIPs found between architectures.

 *Architecture*  ARM LE              ARM BE              MIPS LE              MIPS BE              X86
 --------------  ------------------  ------------------  ------------------   ------------------  ------------------
 ARM LE                              $3.1\times10^{14}$  $2.8\times10^{14}$   $1.2\times10^{15}$  $1.1\times10^{12}$
 ARM BE          $3.1\times10^{14}$                      $1.2\times10^{15}$   $2.8\times10^{14}$  $6.2\times10^{14}$
 MIPS LE         $2.8\times10^{14}$  $1.2\times10^{15}$                       $4.5\times10^{15}$  $4.2\times10^6$
 MIPS BE         $1.2\times10^{15}$  $2.8\times10^{14}$  $4.5\times10^{15}$                       $2.4\times10^{15}$
 X86             $1.1\times10^{12}$  $6.2\times10^{14}$  $4.2\times10^{6}$    $2.4\times10^{15}$

 : Eight byte PIPs found between architectures.  On top of these results $2.0\times10^{10}$ were found which were valid for the ARM LE MIPS BE and X86 architectures.

Tables 5.2 and 5.3 show the number of PIPs found of length four and eight bytes respectively. For four byte headers we found a similar number to Brumley et. al. [@Cha:2010uh] for the ARM and X86 architectures (tens of thousands), however we found significantly more for the MIPS and any other architecture than Brumley (hundreds for Brumley et. al. versus tens to hundreds of thousands for us).  Brumley et. al. don't give numbers for how many eight byte headers they can find however their numbers for twelve byte headers are around a thousand to ten-thousand times bigger than the number found for eight byte headers.  This seems fairly reasonable considering the number of possible different bytecode sequences for a twelve byte sequence is $2^{96}$ rather than only $2^{64}$ for an eight byte one.

### Why So Few For MIPS?

I am unsure why Brumley et. al. found so few four byte PIP headers for the MIPS architecture.  For the twelve byte sequences the number of PIP headers they found between the MIPS and any other architecture is significant but for four byte sequences their number found is very low.  For example they only found six PIP headers between the MIPS little endian and big endian architectures.  This suggests they didn't use the MIPS jump instruction to find any of their sequences.

The MIPs jump instruction has the following format[@MIPSTechnologiesInc:2011ta]:
$$\mathtt{000010\overbrace{\cdot\cdot\cdot\cdot\cdot\cdot\cdot\cdot\cdot\cdot\cdot\cdot\cdot\cdot\cdot\cdot\cdot\cdot\cdot\cdot\cdot\cdot\cdot\cdot\cdot\cdot}^\text{address}}$$

Its easy to find a four byte PIP header for the little and big endian variants of the MIPS architecture by using this instruction.  If we switch the endianess of the instruction and then remove all the $\cdot$s that overlap with a fixed bit we find that a jump instruction for both MIPS endianesses has the form in binary of:
$$\mathtt{000010\cdot\cdot\cdot\cdot\cdot\cdot\cdot\cdot\cdot\cdot\cdot\cdot\cdot\cdot\cdot\cdot\cdot\cdot\cdot\cdot000010\cdot\cdot}$$
Where $\cdot$ indicates either a 1 or a 0.  If we convert this sequence to hexadecimal we get the set of four byte PIP headers for different MIPS endianess variants that I identified.

$$\mathtt{08....08, 08....09, 08....0a, 08....0b, 09....08, 09....09, 09....0a, 09....0b} \brace \mathtt{ 0a....08, 0a....09, 0a....0a, 0a....0b, 0b....08, 0b....09, 0b....0a, 0b....0b}$$




Detecting PIPs
--------------

  Program            ARM BE (%)   MIPS BE (%)  MIPS LE (%)  X86 (%)
  -----------------  -----------  -----------  -----------  --------
  DrawSomethingFree  203 (0.0%)   834 (0.1%)   215 (0.0%)   1 (0.0%)
  Dropbox            79 (0.0%)    375 (0.1%)   89 (0.0%)    1 (0.0%)
  Mother 3           3426 (0.1%)  3181 (0.1%)  2227 (0.1%)  2 (0.0%)
  Pages              696 (0.0%)   2659 (0.1%)  651 (0.0%)   7 (0.0%)
  SwordAndSworcery   136 (0.0%)   545 (0.1%)   129 (0.0%)   0
  Vim                32 (0.0%)    160 (0.1%)   33 (0.0%)    0
  *Random*           25 (0.0%)    94 (0.1%)    17 (0.0%)    0

  : Number of times eight byte PIP headers occur in ARM programs and the percentage of the total program which they occupy.  All of the programs listed *apart from Mother 3 and Random* are taken from iPhone applications for Apple's iOS operating system.  *Mother 3* is a program for Nintendo's GameBoy Advance.  Random is a long string of random bytes.


  Program      ARM BE (%)   ARM LE (%)   MIPS BE (%)  MIPS LE (%)
  -----------  -----------  -----------  -----------  -----------
  hello        0            0            0            0
  cat          0            0            0            0
  clang        223 (0.0%)   0            6299 (0.2%)  0
  echo         0            0            4 (0.1%)     0
  linux-2.6    264 (0.1%)   0            918 (0.2%)   0
  ls           2 (0.0%)     0            19 (0.2%)    0
  mach_kernel  237 (0.0%)   0            5266 (0.3%)  0
  nasm         7 (0.0%)     0            72 (0.2%)    0
  pandoc       582 (0.1%)   0            2147 (0.1%)  0
  *Random*     39 (0.0%)    1 (0.0%)     205 (0.2%)   0

  : Number of times eight byte PIP headers occur in X86 programs and the percentage of the total program that they occupy.  The programs *cat, echo and ls* and small UNIX utilities.  *Hello* is the hello-world program written in C.  *Clang* is a C compiler; *nasm* is an assembler and *pandoc* is a Haskell based markdown compiler.  *Linux-2.6* is the Linux kernel and *mach_kernel* is a version of the Mach kernel by Carnegie Mellon University found in Apple's MacOS Lion.   


To test the steganographic properties of PIPs I looked at how often they occur in various programs for the ARM and X86 architectures.  I chose to look at X86 and ARM as they are two of the most commonly found architectures today.  A processor with the X86 instruction set architecture is inside most consumer PCs and servers.  The ARM architecture[^whicharm], however, is found everywhere.  It is the dominant processor inside mobile phones with both Google's Android and Apple's iOS platforms running on this architecture.  ARM chips are often found in embedded systems and have even been found in massively parallel supercomputers[@Khan:2008uv]. 

[^whicharm]: Specifically the ARM 7 32-bit architecture known as AArch32 not the new shiny 64-bit one.

For the ARM architecture I focused on *app-like* programs.  I looked at a variety of apps from games to text editors as well as a sequence of random bytes and a Gameboy advance game.  The Gameboy game is interesting as it also contains sound and graphics files built into it that the iOS applications do not.  The results are shown in Table 5.4.  The results seem to show that PIP headers very rarely turn up in ARM code; less than 0.1% typically.  Some PIP headers turn up for the ARM little endian and MIPS architectures, but next to none ever turn up for X86 PIP headers in ARM little endian programs.  It would be surprising if more that ten turned up in any program.  Another interesting point is that PIP headers don't appear to turn up in programs more often than they do in a random sequence of code. For X86 we see similar results (Table 5.5).  I looked at a range of program from very simple C programs and system utilities, to compilers and two operating system kernels.  Again we see that NOPs turn up very rarely in bytecode, 

In Brumley et. al.'s paper[@Cha:2010uh] they suggest that whole platform independent programs could be created by splitting the program into several *gadgets* each with a PIP header and a block of code to be executed for each platform the program author wishes to target.  Brumley et. al. go on to suggest that a program could be split up into gadgets one instruction in length, however since each gadget would feature a PIP header this would likely destroy any steganographic properties the author want in their program.   Because PIP headers are rare; a program with execution based steganography could be distinguished from a plain text by counting the number of PIP headers that could be found and deciding whether that number is statistically significant.  When an author is trying to hide X86 behaviour this is a much bigger problem as the number of PIP headers that could be expected to turn up naturally in a program is very low.  This suggests an easy way to implement a detector: if the number of PIP headers in a program is uncharacteristically high predict that the program has some PIP behavior.



### Detecting With Static Analysis

If including several PIP headers and splitting the program into lots of small sections is going to remove steganographic properties what about using fewer gadgets and having longer section of platform specific code?  The problem with this approach is that it becomes very susceptible to static analysis.  Suppose we were to take a program for ARM and were to disassemble as if it were a program for X86.  There are likely to be a fair number of valid instructions in it for X86 just from the fact that a large amount of X86 bytecode is also valid ARM bytecode because designers of architectures like to make instruction sets dense for encode efficiency; but if we were to start seeing sequences that look like X86 calling conventions then we might immediately become suspicious that there is some steganographic execution behaviour hidden.

As an example consider this PIP taken from [@Cha:2010uh]:

  Hexadecimal                                      Characters
  -----------------------------------------------  -------------------------------------------
  \texttt{7f454c46 01010100 00000000 00000000}     \texttt{\frenchspacing .ELF............}
  \texttt{02000300 01000000 54800408 34000000}     \texttt{\frenchspacing ........T...4...}
  \texttt{00000000 00000000 34002000 01000000}     \texttt{\frenchspacing ........4. .....}
  \texttt{00000000 01000000 00000000 00800408}     \texttt{\frenchspacing ................}
  \texttt{00800408 f4000000 f4000000 05000000}     \texttt{\frenchspacing ................}
  \texttt{00100000 90eb3e20 1700002a 1600003a}     \texttt{\frenchspacing ......> ...*...:}
  \texttt{07000010 00000424 2128e003 0c000624}     \texttt{\frenchspacing .......\$!(.....\$}
  \texttt{a40f0224 0c000000 a10f0224 0c000000}     \texttt{\frenchspacing ...\$.......\$....}
  \texttt{f8ff1104 00000000 48656c6c 6f20776f}     \texttt{\frenchspacing ........Hello wo}
  \texttt{726c640a 90909090 eb1731db 438b0c24}     \texttt{\frenchspacing rld.......1.C..\$}
  \texttt{ba0c0000 00b80400 0000cd80 31c040cd}     \texttt{\frenchspacing ............1.\@.}
  \texttt{80e8e4ff ffff4865 6c6c6f20 576f726c}     \texttt{\frenchspacing ......Hello Worl}
  \texttt{640a9090 0100a0e3 18108fe2 0c20a0e3}     \texttt{\frenchspacing d............ ..}
  \texttt{0470a0e3 000000ef 0000a0e3 0170a0e3}     \texttt{\frenchspacing .p...........p..}
  \texttt{000000ef 0000a0e1 48656c6c 6f20576f}     \texttt{\frenchspacing ........Hello Wo}
  \texttt{726c640a}                                \texttt{\frenchspacing rld.           $}

  : A PIP containing a *Hello World* program for ARM MIPS and X86.

If we ignore that the program has the text *Hello world* three times in the bytecode the program might not be immediately suspicious.  The program only uses one platform independent section to split the code, so it isn't particularly suspicious by counting PIP headers.  If we disassemble the code, however, it starts to become far more suspicious. In Listing 5.1 a section of the program disassembled for X86 architecture.  Two system calls (the `int 0x80`) are clearly made[@Kerrisk:vo]. Before each system call arguments are loaded such that the first is a write operation, and the second is an exit.  This program clearly has some X86 behaviour. 

````{ basicstyle=\tt, caption="A disassembled section of the PIP in Table 5.6 for the X86 architecture." }
write:
        xor ebx, ebx
        inc ebx
        mov ecx, [esp]
        mov edx, 0xc
        mov eax, 0x4
        int 0x80
exit:
        xor eax, eax
        inc eax
        int 0x80
````

If we disassembler the program in Table 5.6 as an ARM program (as shown in Listing 5.2) however we can quickly find an equivalent section of code.   Again this is all valid ARM code and it obviously does a write system call followed by an exit.  It's in the PIP too so the PIP must have ARM behavior as well as X86; this program is probably a PIP and we have discovered this just by inspecting the disassembly—a form of static analysis.

````{ basicstyle=\tt, caption="A disassembled section of the PIP in Table 5.6 this time for the ARM architecture." }
write:
        mov r0, #1 ; 0x1
        add r1, pc, #24 ; 0x18
        mov r2, #12 ; 0xc
        mov r7, #4 ; 0x4
        svc 0x00000000
exit:
        mov r0, #0 ; 0x0
        mov r7, #1 ; 0x1
        svc 0x00000000
````

If we try again using a MIPS disassembler we get the code in Listing 5.3.  Again  its pretty obvious what is going on and it didn't take long to find even by eye.  This PIP is probably valid on the MIPS platform as well as X86 and ARM, and we've done this through simple static analysis.  None of these sections of code are long—around nine instructions—and yet they give a strong indication that the program has PIP behaviour.  It would be an interesting extension to look at creating a static analyser to detect how much valid code for different architectures there is in a program and whether any of it seems to form a valid program snippet.

````{ basicstyle=\tt, caption="A disassembled section of the PIP in Table 5.6 for the MIPS architecture." }
write:
        li a0,0
        move a1,ra
        li a2,12
        li v0,4004
        syscall
exit:
        li v0,4001
        syscall
````

This means that if we were to use the number of PIP headers in a program as a metric, we should be able to construct a PIP detector where a greater number of PIP headers would indicate increased confidence in the program being a PIP.  In [@Cha:2010uh] they suggest splitting a program into as many PIP sections as there are lines of code.  If this was actually tried, however, a detector could be constructed to look for PIP headers and due to the large number of them should be able to distinguish PIP from non PIP—or at least do it better than a random oracle or ESP-RNG running in predict mode[@Birkett:vw].


### Hiding PIP Code

Given that excessive use of PIP headers appears to make it obvious when a program is a PIP and that having long sequences of platform specific code give the game away as well; is there any way to use PIPs without destroying the steganographic properties?  Several techniques have been developed for creating analysis resistant malware[@Bethencourt:2008ug] which could equally be applied to resisting PIP detection.  Using signatures is relatively primitive technique[^dino] for detecting malware[@Zhang:2007jy] and several techniques have been developed which can evade it as well as improve upon it.

[^dino]: Whilst signatures are somewhat of a dinosaur[@Lull:1910tz] of a technique they are still an effective technique for detecting malware and still very actively used though they do not always looks just at bytecode snippets anymore.[@Acosta:wz][@Liang:2011va]

One approach is to use encryption.  The program code is stored inside the program as data but at run time the program decrypts it back to executable code[@Royal:2006ug].  This resists static analysis because the section of code we would want to analyze can't be read without decryption.  Unless we can recover the key and know how to decrypt the program we might not be able to spot the PIP behaviour.  Of course to do the decryption on multiple platforms we're either going to need a PIP malware extractor but if this can be written using less PIP headers than the full program then it might be a way forward.  

Developing methods for detecting encrypted or packed malware is a current research topic and there have been several tools developed for detecting this[@Chouchane:2006cf][@Zhang:2007jy].  These could be applied to detecting packed PIP code as well.

Metamorphic malware[@Sikorski:2011ua] takes a similar approach.  It again uses self-modifying code to alter a program so that it can evade signature based detection.  An approach would be to have a program that alters instructions to create the gadget headers in Brumley's paper[@Cha:2010uh] dynamically based on runtime information.  This suffers from similar problems to the encryption approach of needing a PIP modifier and there are several available techniques for detecting it [@Han:2011iu][@Ali:2011do].

Another approach might be to issue a microcode update[@Smotherman:2010wr].  The idea here is that rather than try and decrypt part of the program so that it is valid we alter how the processor decodes the program so that the previously invalid buffer is now a valid program; perhaps even for multiple architectures.  Issuing microcode updates involves modifying the BIOS and is typically used by processor designers to patch bugs in the processor.  The technique is known to be difficult to utilize[@Skoudis:2004to] but is also very difficult to detect. It would be extremely interesting to look further at using microcode updates to create PIPs as there appears to be less available research on the topic.


Writing Programs with PIPs
--------------------------

To demonstrate PIPs I created a shell code (shown in Listing 5.4) for the MIPS and X86 architectures using existing platform specific shell codes by Richard Imrigan[@Imrigan:vg] and TheWorm[@TheWorm:vp].  The shell code uses a single PIP header which would also allow this PIP to be valid for the ARM architecture if it were extended further.

````{ basicstyle=\tt, mathescape=true, caption="An example of a shell code PIP for X86 and MIPS which attempts to spawn a shell and elevate permissions.  Shellcode for each architecture was taken from \autocite{Imrigan:vg}\autocite{TheWorm:vp}." }
eb020008 00000000 6a175831 dbcd80b0 80b02ecd 806a0b58 9952682f 2f736868
2f62696e 89e35253 89e1cd80 00000000 00000000 00000000 00000000 00000000
00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000
                         $\mathrm{\normalsize\vdots \text{\ \textsf{89 lines ommited}\ } \vdots}$ 
00000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000
00000000 00000000 2806ffff 3c0f2f2f 35ef6269 afaffff4 3c0e6e2f 35ce7368
afaefff8 afa0fffc 27a4fff4 2805ffff 24030fab 0101010c 
````

The shell code is far from ideal.  A decompilation of the PIP header can be seen in Table 5.7, but an immediately obvious flaw is that the PIP header used has a nil byte in it.  Even discarding the long sequence of nil bytes in the middle of the program (which could be filled with any value as it is not executed) the shell code is long.  This really isn't a particularly effective bit of shell code.

  Description                Value
  -------------------------  --------------------------------------------------------------
  Bytecode                   `eb020008 00000000`
  X86 Disassembly            `jmp 0x100000004; add [eax], cl add [eax], al; add [eax], al;`
  MIPS Disassembly           `j 0x100000bac; nop;`
  ARM Disassembly (unsused)  `bl 0x100080028; andeq r0, r0, r0`

  : Decompilation of the PIP header used in Listing 5.4

One reason it is so much longer is that it is difficult to find PIPs that have short jumps for multiple architectures.  It is reasonably easy to find a PIP header that will jump to two reasonably close instructions but quite difficult to find a PIP header that will jump to two extremely close instructions.  This need not be that much of a problem.  Most programs are longer than shellcode.   In a longer program more of the empty space could be utilised and filled by program code or by using more PIP headers so there would be less wasted space.

### Liveness And PIPs

An alternative method would be to increase the number of available PIP headers by allowing a PIP to change the state of the processor.  A PIP could modify the state of a register or update status flags if the PIP author knew that the flags or the register wasn't being used at that stage in the program. 

Liveness analysis is a technique used by compiler designers to decide which variables are being used by a program[@Aho:2007tt].  In all the PIPs I found I made the assumption that all registers and flags were being used at every stage of the program.  Whilst this ensures that PIP header are safe to be used at any point in a program it does restrict the number of PIPs we can find. 

Consider the example shown in Table 5.8.  For the ARM architecture it does a jump, but for the X86 architecture it does two additions.  Normally we would reject this as a PIP header as an it alters the contents of the `al`, `dl` and `flags` registers.  If we knew, however, that the next few instructions for X86 updated `al` and `dl` anyway[^x86updatingcode] it would not matter that we had altered the value.  We would have added a redundant transform[@Collberg:1997vt], but we would have also added PIP behavior that we would not have previously been able to accept.

[^x86updatingcode]: For example the write system call from earlier: 

	 `xor ebx, ebx; inc ebx; mov ecx, [esp]; mov edx, 0xc; mov eax, 0x4; int 0x80`
		
  Description               Value                         Altered Registers
  ------------------------- ----------------------------  ------------------
  Bytecode                   `020000ea` 
  ARM Decompilation          `b 0x12`                     `pc`
  X86 Decompilation          `add al, [eax]; add dl, ch`  `al, dl, flags`

  : A PIP header that shows how liveness analysis can be used to find more PIPs.

To implement this scheme we would need two things: a liveness analyser to be able tell which registers are safe to alter in the section of code we want to add PIP behaviour to; and an extended list of PIP headers which detail which registers a PIP alters.  We still need to be careful about altering certain registers (such as the stack pointer) or triggering exceptions (perhaps by invalid code or overflow) but we're gaining a lot more freedom and should be able to find more PIP headers; all though more care would be required to use them.  Brumley have implemented this in their PIP system, however they do not provide any implementation details[@Cha:2010uh].  Again it would be interesting to see how often PIP headers of this form turn up in natural code: probably more often.




Conclusion 
========== 

Current Status
--------------

For this project I have:

  1. Analyzed the ARM, X86, MIPS and XS1 instruction sets for semantic NOPS and contributed a publicly available list of semantic NOP instructions for each.  I looked at the problems with trying to find semantic NOPs for the JVM.
  2. Recreated a subset of the PIP research done by [@Cha:2010uh] and created a list of four and eight byte PIP headers between the ARM, X86 and MIPS instruction sets.
  3. Created a novel PIP using the headers and discussed the problems with not using liveness analysis to find PIP headers.
  4. I analyzed the frequency PIP headers turn up in non-PIP code for X86 and ARM programs to evaluate the steganographic properties of PIPs—something that has never been done before.  I concluded that there may be problems with the approach suggested by [@Cha:2010uh] if an author wanted steganographic properties in PIPs and suggested techniques to overcome the problems.


### XS1 PIPs

I only partially managed to get the PIP generation algorithm going for the XS1 architecture.  It is certainly possible that PIPs exist for the XS1 architecture.  The short number of semantic NOPs I found for the XS1 architecture (Table 5.1) might be a hindrance to the PIP generation algorithm, however the XS1 architecture has several conditional jump instructions that could be used to create the jumps inside the PIPs: specifically the `BRBF, BRBT, BRFF` and `BRFT` instructions could all be used in their `(ru6)` and `(lru6)` forms as well as the `BRBU` and `BRFU` instruction in their `(u6)` and `(lu6)` forms[@May:ua].

If we restrict the search to XS1 PIPs which use the `BRBU` and `BRFU` instructions we can find some for the XS1 and other architectures (Table 6.1).  This isn't a complete search (and hence why it isn't presented as part of the main results) but it definitely indicates that the XS1 architecture is vulnerable to this technique and is comparable to X86 in terms of susceptibility.

  Size of XS1 section  ARM BE               ARM LE            MIPS BE             MIPS LE            X86
  -------------------  -------------------  ----------------  ------------------  -----------------  -------------------
  4 B                  $3.2\times10^4$      $0$               $1.4\times10^5$     0                  $3.3\times10^4$

  : Incomplete table of PIPs found for the XS1 architecture.

Unfortunately these PIPs are also very hard to verify. To check the PIPs for the other architectures I used the Radare2 framework's disassembler[@radarenopcodeorg:vw] to verify the bytecode did what I expected, but the disassembler does not support the XS1 architecture.  Radare does support writing extensions for other architectures—it would be worth writing a back-end for XS1 before doing a full study of the PIPs available for the architecture so that any PIPs found could be verified easily.


### Twelve Byte PIP headers

A problem I encountered finding the PIP headers was the time and space complexities.  Brumley et. al. managed to find twelve byte headers[@Cha:2010uh] whereas I stopped at eight.  Each of the files storing the four byte PIPs can be measured in bytes.  For eight byte PIPs this raises to kilobytes and megabytes.  Attempts to generate twelve byte PIPs lead to files with sizes in gigabytes before I stopped the program running.  The time to find the PIPs also increases: seconds for four byte; hours for eight bytes; unknown time for twelve byte but measured in days.  I did manage to create lists of potential PIP headers for the ARM, MIPS and X86 architectures of twelve bytes in length.  However I could not successfully reduce these to the actual PIP headers for use with multiple architectures.  Since PIPs could be effectively shown using only eight byte headers I compromised and stopped there.

Parallelism could also be used to improve the PIP finding performance.  Finding PIPs involves recursively joining every possible sequence of semantic NOPs for an architecture with every possible jump for that architecture then comparing two lists for different architectures to find the overlapping ones.  Sections of this could certainly parallelized; the comparison could be done very effectively with OpenCL[@opencl]—a technology I discovered too late to use in this project.



Open Problems
-------------

### Extending PIPs To More Architectures

Other architectures can be used to write PIPs and it would be interesting to look at the difficulty for each of them.  Instruction sets such as the new 64 bit ARM would be interesting, as would ARM's THUMB instruction set.  The big architecture to target though has to be the JVM.  

Because the JVM is so different from other architectures, being stack based, it is interesting from a technical point of view to see how effectively PIP generation can be done on it. The other reason the JVM is so tempting is that lots of computers have a lot of Java applications on them.  If you wanted to use PIPs to hide programs on a computer there is a good chance that there would be some Java files that could contain a hidden X86 program as well as the expected JVM bytecode.


### Looking at opportunities for using microcode updates to create PIPs

Microcode is a really fascinating subject by itself. It is easy to find a stack of patents regarding systems for updating or installing microcode[@Demke:2000uf][@Tung:2004tm][@Langford:2006uf], but there is less research available on the subject of using it for writing malware.  In Soukis and Zeltser's book [@Skoudis:2004to] they subtitle the chapter on it: *The Possibility of BIOS and Malware Microcode*.  They note in [@Skoudis:2004to] that trying to analyze the data in a microcode update is:

  > "like trying to read a love letter from a Casanova to his lovers, written in a language that you don't understand, encrypted using a crypto algorithm you don't know, protected with an encryption key that you don't have."

Clearly using microcode for PIPs is a non-trivial task, but the pay-off is potentially huge.  You could write a PIP for one system and develop a virus to deliver the microcode update.  If the system has had the microcode update then the hidden PIP behaviour is triggered.  The nice thing about this approach is that you might be able to get a lot of control over which instructions are used for PIP behavior: this would make trying to detect PIPs a lot more interesting as you could introduce PIP behaviour to very common instructions.


### Advanced PIPs

A problem with the work I did was that I focussed my attentions on PIP headers that made no modification to the program state.  Whilst these are the ideal form of PIP as they can be used with any block of platform specific code without fear of mucking up its behaviour, but it also restricts the number that can be found.  In a realistic situation a PIP author may know something about the program they are trying to add PIPs to.  They may be able to use a wider range of instructions for their semantic NOPs which end up either as dead code or as a part of their program.  If so then this makes the detection problem more difficult.  I only looked at using the PIPs I studied for my detector and found they didn't really turn up in normal code.  This isn't really that surprising.  The PIPs all used semantic NOPs: dead code.  An optimizing compiler ought to be able to remove these sections without much fuss, and sure enough that is what I found: safe PIPs don't turn up in real code.  I would guess that the PIPs that make use of these more dangerous PIPs turn up a lot more in some kinds of programs as they are closer to real code (i.e. they do something).  That said if the way programs are written doesn't match the structure found in a PIP (which is a little more random with respect to instruction order) then they may still not turn up often.  It would be interesting to study this further.


The End
-------

In conclusion I created a publicly available database of semantic NOPs.  I found four and eight byte PIP headers for the ARM, MIPS and X86 architectures.  I looked at the probability of finding PIP headers in natural code and found that a detector for a PIP program could be written if it used the count of PIP headers as a metric as PIP headers occur rarely in natural code.

PIPs are an interesting upshot of instruction sets utilizing their bytecode efficiently.   More research is needed to be able to explore the possibilities offered by them and to see whether they would be actually useful in practice for malware or steganography; as well as to see how well they could be detected in practice.   It has struck me through out this project how funny it is that these languages we program in eventually compile down to assembly and how that assembly is assembled into a sequence of bits which you would normally think of as being completely incompatible with any other architecture.  The way these architectures are designed there ought to be no compatibility—each designed differently with different goals.  But because it all comes down to bits eventually, and designers are keen not to waste them, there is almost always eventually some overlap.  By exploiting that overlap with a little care and thought suddenly the same sequences of assembly can be realised as two different programs for two different architectures; and suddenly we have PIP behaviour.  It wasn't designed for.  It is a side effect of efficiently designing an instruction set.   But that little side effect lets us write truly platform independent programs.  We can use it for steganography.  We can use it to write malware.  It can be used for some really cool things  and it is just a side effect.  Neat or what?

\appendix

Bibliography
============

