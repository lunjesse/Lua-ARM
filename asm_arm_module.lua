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


local utility = require('utility')
local asm_arm_module = {}
local arm_table = {
--bits 27 to 20 = {bits 7 to 4 = {Operation, Shift function}}
--Use of table example: arm_table[bits_27_20][bits_7_6_5_4][1](Rs, Rn)
--http://imrannazar.com/ARM-Opcode-Map
[0] = {[0] = {utility.AND, shift_lli}, [1] = {utility.AND, shift_llr}, [2] = {utility.AND, shift_lri}, [3] = {utility.AND, shift_lrr}, [4] = {utility.AND, shift_ari}, [5] = {utility.AND, shift_arr}, [6] = {utility.AND, shift_rri}, [7] = {utility.AND, shift_rrr}, [8] = {utility.AND, shift_lli}},
[1] = {[0] = {utility.AND, shift_lli}, [1] = {utility.AND, shift_llr}, [2] = {utility.AND, shift_lri}, [3] = {utility.AND, shift_lrr}, [4] = {utility.AND, shift_ari}, [5] = {utility.AND, shift_arr}, [6] = {utility.AND, shift_rri}, [7] = {utility.AND, shift_rrr}, [8] = {utility.AND, shift_lli}},
[2] = {[0] = {utility.EOR, shift_lli}, [1] = {utility.EOR, shift_llr}, [2] = {utility.EOR, shift_lri}, [3] = {utility.EOR, shift_lrr}, [4] = {utility.EOR, shift_ari}, [5] = {utility.EOR, shift_arr}, [6] = {utility.EOR, shift_rri}, [7] = {utility.EOR, shift_rrr}, [8] = {utility.EOR, shift_lli}},
[3] = {[0] = {utility.EOR, shift_lli}, [1] = {utility.EOR, shift_llr}, [2] = {utility.EOR, shift_lri}, [3] = {utility.EOR, shift_lrr}, [4] = {utility.EOR, shift_ari}, [5] = {utility.EOR, shift_arr}, [6] = {utility.EOR, shift_rri}, [7] = {utility.EOR, shift_rrr}, [8] = {utility.EOR, shift_lli}},
[4] = {[0] = {utility.SUB, shift_lli}, [1] = {utility.SUB, shift_llr}, [2] = {utility.SUB, shift_lri}, [3] = {utility.SUB, shift_lrr}, [4] = {utility.SUB, shift_ari}, [5] = {utility.SUB, shift_arr}, [6] = {utility.SUB, shift_rri}, [7] = {utility.SUB, shift_rrr}, [8] = {utility.SUB, shift_lli}},
[5] = {[0] = {utility.SUB, shift_lli}, [1] = {utility.SUB, shift_llr}, [2] = {utility.SUB, shift_lri}, [3] = {utility.SUB, shift_lrr}, [4] = {utility.SUB, shift_ari}, [5] = {utility.SUB, shift_arr}, [6] = {utility.SUB, shift_rri}, [7] = {utility.SUB, shift_rrr}, [8] = {utility.SUB, shift_lli}},
[6] = {[0] = {utility.RSB, shift_lli}, [1] = {utility.RSB, shift_llr}, [2] = {utility.RSB, shift_lri}, [3] = {utility.RSB, shift_lrr}, [4] = {utility.RSB, shift_ari}, [5] = {utility.RSB, shift_arr}, [6] = {utility.RSB, shift_rri}, [7] = {utility.RSB, shift_rrr}, [8] = {utility.RSB, shift_lli}},
[7] = {[0] = {utility.RSB, shift_lli}, [1] = {utility.RSB, shift_llr}, [2] = {utility.RSB, shift_lri}, [3] = {utility.RSB, shift_lrr}, [4] = {utility.RSB, shift_ari}, [5] = {utility.RSB, shift_arr}, [6] = {utility.RSB, shift_rri}, [7] = {utility.RSB, shift_rrr}, [8] = {utility.RSB, shift_lli}},
[8] = {[0] = {utility.ADD, shift_lli}, [1] = {utility.ADD, shift_llr}, [2] = {utility.ADD, shift_lri}, [3] = {utility.ADD, shift_lrr}, [4] = {utility.ADD, shift_ari}, [5] = {utility.ADD, shift_arr}, [6] = {utility.ADD, shift_rri}, [7] = {utility.ADD, shift_rrr}, [8] = {utility.ADD, shift_lli}},
[9] = {[0] = {utility.ADD, shift_lli}, [1] = {utility.ADD, shift_llr}, [2] = {utility.ADD, shift_lri}, [3] = {utility.ADD, shift_lrr}, [4] = {utility.ADD, shift_ari}, [5] = {utility.ADD, shift_arr}, [6] = {utility.ADD, shift_rri}, [7] = {utility.ADD, shift_rrr}, [8] = {utility.ADD, shift_lli}},
[10] = {[0] = {utility.ADC, shift_lli}, [1] = {utility.ADC, shift_llr}, [2] = {utility.ADC, shift_lri}, [3] = {utility.ADC, shift_lrr}, [4] = {utility.ADC, shift_ari}, [5] = {utility.ADC, shift_arr}, [6] = {utility.ADC, shift_rri}, [7] = {utility.ADC, shift_rrr}, [8] = {utility.ADC, shift_lli}},
[11] = {[0] = {utility.ADC, shift_lli}, [1] = {utility.ADC, shift_llr}, [2] = {utility.ADC, shift_lri}, [3] = {utility.ADC, shift_lrr}, [4] = {utility.ADC, shift_ari}, [5] = {utility.ADC, shift_arr}, [6] = {utility.ADC, shift_rri}, [7] = {utility.ADC, shift_rrr}, [8] = {utility.ADC, shift_lli}},
[12] = {[0] = {utility.SBC, shift_lli}, [1] = {utility.SBC, shift_llr}, [2] = {utility.SBC, shift_lri}, [3] = {utility.SBC, shift_lrr}, [4] = {utility.SBC, shift_ari}, [5] = {utility.SBC, shift_arr}, [6] = {utility.SBC, shift_rri}, [7] = {utility.SBC, shift_rrr}, [8] = {utility.SBC, shift_lli}},
[13] = {[0] = {utility.SBC, shift_lli}, [1] = {utility.SBC, shift_llr}, [2] = {utility.SBC, shift_lri}, [3] = {utility.SBC, shift_lrr}, [4] = {utility.SBC, shift_ari}, [5] = {utility.SBC, shift_arr}, [6] = {utility.SBC, shift_rri}, [7] = {utility.SBC, shift_rrr}, [8] = {utility.SBC, shift_lli}},
[14] = {[0] = {utility.RSC, shift_lli}, [1] = {utility.RSC, shift_llr}, [2] = {utility.RSC, shift_lri}, [3] = {utility.RSC, shift_lrr}, [4] = {utility.RSC, shift_ari}, [5] = {utility.RSC, shift_arr}, [6] = {utility.RSC, shift_rri}, [7] = {utility.RSC, shift_rrr}, [8] = {utility.RSC, shift_lli}},
[15] = {[0] = {utility.RSC, shift_lli}, [1] = {utility.RSC, shift_llr}, [2] = {utility.RSC, shift_lri}, [3] = {utility.RSC, shift_lrr}, [4] = {utility.RSC, shift_ari}, [5] = {utility.RSC, shift_arr}, [6] = {utility.RSC, shift_rri}, [7] = {utility.RSC, shift_rrr}, [8] = {utility.RSC, shift_lli}},
[16] = nil,
[17] = {[0] = {utility.TST, shift_lli}, [1] = {utility.TST, shift_llr}, [2] = {utility.TST, shift_lri}, [3] = {utility.TST, shift_lrr}, [4] = {utility.TST, shift_ari}, [5] = {utility.TST, shift_arr}, [6] = {utility.TST, shift_rri}, [7] = {utility.TST, shift_rrr}, [8] = {utility.TST, shift_lli}},
[18] = nil,
[19] = {[0] = {utility.TEQ, shift_lli}, [1] = {utility.TEQ, shift_llr}, [2] = {utility.TEQ, shift_lri}, [3] = {utility.TEQ, shift_lrr}, [4] = {utility.TEQ, shift_ari}, [5] = {utility.TEQ, shift_arr}, [6] = {utility.TEQ, shift_rri}, [7] = {utility.TEQ, shift_rrr}, [8] = {utility.TEQ, shift_lli}},
[20] = nil,
[21] = {[0] = {utility.CMP, shift_lli}, [1] = {utility.CMP, shift_llr}, [2] = {utility.CMP, shift_lri}, [3] = {utility.CMP, shift_lrr}, [4] = {utility.CMP, shift_ari}, [5] = {utility.CMP, shift_arr}, [6] = {utility.CMP, shift_rri}, [7] = {utility.CMP, shift_rrr}, [8] = {utility.CMP, shift_lli}},
}

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

function shift_lli(Operand2, registers)
	--Logical Shift Left, Immediate
	--This is when bit 25 is 0, and bit 4 of Operand2 is 0
	--Take bits 11, 10, 9, 8, 7 of Operand2 as the 5 bit shift amount
	--Bits 6, 5 is the shift type. In this case, it's 00, hence it's logical left shift by a 5 bit integer
	--Technically op2_str is supposed to be just Rm if shift amount is 0
	local Rm_num = bit.band(Operand2, 0xF)	--binary 1111 (bits 3, 2, 1, 0)
	local Rs = bit.rshift(Operand2, 7)	--Immediate value to shift as (bits 11 to 7)
	local op2_str = "R"..Rm_num..", LSL #"..Rs
	return utility.LSL(registers[Rm_num], Rs, registers.CPSR), op2_str
end

function shift_llr(Operand2, registers)
	--Logical Shift Left, Register
	--This is when bit 25 is 0, and bit 4 of Operand2 is 1
	--Take bits 11, 10, 9, 8 of Operand2 as the register number to obtain the shift amount
	--Bits 6, 5 is the shift type. In this case, it's 00, hence it's logical left shift by a value in a register
	local Rm_num = bit.band(Operand2, 0xF)	--binary 1111 (bits 3, 2, 1, 0)
	local Rs_num = bit.rshift(Operand2, 8)	--Register number (bits 11 to 8)
	local op2_str = "R"..Rm_num..", LSL #"..Rs_num
	return utility.LSL(registers[Rm_num], registers[Rs_num], registers.CPSR), op2_str
end

function shift_lri(Operand2, registers)
	--Logical Shift Right, Immediate
	--This is when bit 25 is 0, and bit 4 of Operand2 is 0
	--Take bits 11, 10, 9, 8, 7 of Operand2 as the 5 bit shift amount
	--Bits 6, 5 is the shift type. In this case, it's 01, hence it's logical right shift by a 5 bit integer
	local Rm_num = bit.band(Operand2, 0xF)	--binary 1111 (bits 3, 2, 1, 0)
	local Rs = bit.rshift(Operand2, 7)	--Immediate value to shift as (bits 11 to 7)
	local op2_str = "R"..Rm_num..", LSR #"..Rs
	return utility.LSR1(registers[Rm_num], Rs, registers.CPSR), op2_str
end

function shift_lrr(Operand2, registers)
	--Logical Shift Right, Register
	--This is when bit 25 is 0, and bit 4 of Operand2 is 1
	--Take bits 11, 10, 9, 8 of Operand2 as the register number to obtain the shift amount
	--Bits 6, 5 is the shift type. In this case, it's 01, hence it's logical right shift by a value in a register
	local Rm_num = bit.band(Operand2, 0xF)	--binary 1111 (bits 3, 2, 1, 0)
	local Rs_num = bit.rshift(Operand2, 8)	--Register number (bits 11 to 8)
	local op2_str = "R"..Rm_num..", LSR #"..Rs_num
	return utility.LSR2(registers[Rm_num], registers[Rs_num], registers.CPSR), op2_str
end

function shift_ari(Operand2, registers)
	--Arithmetic Shift Right, Immediate
	--This is when bit 25 is 0, and bit 4 of Operand2 is 0
	--Take bits 11, 10, 9, 8, 7 of Operand2 as the 5 bit shift amount
	--Bits 6, 5 is the shift type. In this case, it's 10, hence it's arithmetic right shift by a 5 bit integer
	local Rm_num = bit.band(Operand2, 0xF)	--binary 1111 (bits 3, 2, 1, 0)
	local Rs = bit.rshift(Operand2, 7)	--Immediate value to shift as (bits 11 to 7)
	local op2_str = "R"..Rm_num..", ASR #"..Rs
	return utility.ASR1(registers[Rm_num], Rs, registers.CPSR), op2_str
end

function shift_arr(Operand2, registers)
	--Arithmetic Shift Right, Register
	--This is when bit 25 is 0, and bit 4 of Operand2 is 1
	--Take bits 11, 10, 9, 8 of Operand2 as the register number to obtain the shift amount
	--Bits 6, 5 is the shift type. In this case, it's 10, hence it's arithmetic right shift by a value in a register
	local Rm_num = bit.band(Operand2, 0xF)	--binary 1111 (bits 3, 2, 1, 0)
	local Rs_num = bit.rshift(Operand2, 8)	--Register number (bits 11 to 8)
	local op2_str = "R"..Rm_num..", ASR #"..Rs_num
	return utility.ASR2(registers[Rm_num], registers[Rs_num], registers.CPSR), op2_str
end

function shift_rri(Operand2, registers)
	--Rotate Right, Immediate
	--This is when bit 25 is 0, and bit 4 of Operand2 is 0
	--Take bits 11, 10, 9, 8, 7 of Operand2 as the 5 bit rotate amount
	--Bits 6, 5 is the shift type. In this case, it's 11, hence it's rotate right by a 5 bit integer
	local Rm_num = bit.band(Operand2, 0xF)	--binary 1111 (bits 3, 2, 1, 0)
	local Rs = bit.rshift(Operand2, 7)	--Immediate value to shift as (bits 11 to 7)
	local op2_str = "R"..Rm_num..", ROR #"..Rs
	return bit.ror(registers[Rm_num], Rs), op2_str
end

function shift_rrr(Operand2, registers)
	--Rotate Right, Register
	--This is when bit 25 is 0, and bit 4 of Operand2 is 1
	--Take bits 11, 10, 9, 8 of Operand2 as the register number to obtain the rotate amount
	--Bits 6, 5 is the shift type. In this case, it's 11, hence it's rotate right by a value in a register
	local Rm_num = bit.band(Operand2, 0xF)	--binary 1111 (bits 3, 2, 1, 0)
	local Rs_num = bit.rshift(Operand2, 8)	--Register number (bits 11 to 8)
	local op2_str = "R"..Rm_num..", ROR #"..Rs_num
	return utility.ROR2(registers[Rm_num], registers[Rs_num], registers.CPSR), op2_str
end

function shift_imm(Operand2, registers)
	--Rotate Right, Immediate 2.
	--This is when bit 25 is 1.
	--Bits 11, 10, 9, 8 of Operand2 is a value, which you multiply by 2, which specifies how much to rotate right
	--Bits 7 to 0 is the immediate value in which you apply the above to.
	--For the op2_str, use this:  #<immed_8>, <rotate_amount> where <rotate_amount> = 2 * rotate_imm.
	local rotate_imm = bit.rshift(Operand2, 8)	--(bits 11 to 8); Multiply by 2 at ROR3 instead
	local immed_8 = bit.band(Operand2, 0xFF)	--binary 1111 1111 (bits 7 to 0)
	local op2_str = "#"..immed_8..", "..rotate_imm*2
	return utility.ROR3(immed_8, rotate_imm, registers.CPSR), op2_str
end

function arm_format1(Cond, I, Opcode, S, bits_27_20, bits_7_6_5_4, Rn, Rd, Operand2, registers)
--Data Processing/PSR Transfer
--Rn is always first operand
--Rd is always destination
--I == 0 operand 2 is a shifted register. 1 means operand 2 is a rotated immediate offset
--Opcode is what determines the action to do
--S == 0 do not set condition code. 1 means set condition codes
--bits_27_20 and bits_7_6_5_4 are for the arm lookup table
--Operand2 are bits 0-11
--Binary 1111 or 1111 1111 respectively.
	local return_string = ""
	local S_str = (S == 1) and "S\t" or ""	--So it'll be eg. ADD EQ S; technically there's no space, but fuck that
	local cond_val, cond_str = cond(Cond, registers.CPSR)
	local shifted_op2, op2_str = arm_table[bits_27_20][bits_7_6_5_4][2](Operand2, registers)	--Apparently, you just give the Operand2 as is
	--[[If R15 (the PC) is used as an operand in a data processing instruction the register is
used directly.
The PC value will be the address of the instruction, plus 8 or 12 bytes due to instruction
prefetching. If the shift amount is specified in the instruction, the PC will be 8 bytes
ahead. If a register is used to specify the shift amount the PC will be 12 bytes ahead
]]--

	local temp_array = registers
	local Rn_value = registers[15]
	if Rn == 15 then
		--Shifted immediate is always even for bits 4-7.
		Rn_value = Rn_value + 8--check if 8 or 12 in GBA
	end
	local MRS_flag = (Opcode == 8 || Opcode == 10) and S == 0 and Rn == 0xF and Operand2 == 0
	local MSR1_flag = (Opcode == 9 || Opcode == 11) and S == 0 and Rn == 0x9 and Rd == 0xF and bit.band(Operand2,0xFF0) == 0
	local MSR2_flag = (Opcode == 9 || Opcode == 11) and S == 0 and Rn == 0x8 and Rd == 0xF
	local is_DataProc = (MRS_flag == false and MSR1_flag == false and MSR2_flag == false)
	
	--This applies to both Data Processing & PSR Transfer
	
	if is_DataProc == true then
	--<opcode>{cond}{S} Rd, <Op2>
	--<opcode>{cond} Rn, <Op2>
	--<opcode>{cond}{S} Rd, Rn, <Op2>
		temp_array[Rd], temp_array.CPSR = arm_table[bits_27_20][bits_7_6_5_4][1](registers[Rn], shifted_op2, registers.CPSR)
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

function arm_format6(Cond, P, U, bit22, W, L, Rn, Rd, bits_11_0, registers)
--Halfword Data Transfer: register offset
--Halfword Data Transfer: immediate offset
--ARM Manual A5.33
--[[
	P  U  22  W  L .. S H are bits 
	24 23 22 21 20 .. 6 5 respectively
	P (bit 24)
		P == 0
			Indicates the use of post-indexed addressing. The base register value is used for
			the memory address, and the offset is then applied to the base register value and
			written back to the base register.
		P == 1
			Indicates the use of offset addressing or pre-indexed addressing (the W bit
			determines which). The memory address is generated by applying the offset to
			the base register value.
	U (bit 23)
		U == 0
			Offset is subtracted from base
		U == 1
			OFfset is added to base
	(bit 22)
		bit 22 == 0
			Register offset/index
		bit 22 == 1
			Immediate offset/index
	W (bit 21)
		This thing has 2 meanings
		Additionally, if W == 1, Rn == 15, result is UNPREDICTABLE
		P == 0
			W == 0
				The W bit must be 0 or the instruction is UNPREDICTABLE
			W == 1
				UNPREDICTABLE
		P == 1
			W == 0
				base register is not updated. Treat as offset addressing
			w == 1
				address defined as base register + offset is written back to the base register. 
				This is called pre-indexed addressing, and is literally the same as offset addressing but you write back
	L, S, H (bits 20, 6, 5)
		L == 0
			Store byte or word
		L == 1
			Load byte or word
		S == 0, H == 0
			SWP (wrong format to use; give error)
		S == 0, H == 1
			Unsigned halfword LDRH/STRH
		S == 1, H == 0
			Signed byte LDRSB
		S == 1, H == 1
			Signed halfword LDRSH
		There are no STRB, STRSH; STRB uses the "Single Data Transfer" format, while STRSH is the same as STRH
	Plan:
		1. Check L, S, H bit to find out which action to use: LDR/STR(B).
		2. Check I bit to find out the offset
		3. Check U bit to determine if +/- offset
	]]--
	local SHbits = bit.rshift(bit.band(bits_11_0, 0x60),5)	--Keep only bits 6 and 5. 0x60 is binary 0110 0000
	local bits_11_10_9_8 = bit.rshift(bit.band(bits_11_0, 0xF00),8)	--Binary 1111 0000 0000
	local bits_3_2_1_0 = bit.band(bits_11_0, 0xF)	--Binary 1111
	local cond_val, cond_str = cond(Cond, registers.CPSR)
	local base = registers[Rn]
	base = (Rn == 15) and base + 8 or base	--If P bit is 0, or P is 1 and W is 1, this is UNPREDICTABLE
	local offset = 0
	local value = registers[Rd]
	local return_string = "SWP\t"	--assume opcode is 0 at start
	local offset_string = (U == 1) and "+" or "-"
	local addressing_mode_str = (P == 0) and "["..Rn..", " or "["..Rn.."], "
	--[[
	Return string holds LDR|STR{<cond>}{B}{T}	<Rd>, ..offset_string
	offset_string holds #+/-<offset_8>, #+/-<Rm>
	addressing_mode_str holds [<Rn>..offset_string], [<Rn>]..offset_string
	]]--
	local action = SWP
	local error1 = SHbits > 3	--not sure how that would occur, but ok
--Getting mixed results here; Arm Instruction Set pdf claims W == 1 and Rn == 15 should not be used, while the
--Arm Manual claims Rn == 15 alone is either unpredictable, or must +8/12. Seems to be instruction based
	local error2 = (W == 1 and Rn == 15)
	local error3 = (bits_3_2_1_0 == 15) --R15 should not be the register offset
	local error4 = (SHbits == 0)	--If S == H == 0, this is immediately treated as Single Data Swap/Multiply/Multiply Long
	local error5 = (bit.band(bits_11_0,0x90) ~= 0x90) --bits 7 and 4 are not 1; that's binary 1001 0000
	local error6 = (P == 0 and W == 1)	--W must be 0 if P is 0 
	
	
--[[Only LDRH/STRH/LDRSB/LDRSH are legal; STR, STRB, STRSH, STRSB are not allowed in this format
(Arm Manual A5.3, A5-34)
"Signed stores If S ==1 and L == 0, apparently indicating a signed store instruction, the encoding along
with the H-bit is used to support the LDRD (H == 0) and STRD (H == 1) instructions. "
That is for ARMv5TE
So if this occurs, ignore it, and use H bit to determine the instruction.
Signed bytes and halfwords can be stored with the same STRB and STRH instructions as are
used for unsigned quantities, so no separate signed store instructions are provided.
]]--
	--Determine which action to use: LDR/STR(B)
	if error1 == true then	--how?
		return registers, "Format 6: Invalid S H flags; bits 5 and 6 over 3"
	end
	if error2 == true then
		return registers, "Format 6: STR/STRB/STRSH/STRSB not allowed" 
	end
	if error3 == true then
		return registers, "Format 6: Bits 0 to 3 must not be 15 if register offset" 
	end
	if error4 == true then
		return registers, "Format 6: Wrong addressing mode for SWP; bits 5 and 6 must not be 0 simultaneously" 
	end
	if error5 == true then
		return registers, "Format 6: Wrong addressing mode for MUL; bits 4 and 7 must be 1" 
	end
	if error6 == true then
		return registers, "Format 6: W must be 0 if P is 0" 
	end
	if L == 0 then
		if SHbits == 0 then	--SWP
			return_string = "Error: Wrong addressing mode: SWP"
		elseif SHbits == 1 then 
			action = utility.STRH
			return_string = "STR"..cond_str.."H"
		elseif SHbits > 1 then --Load/Store doubleword, but not supported in ARMv4
		--Also, STRB, STRSH are the same as addressing mode 2 and STRH, so not supported here
			return_string = "Error: Doubleword not supported in ARMv4"
		end
	else
		if SHbits == 0 then	
			return_string = "Error: Wrong addressing mode: SWP"
		elseif SHbits == 1 then --Load unsigned halfword
			action = utility.LDRH
			return_string = "LDR"..cond_str.."H"
		elseif SHbits == 2 then --Load signed byte
			action = utility.LDRSB
			return_string = "LDR"..cond_str.."SB"
		elseif SHbits == 3 then --Load signed halfword
			action = utility.LDRSH
			return_string = "LDR"..cond_str.."SH"
		end
	end
	return_string = return_string.."\t"..Rd..", "
	--Determine how the offset is calculated
	if bit22 == 0 then	--register offset
		if bits_11_10_9_8 > 0 then
			console.log("Warning. Bits 8 to 11 are not 0")
		end
		offset = registers[bits_3_2_1_01]
		offset_string = offset_string..bits_3_2_1_0
	else	--immediate offset
	--bits 8 to 11 shifted to the left by 4, plus bits 0 to 3 for offset
		offset = bits_11_10_9_8 * 2^8 + bits_3_2_1_0
		offset_string = offset_string..offset
	end
	offset = (U == 1) and offset or -1*offset
	addressing_mode_str = addressing_mode_str..shift_str
	if P == 0 then	--Post index
		--W should never be 1 here; ie. no write back
		temp_array[Rd] = action(base, 0, value)	--Don't implement writeback until later
	else	--Preindex/Offset addressing
		temp_array[Rd] = action(base, offset, value)	--Don't implement writeback until later
		addressing_mode_str = addressing_mode_str.."]"
		if W == 0 then
			temp_array[Rd] = base
		else
			temp_array[Rd] = base + offset
			addressing_mode_str = addressing_mode_str.."!"
		end
	end
	return_string = return_string..addressing_mode_str
	return temp_array, return_string
end

function arm_format7(Cond, I, P, U, W, L, Rn, Rd, Offset12, registers)
--Single Data Transfer
	local temp_array = registers
	local bits_11_4 = bit.rshift(Offset12, 4)	--shift amount
	local bits_3_2_1_0 = bit.band(Offset12, 0xF)	--Rm, if register offset
	local return_string = ""
	local cond_val, cond_str = cond(Cond, registers.CPSR)
	local shift_str = U == 1 and "+" or "-"	--check I bit later I guess
	local addressing_mode_str = (P == 0) and "["..Rn..", " or "["..Rn.."], "
	--[[Addressing mode string has 2 forms based on P bit
		P == 0 (Post indexing)
			[<Rn>, #+/-<offset_12>](!)
			[<Rn>, #+/-<Rm>](!)
			[<Rn>, #+/-<Rm>, <shift> #<shift_imm>](!)
		P == 1 (Pre indexing or offset addressing)
			[<Rn>], #+/-<offset_12>
			[<Rn>], #+/-<Rm>
			[<Rn>], #+/-<Rm>, <shift> #<shift_imm>
	Return string holds LDR|STR{<cond>}{B}{T}	<Rd>, ..addressing_mode_str
	Shift_str holds #+/-<offset_12>, #+/-<Rm>, #+/-<Rm>, <shift> #<shift_imm>
	addressing_mode_str holds [<Rn>..shift_str], [<Rn>]..shift_str
	]]--
	--[[
	I  P  U  B  W  L are bits 
	25 24 23 22 21 20 respectively
	I (bit 25)
		According to ARM Manual A5-19, 3 cases:
		I == 0
			Immediate offset
		I == 1
		Register offset with no shifts
		Register offset with shifts
	P (bit 24)
		P == 0
			Indicates the use of post-indexed addressing. The base register value is used for
			the memory address, and the offset is then applied to the base register value and
			written back to the base register.
		P == 1
			Indicates the use of offset addressing or pre-indexed addressing (the W bit
			determines which). The memory address is generated by applying the offset to
			the base register value.
	U (bit 23)
		U == 0
			Offset is subtracted from base
		U == 1
			OFfset is added to base
	B (bit 22)
		B == 0
			LDR/STR Word
		B == 1
			LDR/STR Byte
	W (bit 21)
		This thing has 2 meanings
		Additionally, if W == 1, Rn == 15, result is UNPREDICTABLE
		P == 0
			W == 0
				the instruction is LDR, LDRB, STR or STRB and a normal memory access is performed.
			W == 1
				the instruction is LDRBT, LDRT, STRBT or STRT and an unprivileged (User mode) memory access is performed.
		P == 1
			W == 0
				base register is not updated. Treat as offset addressing
			w == 1
				address defined as base register + offset is written back to the base register. 
				This is called pre-indexed addressing, and is literally the same as offset addressing but you write back
	L (bit 20)
		L == 0
			Store byte or word
		L == 1
			Load byte or word
	Plan:
		1. Check L and B bit to find out which action to use: LDR/STR(B).
		2. Check I bit to find out the offset
		3. Check U bit to determine if +/- offset
		4. Check P bit to determine if Post or Pre index
	]]--
	--Case 1:  Load and Store Word or Unsigned Byte - Immediate offset
	--[<Rn>, #+/-<offset_12>]
	local base = registers[Rn]
	base = (Rn == 15) and base + 8 or base	--If P bit is 0, or P is 1 and W is 1, this is UNPREDICTABLE
	local offset = 0
	local value = registers[Rd]	--This seems to be it.
	local action = utility.LDR	--default I guess?
	--Determine which action to use: LDR/STR(B)
	if L == 0 then
		if B == 0 then
			action = utility.STR
			return_string = "STR"..cond_str
		else
			action = utility.STRB
			return_string = "STR"..cond_str.."B"
		end
	else
		if B == 0 then
			action = utility.LDR
			return_string = "LDR"..cond_str
		else
			action = utility.LDRB
			return_string = "LDR"..cond_str.."B"
		end
	end
	if P == 0 and W == 1 then return_string = return_string..cond.."T" end
	return_string = return_string.."\t"..Rd..", "
	--Determine how the offset is calculated
	if I == 0 then	--Shift immediate
	--ARM Manual A5-20 (W == 0), A5-24 (W == 1)
		offset = Offset12
		shift_str = "#"..shift_str..Offset12
	else
		local Rm = registers[bits_3_2_1_0]
		if bits_11_4 == 0 then	--we use a different case instead of offset of shifted 0 since different text
			--Register offset
			offset = Rm
			shift_str = shift_str..Rm
		else
			--ARM Manual A5-26
			--Don't seem to change flags
			--Scaled register offset
			shift_str = shift_str..Rm..", "
			local shift_imm = bit.rshift(Offset12, 7)	--bits 7 to 11
			local shift_type = bit.band(bit.rshift(Offset12, 5), 3) --bits 5,6
			if shift_type == 0 then
			--LSL: 0 to 31, encoded directly in the shift_imm field.
				offset = bit.lshift(Rm, shift_imm)
				shift_str = shift_str.."LSL #"..shift_imm
			elseif shift_type == 1 then
			--LSR: 1 to 32. A shift amount of 32 is encoded as shift_imm == 0. Other shift
			--amounts are encoded directly.
				offset = shift_imm == 0 and 0 or bit.rshift(Rm, shift_imm)
				shift_str = shift_str.."LSR #"..shift_imm
			elseif shift_type == 2 then
			--ASR: 1 to 32. A shift amount of 32 is encoded as shift_imm == 0. Other shift
			--amounts are encoded directly.
				if shift_imm == 0 then	--ASR #32 apparently
					offset = bit.check(Rm, 31) and 0xFFFFFFFF or 0
				else
					offset = bit.arshift(Rm, shift_imm)
				end
				shift_str = shift_str.."ASR #"..shift_imm
			else
			--ROR: 1 to 31, encoded directly in the shift_imm field. (The shift_imm == 0
			--encoding is used to specify the RRX option.)
				if shift_imm == 0 then --RRX
					--implement RRX
					--shifter_operand = (C Flag Logical_Shift_Left 31) OR (Rm Logical_Shift_Right 1)
					--shifter_carry_out = Rm[0]
					--[[If I understand correctly:
					1. Get bit 0 of Rm
					2. Logical shift right of Rm by 1
					3. Place 1) into bit 31 of result 2)
					]]--
					local temp = Rm % 2 --This is same as check first bit. Probably
					offset = bit.rshift(Rm, 1)
					offset = temp == 1 and bit.set(offset, 31) or offset
					shift_str = shift_str.."RRX"
				else
					offset = bit.ror(Rm, shift_imm)
					shift_str = shift_str.."ROR #"..shift_imm
				end
			end
		end
	end --End I bit check for offset
	--Determine if +/- offset
	offset = (U == 1) and offset or -1*offset
	addressing_mode_str = addressing_mode_str..shift_str
	if P == 0 then	--Post index
		temp_array[Rd] = action(base, 0, value)	--Don't implement writeback until later
		temp_array[Rd] = base+offset	--Seems to always write back; W bit just determines "T"
	else	--Preindex/Offset addressing
		temp_array[Rd] = action(base, offset, value)	--Don't implement writeback until later
		addressing_mode_str = addressing_mode_str.."]"
		if W == 0 then
			temp_array[Rd] = base
		else
			temp_array[Rd] = base + offset
			addressing_mode_str = addressing_mode_str.."!"
		end
	end
	return_string = return_string..addressing_mode_str
	return temp_array, return_string
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



function asm_arm_module.do_instr(instruction, registers, definition)
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
