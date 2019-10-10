--[[
27	26	25	24	23	22	21	20

0	0	I	OP	OP	OP	OP	S	Data Processing/PSR Transfer	If bit 25 is 1 this is only choice
0	0	0	0	0	0	A	S	Multiply
0	0	0	0	1	U	A	S	Multiply Long
0	0	0	1	0	U	0	0	Single Data Swap	U == B
0	0	0	1	0	0	1	0	Branch and Exchange
0	0	0	P	U2	0	W	L	Halfword Data Transfer: register offset
0	0	0	P	U2	1	W	L	Halfword Data Transfer: immediate offset

0	1	I	P	U2	U	W	L	Single Data Transfer	U == B
0	1	1	X	X	X	X	X	Undefined	check bits 27-25, 4

1	0	0	P	U2	U	W	L	Block Data Transfer	U == S

1	0	1	L	X	X	X	X	Branch

1	1	0	P	U2	U	W	L	Coprocessor Data Transfer	U == N

1	1	1	0	CP	CP	CP	CP	Coprocessor Data Operation
1	1	1	0	CP	CP	CP	L	Coprocessor Register Transfer

1	1	1	1	X	X	X	X	Software Interupt
X means ignore it

In summary: Bits 27-24
0000	(0)
	Data Processing/PSR Transfer
	Multiply
	Multiply Long
	Halfword Data Transfer: register offset
	Halfword Data Transfer: immediate offset
0001	(1)
	Data Processing/PSR Transfer
	Halfword Data Transfer: register offset
	Halfword Data Transfer: immediate offset
	Single Data Swap
	Branch and Exchange
0010	(2)
	Data Processing/PSR Transfer
0011	(3)
	Data Processing/PSR Transfer
0100	(4)
	Single Data Transfer
0101	(5)
	Single Data Transfer
0110	(6)
	Single Data Transfer
	Undefined (need to also check bit 4)
0111	(7)
	Single Data Transfer
	Undefined (need to also check bit 4)
1000	(8)
	Block Data Transfer
1001	(9)
	Block Data Transfer
1010	(10)
	Branch
1011	(11)
	Branch
1100	(12)
	Coprocessor Data Transfer
1101	(13)
	Coprocessor Data Transfer
1110	(14)
	Coprocessor Data Operation
	Coprocessor Register Transfer
1111	(15)
	Software Interupt
]]--

function cond(code, CPSR)
	local temp = CPSR
	local N = bit.rshift(CPSR, 31) % 2
	local Z = bit.rshift(CPSR, 30) % 2
	local C = bit.rshift(CPSR, 29) % 2
	local V = bit.rshift(CPSR, 28) % 2
	if code == 15 then console.log("COND ERROR") end
	if code == 0 then return (Z == 1), "EQ\t" 					--EQ (equal)
	elseif code == 1 then return (Z == 0), "NE\t"				--NE (not equal)
	elseif code == 2 then return (C == 1), "CS\t"				--CS (unsigned higher or same)
	elseif code == 3 then return (C == 0), "CS\t"				--CC (unsigned lower)
	elseif code == 4 then return (N == 1), "MI\t"				--MI (negative)
	elseif code == 5 then return (N == 0), "PL\t"				--PL (positive or zero)
	elseif code == 6 then return (V == 1), "VS\t"				--VS (overflow)
	elseif code == 7 then return (V == 0), "VC\t"				--VC (no overflow)
	elseif code == 8 then return (C == 1 and Z == 0), "HI\t"	--HI (unsigned higher)
	elseif code == 9 then return (C == 0 and Z == 1), "LS\t"	--LS (positive or zero)
	elseif code == 10 then return (N == V), "GE\t"				--GE (greater or equal)
	elseif code == 11 then return (N ~= V), "LT\t"				--LT (less than)
	elseif code == 12 then return (Z == 0 and (N == V)), "GT\t"	--GT (greater than)
	elseif code == 13 then return (Z == 1 or (N ~= V)), "LE\t"	--LE (less than or equal)
	elseif code == 14 then return true, "AL\t"					--AL (always)
	else return false, "ERROR\t" end
end


function arm_format1(Cond, I, Opcode, S, Rn, Rd, Operand2, registers)
--Data Processing/PSR Transfer
--Rn is always first operand
--Rd is always destination
--I == 0 operand 2 is a shifted register. 1 means operand 2 is a rotated immediate offset
--Opcode is what determines the action to do
--S == 0 do not set condition code. 1 means set condition codes
--Binary 1111 or 1111 1111 respectively.
	local Rm = 0
	local Shift = 0
	local Rotate = 0
	local Shift = bit.ror	--default choice
	local op2_str = ", ROR "
	local return_string = ""
	local S_str = (S == 1) and "S\t" or ""	--So it'll be eg. ADD EQ S; technically there's no space, but fuck that
	local cond_val, cond_str = cond(Cond, registers.CPSR)
	--[[
	31	30	29	28	27	26	25	24	23	22	21	20	19	18	17	16	15	14	13	12	11	10	9	8	7	6	5	4	3	2	1	0
C	C	C	C	0	0	I	OP	OP	OP	OP	S	RN	RN	RN	RN	RD	RD	RD	RD	OP2	OP2	OP2	OP2	OP2	OP2	OP2	OP2	OP2	OP2	OP2	OP2	Data processing instructions
C	C	C	C	0	0	0	1	0	P	0	0	1	1	1	1	RD	RD	RD	RD	0	0	0	0	0	0	0	0	0	0	0	0	MRS (transfer PSR contents to a register)
C	C	C	C	0	0	0	1	0	P	1	0	1	0	0	1	1	1	1	1	0	0	0	0	0	0	0	0	RM	RM	RM	RM	MSR (transfer register contents to PSR)
C	C	C	C	0	0	I	1	0	P	1	0	1	0	0	0	1	1	1	1	S	S	S	S	S	S	S	S	S	S	S	S	MSR  (transfer register contents or immdiate value to PSR flag bits only)
OP for PSR corresponds to 
1000	TST
1001	TEQ
1010	CMP
1011	CMN
S is always 0 for PSR Transfer
	]]--
	local MRS_flag = (Opcode == 8 || Opcode == 10) and S == 0 and Rn == 0xF and Operand2 == 0
	local MSR1_flag = (Opcode == 9 || Opcode == 11) and S == 0 and Rn == 0x9 and Rd == 0xF and bit.band(Operand2,0xFF0) == 0
	local MSR2_flag = (Opcode == 9 || Opcode == 11) and S == 0 and Rn == 0x8 and Rd == 0xF
	local is_DataProc = (MRS_flag == false and MSR1_flag == false and MSR2_flag == false)
	
	--This applies to both Data Processing & PSR Transfer
	if I == 0 then	--Operand 2 is a (shifted) register
		local Rm_num = bit.band(Operand2, 0xF)	--binary 1111
		Rm = registers[Rm_num]		
		local Shift_flag = bit.rshift(Operand2, 4) % 2
		local Rs = 0
		local Shift_type = bit.rshift(bit.band(Operand2, 0x60),5)	--binary 0110 0000
		--Define which shift operation to use. As long as I == 0, this is always bits 5 and 6 in operand2
		if Shift_type == 0 then
			Shift = bit.lshift
			op2_str = ", LSL "
		elseif Shift_type == 1 then
			Shift = bit.rshift 
			op2_str = ", LSR "
		elseif Shift_type == 2 then
			Shift = bit.arshift
			op2_str = ", ASR "
		end
		--If flag (bit 4 of operand2) == 0 then we shift operand2 by an immediate value; 
		--else we take another register and shift by the contents in that
		--Either way, call this thing Rs
		if Shift_flag == 0 then
			Rs = bit.rshift(Operand2, 7)	--Immediate value to shift as
			op2_str = "R"..Rm_num..op2_str.."#"..Rs
		else
			local Rs_num = bit.rshift(Operand2, 8)	--Register number
			Rs = registers[Rs_num]
			op2_str = "R"..Rm_num..op2_str.."R"..Rs_num
		end
		--Do we set carry flags here?? Need to check if shifting at this point also affects CPSR
		--This should also work for PSR, since Shfit == 0000000
		Rm = Shift(Rm, Rs)
	else	--Operand2 is a (rotated) immediate value
		Rm = bit.band(Operand2, 0xFF)	--binary 1111 1111
		Rotate = bit.rshift(Operand2, 8)
		--op2_str should be ", ROR " here
		--Also, both values should be immediate; IMM ROR Rotate basically
		op2_str = "#"..Rm..op2_str.."#"..Rotate
		Rm = Shift(Rm, Rotate)	--This is why rotate is default
	end
	if is_DataProc == true then
	--<opcode>{cond}{S} Rd, <Op2>
	--<opcode>{cond} Rn, <Op2>
	--<opcode>{cond}{S} Rd, Rn, <Op2>
		if Opcode == 0 then
			return_string = "AND\t"..cond_str..S_str.."R"..Rd..", R"..Rn..", "..op2_str
		elseif Opcode == 1 then
			return_string = "EOR\t"..cond_str..S_str.."R"..Rd..", R"..Rn..", "..op2_str
		elseif Opcode == 2 then
			return_string = "SUB\t"..cond_str..S_str.."R"..Rd..", R"..Rn..", "..op2_str
		elseif Opcode == 3 then
			return_string = "RSB\t"..cond_str..S_str.."R"..Rd..", R"..Rn..", "..op2_str
		elseif Opcode == 4 then
			return_string = "ADD\t"..cond_str..S_str.."R"..Rd..", R"..Rn..", "..op2_str
		elseif Opcode == 5 then
			return_string = "ADC\t"..cond_str..S_str.."R"..Rd..", R"..Rn..", "..op2_str
		elseif Opcode == 6 then
			return_string = "SBC\t"..cond_str..S_str.."R"..Rd..", R"..Rn..", "..op2_str
		elseif Opcode == 7 then
			return_string = "RCS\t"..cond_str..S_str.."R"..Rd..", R"..Rn..", "..op2_str
		elseif Opcode == 8 then
			return_string = "TST\t"..cond_str.."R"..Rn..", "..op2_str
		elseif Opcode == 9 then
			return_string = "TEQ\t"..cond_str.."R"..Rn..", "..op2_str
		elseif Opcode == 10 then
			return_string = "CMP\t"..cond_str.."R"..Rn..", "..op2_str
		elseif Opcode == 11 then
			return_string = "CMN\t"..cond_str.."R"..Rn..", "..op2_str
		elseif Opcode == 12 then
			return_string = "ORR\t"..cond_str..S_str.."R"..Rd..", R"..Rn..", "..op2_str
		elseif Opcode == 13 then
			return_string = "MOV\t"..cond_str..S_str.."R"..Rd..", "..op2_str
		elseif Opcode == 14 then
			return_string = "BIC\t"..cond_str..S_str.."R"..Rd..", R"..Rn..", "..op2_str
		elseif Opcode == 15 then
			return_string = "MVN\t"..cond_str..S_str.."R"..Rd..", "..op2_str
		end
	else
		local mode == bit.rshift(Opcode,1) % 2	--"PSR" flag; 0 == CPSR, 1 == SPSR_Mode
		local mode_str = (mode == 0) and "CPSR" or "SPSR"
		if MRS_flag == true then
			return_string = "MRS\t"..cond_str.."R"..Rd..", "..mode_str
		elseif MSR1_flag == true then
			return_string = "MSR\t"..cond_str..mode_str..", R"..Rm_num
		else
			return_string = "MSR\t"..cond_str..mode_str.."_flg, "..op2_str
		end
	end
	return return_string
end

function arm_format2(Cond, A, S, Rd, Rn, Rs, Rm, registers)
--Multiply
--This consists of Multiply, and Multiply Accumulate
--A == 0 multiply only. 1 means multiply and accumulate
--S == 0 do not set condition code. 1 means set condition codes
--Rd destination register
--Rn Operand register for accumulator
--Rs, Rm Operand register used for multiplication (Rd = Rs * Rm)
	local S_str = (S == 1) and "S\t" or ""	--So it'll be eg. ADD EQ S; technically there's no space, but fuck that
	local return_string = ""
	local cond_val, cond_str = cond(Cond, registers.CPSR)
	local error1 = (Rd == Rm)	--Rd must not be the same as Rm. Rd is allowed to be the same as Rn, Rs however
	local error2 = (Rd == 15 or Rn == 15 or Rs == 15 or Rm == 15) --register 15 must not be used as destination nor operands
	if error1 == false and error2 == false then
		if A == 0 then
		--Rd = Rm * Rs; Rn is ignored
			return_string = "MUL\t"..cond_str..S_str.."R"..Rd..", R"..Rm..", R"..Rs
		else
		--Rd = Rm * Rs + Rn
			return_string = "MLA\t"..cond_str..S_str.."R"..Rd..", R"..Rm..", R"..Rs..", R"..Rn
		end
	else
		return_string = "Format 2 ERROR"
	end
	return return_string
end

function arm_format3(Cond, U, A, S, RdHi, RdLo, Rs, Rm, registers)
--Multiply Long
--Literally the same as Multiply, except the output is a 64 bit number, split into 2 registers
--Multiply Accumulate becomes RdHi, RdLo = Rm * Rs + RdHi, RdLo
--U A act as opcode
--S == 0 do not set condition code. 1 means set condition codes
--RdHi top 32 bits of result
--RdLo bottom 32 bits of result. Together, they also act as the accumulator

	local S_str = (S == 1) and "S\t" or ""	--So it'll be eg. ADD EQ S; technically there's no space, but fuck that
	local return_string = ""
	local cond_val, cond_str = cond(Cond, registers.CPSR)
	local error1 = (RdHi == Rm or RdHi == RdLo or RdLo == Rm)	--RdHi, RdLo, Rm must not be the same as each other. 
	local error2 = (RdHi == 15 or RdLo == 15 or Rs == 15 or Rm == 15) --register 15 must not be used as destination nor operands
	local opcode = (U * 2) + A	--These are both 1 bit; combine them to form a number between 0-3
	if error1 == false and error2 == false then
		if opcode == 0 then
			return_string = "UMULL"..cond_str..S_str.."R"..RdLo..", R"..RdHi..", R"..Rm..", R"..Rs
		elseif opcode == 1 then
			return_string = "UMLAL"..cond_str..S_str.."R"..RdLo..", R"..RdHi..", R"..Rm..", R"..Rs
		elseif opcode == 2 then
			return_string = "SMULL"..cond_str..S_str.."R"..RdLo..", R"..RdHi..", R"..Rm..", R"..Rs
		elseif opcode == 3 then
			return_string = "SMLAL"..cond_str..S_str.."R"..RdLo..", R"..RdHi..", R"..Rm..", R"..Rs
		else
			return_string = "Format 3 error (undefined opcode)"
		end
	else
		return_string = "Format 3 error"
	end
	return return_string
end

function arm_format4(Cond, B, Rn, Rd, Rm, registers)
--Single Data Swap
--SWP{B} Rd, Rm, [Rn]
--Load Rd with the word addressed by Rn, and store Rm at Rn
--B == 0 store word else store byte
	local B_str = (B == 1) and "B\t" or ""	--So it'll be eg. ADD EQ B; technically there's no space, but fuck that
	local size =(B == 1) and 16 or 8
	local error1 = (Rn == 15 or Rd == 15 or Rm == 15)
	local cond_val, cond_str = cond(Cond, registers.CPSR)
	local return_string = ""
	if cond_val == true then
		return_string = "SWP"..cond_str..B_str.."R"..Rd..", R"..Rm..", [R"..Rn.."]"
	end
	return return_string
end

function arm_format5(Cond, Rn, registers)
--Branch and Exchange
--If bit 0 of Rn = 1, subsequent instructions are THUMB. Else ARM
--This is literally just R15 (PC) = [Rn]
--Exchange apparently refers to ARM <=> THUMB change
	local cond_val, cond_str = cond(Cond, registers.CPSR)
	local return_string = "BX"..cond_str.."R"..Rn
	return return_string
end

function arm_format6(Cond, P, U, W, L, Rn, Rd, S, H, Rm, registers)
--Halfword Data Transfer: register offset
--P == 0 add/subtract offset after transfer. 1 means add/subtract before transfer
--Example: Preindex LDR R1, [R2, #100] load R1 from address located in R2+100
--Example: Postindex LDR R1, [R2], #100 load from address located in R2, then +100
--If P == 1, treat W as 0
--U == 0 subtract offset from base. 1 means add offset to base
--W == 0 no write back. 1 means write address to base
--L == 0 store to memory. 1 means load from memory
--Rn base register
--Rd source/destination register
--S H act as opcode
--Rm Offset register
--Try treating P U W L as a single opcode
--<LDR|STR>{cond}<H|SH|SB> Rd,<address>
	local opcode = (P * 8) + (U * 4) + (W * 2) + L
	local opcode2 = (S * 2) + H
	local cond_val, cond_str = cond(Cond, registers.CPSR)
	local return_string = "SWP\t"	--assume opcode is 0 at start
	local action = SWP
	local error1 = opcode2 > 3	--not sure how that would occur, but ok
--Getting mixed results here; Arm Instruction Set pdf claims W == 1 and Rn == 15 should not be used, while the
--Arm Manual claims Rn == 15 alone is either unpredictable, or must +8/12. Seems to be instruction based
	local error2 = (W == 1 and Rn == 15)	
	--LDRH (A4-54); LDRSB (A4-56); LDRSH (A4-56)
	--RD == 15 unpredictable
	--If W == 1, Rd == Rn then unpredictable
	--STRH (A4-204)
	--RD == 15 unpredictable 
	--(A2-9) This means its either banned, +8, or +12. Have fun :)
	--If W == 1, Rd == Rn then unpredictable
	--Load/Store Immediate offset (A5-35)
	--If Rn == 15, value is address of the instruction + 8
	--Load/Store Register offset (A5-36)
	--If Rn == 15, value is address of the instruction + 8
	--Rm == 15 is unpredictable
	--Load/Store Immediate pre-indexed (P, W == 1; bit22 == 1) (A5-37)
	--Rn == 15 is unpredictable
	--Load/Store Register pre-indexed (P, W == 1; bit22 == 0) (A5-38)
	--Rn == 15 is unpredictable
	--Rm == 15 is unpredictable
	--Rm == Rn is unpredictable (ARMv5 and below; including GBA) 
	--Load/Store Register post-indexed (P, W == 0; bit22 == 1) (A5-39)
	--Rn == 15 is unpredictable
	--Load/Store Register post-indexed (P, W == 0; bit22 == 0) (A5-40)
	--Rn == 15 is unpredictable
	--Rm == 15 is unpredictable
	--Rm == Rn is unpredictable (ARMv5 and below; including GBA) 
	local error3 = (Rm == 15) --R15 should not be the register offset
	local error4 = (S == H and S == 0)	--If S == H == 0, this is immediately treated as Single Data Swap/Multiply/Multiply Long
	local error5 = (P == 0 and W == 1)	--W must be 0 if P is 0 
	
--[[Only LDRH/STRH/LDRSB/LDRSH are legal; STR, STRB, STRSH, STRSB are not allowed in this format
(Arm Manual A5.3, A5-34)
"Signed stores If S ==1 and L == 0, apparently indicating a signed store instruction, the encoding along
with the H-bit is used to support the LDRD (H == 0) and STRD (H == 1) instructions. "
That is for ARMv5TE
So if this occurs, ignore it, and use H bit to determine the instruction.
Signed bytes and halfwords can be stored with the same STRB and STRH instructions as are
used for unsigned quantities, so no separate signed store instructions are provided.
]]--
	if error1 == true then
		return "Format 6: Invalid Opcode"
	end
	if error2 == true then
		return "Format 6: STR/STRB/STRSH/STRSB not allowed" 
	end
	if L == 0 then
		action = STRH
		return_string = "STRH\t"
	else
		-- if opcode2 == 0 then
			-- return_string = return_string
		if opcode2 == 1 then
			action = LDRH
			return_string = "LDRH\t"
		elseif opcode2 == 2 then
			action = LDRSB
			return_string = "LDRSB\t"
		elseif opcode2 == 3 then
			action = LDRSH
			return_string = "LDRSH\t"
		end
	end
	--See examples in Arm Manual A3.11.4, A3-23; not the same instructions but eh
	if opcode == 0 then
	--P == 0; U == 0; W == 0; L == 0
	--Post index; Subtract Rm from Rn; Don't write back to Rn; Store to memory
		--Rd = 
	elseif opcode == 1 then
	--P == 0; U == 0; W == 0; L == 1
	--Post index; Subtract Rm from Rn; Don't write back to Rn; Load from memory
	elseif opcode == 2 then
	--P == 0; U == 0; W == 1; L == 0
	--Post index; Subtract Rm from Rn; Write back to Rn; Store to memory
	elseif opcode == 3 then
	--P == 0; U == 0; W == 1; L == 1
	--Post index; Subtract Rm from Rn; Write back to Rn; Load from memory
	elseif opcode == 4 then
	--P == 0; U == 1; W == 0; L == 0
	--Post index; Add Rm to Rn; Don't write back to Rn; Store to memory
	elseif opcode == 5 then
	--P == 0; U == 1; W == 0; L == 1
	--Post index; Add Rm to Rn; Don't write back to Rn; Load from memory
	elseif opcode == 6 then
	--P == 0; U == 1; W == 1; L == 0
	--Post index; Add Rm to Rn; Write back to Rn; Store to memory
	elseif opcode == 7 then
	--P == 0; U == 1; W == 1; L == 1
	--Post index; Add Rm to Rn; Write back to Rn; Load from memory
	elseif opcode == 8 then
	--P == 1; U == 0; W == 0; L == 0
	--Pre index; Subtract Rm from Rn; Don't write back to Rn; Store to memory
	elseif opcode == 9 then
	--P == 1; U == 0; W == 0; L == 1
	--Pre index; Subtract Rm from Rn; Don't write back to Rn; Load from memory
	elseif opcode == 10 then
	--P == 1; U == 0; W == 1; L == 0
	--Pre index; Subtract Rm from Rn; Write back to Rn; Store to memory
	elseif opcode == 11 then
	--P == 1; U == 0; W == 1; L == 1
	--Pre index; Subtract Rm from Rn; Write back to Rn; Load from memory
	elseif opcode == 12 then
	--P == 1; U == 1; W == 0; L == 0
	--Pre index; Add Rm to Rn; Don't write back to Rn; Store to memory
	elseif opcode == 13 then
	--P == 1; U == 1; W == 0; L == 1
	--Pre index; Add Rm to Rn; Don't write back to Rn; Load from memory
	elseif opcode == 14 then
	--P == 1; U == 1; W == 1; L == 0
	--Pre index; Add Rm to Rn; Write back to Rn; Store to memory
	elseif opcode == 15 then
	--P == 1; U == 1; W == 1; L == 1
	--Pre index; Add Rm to Rn; Write back to Rn; Load from memory
	
	
	end
end

function arm_format7()
--Halfword Data Transfer: immediate offset
end

function arm_format8()
--Single Data Transfer
end

function arm_format9()
--Undefined
	return "Format 9 is undefined"
end

function arm_format10()
--Block Data Transfer
end

function arm_format11()
--Branch
end

function arm_format12()
--Coprocessor Data Transfer
end

function arm_format13()
--Coprocessor Data Operation
end

function arm_format14()
--Coprocessor Register Transfer
end

function arm_format15()
--Software Interupt
end






function asm_arm_module.do_thumb_instr(instruction, registers, definition)
	local cond = bit.rshift(bit.band(0xF0000000, instruction), 28)				--binary 1111 0000 0000 0000 0000 0000 0000 0000‬
	--We use this to check which format to use
	local bits_27_26_25_24 = bit.rshift(bit.band(0xF000000, instruction), 24)	--binary 0000 1111 0000 0000 0000 0000 0000 0000‬
	--This is used to set some flags A/S/U/B/W/L/S/N and CPOPC/CPOPCL
	local bits_23_22_21_20 = bit.rshift(bit.band(0xF00000, instruction), 20)	--binary 0000 0000 1111 0000 0000 0000 0000 0000
	--This is Rn/Rd/RdHi/CRn
	local bits_19_18_17_16 = bit.rshift(bit.band(0xF0000, instruction), 16)		--binary 0000 0000 0000 1111 0000 0000 0000 0000‬
	--This is Rd/Rn/RdLo/CRd
	local bits_15_14_13_12 = bit.rshift(bit.band(0xF000, instruction), 12)		--binary 0000‬ 0000 0000 0000 1111 0000 0000 0000
	--This is Rs/Rn/Offset/CP#
	local bits_11_10_9_8 = bit.rshift(bit.band(0xF00, instruction), 8)			--binary 0000 0000 0000 0000 0000 1111 0000 0000
	--Format differentiation
	local bits_7_6_5_4 = bit.rshift(bit.band(0xF0, instruction), 4)				--binary 0000 0000 0000 0000 0000 0000 1111 0000
	--This is Rm/Offset/CRm
	local bits_3_2_1_0 = bit.band(0xF, instruction)								--binary 0000 0000 0000 0000 0000 0000 0000 1111
	--This is same as Operand2/Offset (Data Processing/PSR Transfer & Single Data Transfer)
	local Operand2 = bit.band(0xFFF, instruction)								--binary 0000 0000 0000 0000 0000 1111 1111 1111
	local Opcode = bit.rshift(bit.band(instruction, 0x1E00000‬), 21)				--binary 0000 0001 1110 0000 0000 0000 0000 0000‬
	local bit7 = bit.rshift(bits_7_6_5_4, 3) % 2
	--bit 4 to check if undefined
	local bit4 = bits_7_6_5_4 % 2
	--This is bit 25
	local bit25 = bit.rshift(bits_27_26_25_24,1) % 2
	--This is bit 24
	local bit24 = bits_27_26_25_24 % 2
	local bit23 = bit.rshift(bits_23_22_21_20, 3) % 2
	local bit22 = bit.rshift(bits_23_22_21_20, 2) % 2
	local bit21 = bit.rshift(bits_23_22_21_20, 1) % 2
	--This is bit 20
	local bit20 = bits_23_22_21_20 % 2
	
	if bits_27_26_25_24 == 0 then
	--Format 1, 2, 3, 6, 7
	--Data Processing/PSR Transfer
	--Multiply
	--Multiply Long
	--Halfword Data Transfer: register offset
	--Halfword Data Transfer: immediate offset
	--"Multiply takes precedence over data processing instructions;
	--basically, if the shifter operand is invalid (bits 7 and 4 are both 1) then it's not a DP Instruction"
	--If bit6 == bit5 == 0, it is NEVER Halfword Data Transfer. Immediately treat it as Single Data Swap/Multiply/Multiply Long (Arm Manual A5.3, A5-34)
		if bits_7_6_5_4 == 9 then --binary 1001
			if bit23 == 0 then 
			--arm_format2(Cond, A, S, Rd, Rn, Rs, Rm, registers)
				arm_format2(cond, bit21, bit20, bits_19_18_17_16, bits_15_14_13_12, bits_11_10_9_8, bits_3_2_1_0, registers)
			else
			--arm_format3(Cond, U, A, S, RdHi, RdLo, Rs, Rm, registers)
				arm_format3(cond, bit22, bit21, bit20, bits_19_18_17_16, bits_15_14_13_12, bits_11_10_9_8, bits_3_2_1_0, registers)
			end
		elseif bits_7_6_5_4 > 9 then
			if bit22 == 0 then
				arm_format6()
			else
				arm_format7()
			end
		else
			-- arm_format1(Cond, I, Opcode, S, Rn, Rd, Operand2, registers)
			arm_format1(cond, bit25, Opcode, bit20, bits_19_18_17_16, bits_15_14_13_12, Operand2, registers)
		end
	elseif bits_27_26_25_24 == 1 then
	--Format 1, 4, 5, 6, 7
	--Data Processing/PSR Transfer
	--Single Data Swap
	--Branch and Exchange
	--Halfword Data Transfer: register offset
	--Halfword Data Transfer: immediate offset
	elseif bits_27_26_25_24 == 2 then
	--Data Processing/PSR Transfer
		arm_format1(cond, bit25, Opcode, bit20, bits_19_18_17_16, bits_15_14_13_12, Operand2, registers)
	elseif bits_27_26_25_24 == 3 then
	--Data Processing/PSR Transfer
		arm_format1(cond, bit25, Opcode, bit20, bits_19_18_17_16, bits_15_14_13_12, Operand2, registers)
	elseif bits_27_26_25_24 == 4 then
	--Single Data Transfer
		arm_format8()
	elseif bits_27_26_25_24 == 5 then
	--Single Data Transfer
		arm_format8()
	elseif bits_27_26_25_24 == 6 then
	--Single Data Transfer
	--Undefined
		arm_format8()
		arm_format9()
	elseif bits_27_26_25_24 == 7 then
	--Single Data Transfer
	--Undefined
		arm_format8()
		arm_format9()
	elseif bits_27_26_25_24 == 8 then
	--Block Data Transfer
		arm_format10()
	elseif bits_27_26_25_24 == 9 then
	--Block Data Transfer
		arm_format10()
	elseif bits_27_26_25_24 == 10 then
	--Branch
		arm_format11()
	elseif bits_27_26_25_24 == 11 then
	--Branch
		arm_format11()
	elseif bits_27_26_25_24 == 12 then
	--Coprocessor Data Transfer
		arm_format12()
	elseif bits_27_26_25_24 == 13 then
	--Coprocessor Data Transfer
		arm_format12()
	elseif bits_27_26_25_24 == 14 then
	--Coprocessor Data Operation
	--Coprocessor Register Transfer
		arm_format13()
		arm_format14()
	elseif bits_27_26_25_24 == 15 then
	--Software Interupt
		arm_format15()
	else
		error
	end
end
