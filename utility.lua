local utility = {}
--Constants for flags
--CPSR is status register
--Usage: set_flag(r,1,1,1,1) example
--[[https://nintenfo.github.io/repository/webmirrors/techinfo.html
	Bit   Expl.
  31    N - Sign Flag       (0=Not Signed, 1=Signed)               ;\
  30    Z - Zero Flag       (0=Not Zero, 1=Zero)                   ; Condition
  29    C - Carry Flag      (0=Borrow/No Carry, 1=Carry/No Borrow) ; Code Flags
  28    V - Overflow Flag   (0=No Overflow, 1=Overflow)            ;/
  27    Q - Sticky Overflow (1=Sticky Overflow, ARMv5TE and up only)
  26-8  Reserved            (For future use) - Do not change manually!
  7     I - IRQ disable     (0=Enable, 1=Disable)                     ;\
  6     F - FIQ disable     (0=Enable, 1=Disable)                     ; Control
  5     T - State Bit       (0=ARM, 1=THUMB) - Do not change manually!; Bits
  4-0   M4-M0 - Mode Bits   (See below)                               ;/
]]--
local flags = {}
flags.N = 31
flags.Z = 30
flags.C = 29
flags.V = 28
flags.Q = 27
flags.I = 7
flags.F = 6
flags.T = 5
function utility.set_flag(CPSR, flags)
	for k, v in pairs(flag) do
	--k should be the index of a sparse table, and v should be true/false
		CPSR = v == true and bit.set(CPSR,k) or bit.clear(CPSR, k)
	end
	return CPSR;
end

--since bizhawk hates the 0x8/0x3/0x4 part, remove it
function utility.load_biz_addr(addr, size)
	local destination
	local read_memory = memory.read_u32_le	--default
	if size == 8 then
		read_memory = memory.read_u8
	elseif size == 16 then
		read_memory = memory.read_u16_le
	elseif size == 24 then
		read_memory = memory.read_u24_le
	end
	if addr < 0x01000000 and addr > 0x00000000 then
		destination = read_memory(addr, "BIOS")
	elseif addr < 0x03000000 and addr > 0x02000000 then
		destination = read_memory(addr - 0x02000000,"EWRAM")
	elseif addr < 0x04000000 and addr > 0x03000000 then
		destination = read_memory(addr - 0x03000000,"IWRAM")
	elseif addr < 0x05000000 and addr > 0x04000000 then
		destination = read_memory(addr - 0x04000000,"System Bus")
	elseif addr < 0x09000000 and addr > 0x08000000 then
		destination = read_memory(addr - 0x08000000,"ROM")
	end
	return destination
end

function utility.write_biz_addr(addr, value, size)
	local write_memory = memory.write_u32_le	--default
	if size == 8 then
		write_memory = memory.write_u8
	elseif size == 16 then
		write_memory = memory.write_u16_le
	elseif size == 24 then
		write_memory = memory.write_u24_le
	end
	if addr < 0x01000000 and addr > 0x00000000 then
		-- dont touch BIOS
		-- write_memory(addr, value, "BIOS")
	elseif addr < 0x03000000 and addr > 0x02000000 then
		write_memory(addr - 0x02000000, value, "EWRAM")
	elseif addr < 0x04000000 and addr > 0x03000000 then
		write_memory(addr - 0x03000000, value, "IWRAM")
	elseif addr < 0x05000000 and addr > 0x04000000 then
		write_memory(addr - 0x04000000, value, "System Bus")
	elseif addr < 0x09000000 and addr > 0x08000000 then
		--dont write in ROM
		-- write_memory(addr - 0x08000000, value, "ROM")
	end
end

function borrow_from(A, B)
--[[
BorrowFrom
Returns 1 if the subtraction specified as its parameter caused a borrow (the true result is less than 0, 
where the operands are treated as unsigned integers), and returns 0 in all other cases. This delivers further
information about a subtraction which occurred earlier in the pseudo-code. The subtraction is not repeated.
]]--
	return B > A and 1 or 0
end

function carry_from(A, B)
--[[
CarryFrom
Returns 1 if the addition specified as its parameter caused a carry (true result is bigger than 23^2−1, 
where the operands are treated as unsigned integers), and returns 0 in all other cases. This delivers further
information about an addition which occurred earlier in the pseudo-code. The addition is not repeated.
]]--
	return A+B > 4294967295
end

function overflow_from_add(A, B)
--[[
OverflowFrom
Returns 1 if the addition or subtraction specified as its parameter caused a 32-bit signed overflow. 
Addition generates an overflow if both operands have the same sign (bit[31]), and the sign of the result is different to the sign of both operands. 
Subtraction causes an overflow if the operands have different signs, and the first operand and the result have different signs.
This delivers further information about an addition or subtraction which occurred earlier in the pseudo-code.
The addition or subtraction is not repeated.
]]--
--[[Truth table
	A	B	A+B	V
	0	0	0	0
	0	0	1	1
	0	1	0	0
	0	1	1	0
	1	0	0	0
	1	0	1	0
	1	1	0	1
	1	1	1	0
	Literally 2 cases possible for overflow
]]--
	local A31 = bit.check(A, 31)
	local B31 = bit.check(B, 31)
	local AB31 = bit.check(A+B, 31)
	return (A31 == B31 and A31 ~= AB31)
end	
	
function overflow_from_sub(A, B)
--[[Truth table
	A	B	A-B	V
	0	0	0	0
	0	0	1	0
	0	1	0	0
	0	1	1	1
	1	0	0	1
	1	0	1	0
	1	1	0	0
	1	1	1	0
	Literally 2 cases possible for overflow
]]--
	local A31 = bit.check(A, 31)
	local B31 = bit.check(B, 31)
	local AB31 = bit.check(A-B, 31)
	return (A31 ~= B31 and A31 ~= AB31)
end

function ADC(Rs, Rn, Carry, CPSR, Sub)
	--Insert a boolean to determine if subtract or not. Default false
	--we need carry as well, since some instructions ignore carry flag
	local result = (Rs + Rn + Carry)
	local sum32 = result % 4294967296
	local flag = {}
	flag[flags.N] = bit.check(sum32, flags.N)
	flag[flags.Z] = (sum32 == 0)
	flag[flags.C] = carry_from(Rs, Rn + Carry)
	--Can't seem to figure out how to implement SUB as ADD using ADC, so just using a bool to check which version of overflow to use
	if Sub == true then
		flag[flags.V] = overflow_from_sub(Rs, bit.bnot(Rn))
	else
		flag[flags.V] = overflow_from_add(Rs, Rn + Carry)
	end
	return sum32, utility.set_flag(CPSR, flag)
end

--DATA PROCESSING OPERANDS
--Function(Operand1, Operand2, CPSR)
--ARM Manual A5-9, A5-10, A7-64, A7-66 (THUMB)
function utility.LSL(Rs, Offset, CPSR)
--Imagine that the shift happens with a double-wide register, and then at the end we cut off the lower 32 bits to get the new value, and then the next bit onward is the carry flag
--diagram https://www.csee.umbc.edu/courses/undergraduate/313/spring04/burt_katz/lectures/Lect06/shift.html
	--There are 2 cases. LSL immediate offset of 5 bits, and LSL register offset using the least significant byte (bits 7 to 0). 
	--We first mask the Offset into an 8 bit number; this won't change anything if it was the 5 bit offset
	Offset = bit.band(0xFF, Offset)
	local result = nil
	local flag = {}	--For CPSR update
	--LSL immediate
	if Offset == 0 then
		flag[flags.C] = bit.check(CPSR, flags.C)	--C flag unaffected if 0 shift
		result = Rs
	elseif Offset < 32 then 
		flag[flags.C] = bit.check(Rs, 32-Offset)
		result = bit.lshift(Rs, Offset)
	--LSL register
	elseif Offset == 32 then
		flag[flags.C] = bit.check(Rs, 0)
		result = 0
	else	--Greater than 32
		C = 0
		result = 0
	end
	flag[flags.N] = bit.check(result, flags.N)
	flag[flags.Z] = (result == 0)
	return result, utility.set_flag(CPSR, flag)
end

--ARM Manual A5-11, A7-68 (THUMB)
function utility.LSR1(Rs, Offset, CPSR)
	--There are 2 cases. LSR immediate offset of 5 bits, and LSR register offset using the least significant byte (bits 7 to 0). 
	--In this case, it's immediate offset. An offset of 0 indicates logical right shift of 32 rather than 0; 
	--instead, LSR #0 is converted to LSL #0. This applies to ASR and ROR as well
	local result = nil
	local flag = {}	--For CPSR update
	if Offset == 0 then
		flag[flags.C] = bit.check(Rs, flags.N)
		result = 0
	else
		flag[flags.C] = bit.check(Rs, Offset-1)
		result = bit.rshift(Rs, Offset)
	end
	flag[flags.N] = bit.check(result, flags.N)
	flag[flags.Z] = (result == 0)
	return result, utility.set_flag(CPSR, flag)
end

--ARM Manual A5-12, A7-70 (THUMB)
function utility.LSR2(Rd, Rs, CPSR)
	--There are 2 cases. LSR immediate offset of 5 bits, and LSR register offset using the least significant byte (bits 7 to 0). 
	--In this case, it's register offset. Unlike LSR1, this does allow LSR #0 to occur.
	--We first mask the Offset (Rs, in this case) into an 8 bit number
	Rs = bit.band(0xFF, Rs)
	local result = nil
	local flag = {}	--For CPSR update
	if Rs == 0 then
		flag[flags.C] = bit.check(CPSR, flags.C)	--C flag unaffected if 0 shift
		result = Rd
	elseif Rs < 32 then
		flag[flags.C] = bit.check(Rd, Rs-1)
		result = bit.rshift(Rd, Rs)
	elseif Rs == 32 then
		flag[flags.C] = bit.check(Rd, flags.N)
		result = 0
	else	--Greater than 32
		flag[flags.C] = false
		result = 0
	end
	flag[flags.N] = bit.check(result, flags.N)
	flag[flags.Z] = (result == 0)
	return result, utility.set_flag(CPSR, flag)
end

--ARM Manual A5-13, A7-15 (THUMB)
function utility.ASR1(Rm, Offset, CPSR)
	--There are 2 cases. ASR immediate offset of 5 bits, and ASR register offset using the least significant byte (bits 7 to 0). 
	--In this case, it's immediate offset. An offset of 0 indicates arithmetic right shift of 32 rather than 0; 
	--instead, ASR #0 is converted to LSL #0. This applies to LSR and ROR as well
	local result = nil
	local flag = {}	--For CPSR update
	if Offset == 0 then
		flag[flags.C] = bit.check(Rm, flags.N)
		if flag[flags.C] == false then
			result = 0
		else	--bit 31 of Rm is 1
			result = 0xFFFFFFFF
		end
	else
		flag[flags.C] = bit.check(Rm, Offset-1)
		result = bit.arshift(Rm, Offset)
	end
	flag[flags.N] = bit.check(result, flags.N)
	flag[flags.Z] = (result == 0)
	return result, utility.set_flag(CPSR, flag)
end

--ARM Manual A5-14, A7-17 (THUMB)
function utility.ASR2(Rd, Rs, CPSR)
	--There are 2 cases. ASR immediate offset of 5 bits, and ASR register offset using the least significant byte (bits 7 to 0). 
	--In this case, it's register offset. Unlike ASR1, this does allow ASR #0 to occur.
	--We first mask the Offset (Rs, in this case) into an 8 bit number
	Rs = bit.band(0xFF, Rs)
	local result = nil
	local flag = {}	--For CPSR update
	if Rs == 0 then
		flag[flags.C] = bit.check(CPSR, flags.C)	--C flag unaffected if 0 shift
		result = Rd
	elseif Rs < 32 then
		flag[flags.C] = bit.check(Rd, Rs-1)
		result = bit.arshift(Rs, Rs)
	else --Greater than 32
		flag[flags.C] = bit.check(Rd, flags.N)
		if flag[flags.C] == false then
			result = 0
		else	--bit 31 of Rd is 1
			result = 0xFFFFFFFF
		end
	end
	flag[flags.N] = bit.check(result, flags.N)
	flag[flags.Z] = (result == 0)
	return result, utility.set_flag(CPSR, flag)
end

--ARM Manual pA7-92
function utility.ROR(Rd, Rs, CPSR)
	--THUMB version
	--Rotate by the least significant byte (bits 7 to 0).
	--We first mask the Offset (Rs, in this case) into an 8 bit number
	Rs = bit.band(0xFF, Rs)
	local result = nil
	local flag = {}	--For CPSR update
	if Rs == 0 then
		--C flag unaffected if 0 rotate
		result = Rd
	else
		--Apparently we now only care about bits 4 to 0 for the else
		Rs = bit.band(0xF, Rs)
		if Rs == 0 then 
			flag[flags.C] = bit.check(Rd, flags.N)
			result = Rd
		else	--Rs[4:0] > 0
			flag[flags.C] = bit.check(Rd, Rs-1)
			result = bit.ror(Rd, Rs)
		end
	end
	flag[flags.N] = bit.check(result, flags.N)
	flag[flags.Z] = (result == 0)
	return result, utility.set_flag(CPSR, flag)
end

--ARM Manual A5-15, A5-17 (RRX)
function utility.ROR1(Rm, Offset, CPSR)
	--This is not used in THUMB; instead it is for ARM, data processing
	--There are 3 cases. ROR immediate offset of 8 bits, ROR immediate offset of 5 bits, and ROR register offset using the least significant byte (bits 7 to 0). 
	--Bit 25 is 0, so in this case, it's either immediate offset of 5 bits, or register offset using the least significant byte. 
	--Bit 4 is 0, so it's immediate offset of 5 bits
	--"If R15 is specified as register Rm or Rn, the value used is the address of the current instruction plus 8"
	local result = nil
	local flag = {}	--For CPSR update
	if Offset == 0 then
		--implement RRX
		--shifter_operand = (C Flag Logical_Shift_Left 31) OR (Rm Logical_Shift_Right 1)
		--shifter_carry_out = Rm[0]
		--[[If I understand correctly:
		1. Get bit 0 of Rm
		2. Logical shift right of Rm by 1
		3. Place 1) into bit 31 of result 2)
		]]--
		local temp = Rm % 2 --This is same as check first bit. Probably
		result = bit.rshift(Rm, 1)
		result = temp == 1 and bit.set(result, flags.N) or result
	else
		result = bit.ror(Rs, Offset)
		flag[flags.C] = bit.check(Rm, Offset-1)
	end
	flag[flags.N] = bit.check(result, flags.N)
	flag[flags.Z] = (result == 0)
	return result, utility.set_flag(CPSR, flag)
end

--ARM Manual A5-16
function utility.ROR2(Rm, Rs, CPSR)
	--This is not used in THUMB; instead it is for ARM, data processing
	--There are 3 cases. ROR immediate offset of 8 bits, ROR immediate offset of 5 bits, and ROR register offset using the least significant byte (bits 7 to 0). 
	--Bit 25 is 0, so in this case, it's either immediate offset of 5 bits, or register offset using the least significant byte. 
	--Bit 4 is 1, so it's register offset using the least significant byte. 
	--We first mask the Offset (Rs, in this case) into an 8 bit number
	--"Specifying R15 as register Rd, register Rm, register Rn, or register Rs has UNPREDICTABLE results."
	Rs = bit.band(0xFF, Rs)
	local result = nil
	local flag = {}	--For CPSR update
	if Rs == 0 then
		result = Rm
		flag[flags.C] = bit.check(CPSR, flags.C)	--C flag unaffected if 0 rotate
	else
		Rs = bit.band(0x1F, Rs) --Only care about first 5 bits
		if Rs == 0 then
			result = Rm
			flag[flags.C] = bit.check(Rm, flags.N)	--Differnt than above
		else	--Bits 0-4 are not 0
			result = bit.ror(Rm, Rs)
			flag[flags.C] = bit.check(Rm, Rs-1)
		end
	end
	flag[flags.N] = bit.check(result, flags.N)
	flag[flags.Z] = (result == 0)
	return result, utility.set_flag(CPSR, flag)
end

--ARM Manual A5-6
function utility.ROR3(immed_8, rotate_imm, CPSR)
	--This is not used in THUMB; instead it is for ARM, data processing
	--There are 3 cases. ROR immediate offset of 8 bits, ROR immediate offset of 5 bits, and ROR register offset using the least significant byte (bits 7 to 0). 
	--Bit 25 is 1, so in this case, it's immediate offset of 8 bits. 
	--Bits 11-8 are the amount to rotate, and bits 7-0 are the immediate offset
	--"If R15 is specified as register Rn, the value used is the address of the current instruction plus eight"
	--The above line should be done BEFORE you give ROR3 the numbers in a different function
	local result = nil
	local flag = {}	--For CPSR update
	if rotate_imm == 0 then
		flag[flags.C] = bit.check(CPSR, flags.C)	--C flag unaffected if 0 rotate
	else
		result = bit.ror(immed_8, rotate_imm*2)
		flag[flags.C] = bit.check(result, flags.N)	--Set this to bit 31 of the shifted number instead of the original
	end
	flag[flags.N] = bit.check(result, flags.N)
	flag[flags.Z] = (result == 0)
	return result, utility.set_flag(CPSR, flag)
end

--ARM Manual A7-14
function utility.AND(Rd, Rs, CPSR)
	local result = bit.band(Rd,Rs)
	local flag = {}	--For CPSR update
	flag[flags.N] = bit.check(result, flags.N)
	flag[flags.Z] = (result == 0)
	return result, utility.set_flag(CPSR, flag)
end

--ARM Manual A4-32, A7-43
function utility.EOR(Rd, Rs, CPSR)
	--C flag generated by the shifter
	local result = bit.bxor(Rd, Rs)
	local flag = {}	--For CPSR update
	flag[flags.N] = bit.check(result, flags.N)
	flag[flags.Z] = (result == 0)
	return result, utility.set_flag(CPSR, flag)
end

--ARM Manual A4-209
function utility.SUB(Rs, Rn, CPSR)
--Subtract contents of Rn from contents of Rs. Ie. Rs - Rn
	return ADC(Rs, bit.bnot(Rn), 1, CPSR, true)
end

--ARM Manual A4-115
function utility.RSB(Rs, Rn, CPSR)
--Subtract contents of Rs from contents of Rn. Ie. Rn - Rs
	return ADC(Rn, bit.bnot(Rs), 1, CPSR, true)
end

--ARM Manual A4-6 (ARM), A7-5, A7-6, A7-7, A7-8, A7-9, A7-10, A7-11, A7-12 (THUMB)
function utility.ADD(Rs, Rn, CPSR)
	return ADC(Rs, Rn, 0, CPSR, false)
end

--This version is what thumb/arm module use. maybe
--ARM Manual A4-4 (ARM),  A7-4
function utility.ADC(Rs, Rn, CPSR)
	local C = bit.check(CPSR, flags.C) and 1 or 0
	return ADC(Rs, Rn, C, CPSR, false)
end

--ARM Manual A4-125 (ARM), A7-94
function utility.SBC(Rs, Rn, CPSR)
	local C = bit.check(CPSR, flags.C) and 0 or -1
	return ADC(Rs, bit.bnot(Rn), C, CPSR, true)
end

--ARM Manual A4-117
function utility.RSC(Rs, Rn, CPSR)
--Subtract contents of Rs from contents of Rn, with NOT carry. Ie. Rn - Rs
	local C = bit.check(CPSR, flags.C) and 0 or -1	--NOT C flag; Also needs to be - C, which you can do by making C negative
	return ADC(Rn, bit.bnot(Rs), C, CPSR, true)
end

--ARM Manual A4-230 (ARM), A7-122
function utility.TST(Rd, Rs, CPSR)
--From  ARM manual: Test (register) performs a logical AND operation on a register value and an optionally-shifted register value.
--It updates the condition flags based on the result, and discards the result.
	--C flag generated by the shifter
	local _, CPSR2 = utility.AND(Rd, Rs, CPSR)
	return Rd, CPSR2	--Need to return Rd to make it same as other functions for lookup table
end

--ARM Manual A4-228
function utility.TEQ(Rd, Rs, CPSR)
--From ARM manual: TEQ (Test Equivalence) compares a register value with another arithmetic value. The condition flags are
-- updated, based on the result of logically exclusive-ORing the two values, so that subsequent instructions can
--be conditionally executed.
	--C flag generated by the shifter
	local _, CPSR2 = utility.EOR(Rd, Rs, CPSR)
	return Rd, CPSR2	--Need to return Rd to make it same as other functions for lookup table
end

--ARM Manual A4-28 (ARM), A7-35, A7-36, A7-37
function utility.CMP(Rd, Rs, CPSR)
--From ARM manual: Compare (immediate) subtracts an immediate value from a register value. 
--It updates the condition flags based on the result, and discards the result.
--This is also used for format 5 in THUMB
	local _, CPSR2 = utility.SUB(Rd, Rs, CPSR)
	return Rd, CPSR2	--Need to return Rd to make it same as other functions for lookup table
end

--ARM Manual A4-26 (ARM), A7-34
function utility.CMN(Rd, Rs, CPSR)
--From ARM manual: Compare Negative (register) adds a register value and an optionally-shifted register value. 
--It updates the condition flags based on the result, and discards the result.
	local _, CPSR2 = utility.ADD(Rd, Rs, CPSR)
	return Rd, CPSR2	--Need to return Rd to make it same as other functions for lookup table
end

--ARM Manual A4-84 (ARM), A7-81
function utility.ORR(Rd, Rs, CPSR)
	--C flag generated by the shifter
	local result = bit.bor(Rd, Rs)
	local flag = {}	--For CPSR update
	flag[flags.N] = bit.check(result, flags.N)
	flag[flags.Z] = (result == 0)
	--Manual sets carry by LSL shift 0 with Rs (Rm in ARM manual); this means 32 - 0 = 32th bit
	--Seems to be from the ARM version where RS gets shifted`
	--local C = bit.check(Rs, 32) and 1 or 0
	return result, utility.set_flag(CPSR, flag)
end

--ARM Manual A4-68 (ARM), A7-72, A7-73, A7-75
function utility.MOV(dummy, Offset8, CPSR)
	--Need dummy to make it same argument placement as other functions for lookup table
	--C flag generated by the shifter
	local flag = {}	--For CPSR update
	flag[flags.N] = bit.check(Offset8, flags.N)
	flag[flags.Z] = (Offset8 == 0)
	return Offset8, utility.set_flag(CPSR, flag)
end

--ARM Manual A4-12 (ARM), A7-23
function utility.BIC(Rd, Rs, CPSR)
	--C flag generated by the shifter
	local result = bit.band(Rd, bit.bnot(Rs))
	local flag = {}	--For CPSR update
	flag[flags.N] = bit.check(result, flags.N)
	flag[flags.Z] = (result == 0)
	return result, utility.set_flag(CPSR, flag)
end

--ARM Manual A4-82 (ARM), A7-79
function utility.MVN(dummy, Rs, CPSR)
	--C flag generated by the shifter
	local flag = {}	--For CPSR update
	flag[flags.N] = bit.check(Rs,31)
	flag[flags.Z] = (Rs == 0)
	return bit.bnot(Rs), utility.set_flag(CPSR, flag)
end

--ARM Manual A7-80 (THUMB only)
function utility.NEG(Rs, CPSR)
--You need to set flags similar to Operand1 being 0
	return utility.SUB(0, Rs, CPSR)
end

--ARM Manual A5-17 (Addressing Mode 2)
--ARM Manual A5-32 (Addressing Mode 3)
--ARM Manual A4-43, A4-60 (LDRT)
function utility.LDR(Base, Offset)
--don't set flags
	return utility.load_biz_addr(Base + Offset, 32)
end

--ARM Manual A4-46, A4-48 (LDRBT)
function utility.LDRB(Base, Offset)
--don't set flags
	return utility.load_biz_addr(Base + Offset, 8)
end

--ARM Manual A4-54
function utility.LDRH(Base, Offset)
--Add Offset to base address in Base. Load bits 0-15 of Rd fOffsetm the resulting address, and set bits 16-31 of Rd to 0.
	local result = utility.load_biz_addr(Base + Offset, 32)
	result = bit.band(0xFFFF, result)	-- binary 1111 1111 1111 1111
	return result
end

--ARM Manual A4-56
function utility.LDRSB(Base, Offset)
--Add Offset to base address in Base. Load bits 0-7 of Rd fOffsetm the resulting address, and set bits 8-31 of Rd to bit 7.
	local result = utility.load_biz_addr(Base + Offset, 32)
	result = bit.band(0xFF, result)	-- binary 1111 1111
	result = bit.check(result,7) and result + 0xFFFFFF00 or result	-- Make bits 8 to 31 to 1 by adding.
	return result
end

--ARM Manual A4-58
function utility.LDRSH(Base, Offset)
--Add Offset to base address in Base. Load bits 0-15 of Rd fOffsetm the resulting address, and set bits 16-31 of Rd to bit 15.
	local result = utility.load_biz_addr(Base + Offset, 32)
	result = bit.band(0xFFFF, result)	-- binary 1111 1111 1111 1111
	result = bit.check(result,15) and result + 0xFFFF0000 or result	-- Make bits 16 to 31 to 1 by adding.
	return result
end

--ARM Manual A4-193, A4-206 (STRT)
function utility.STR(Base, Offset, Value)
	utility.write_biz_addr(Base + Offset, Value, 32)
	return Base
end

--ARM Manual A4-195
function utility.STRB(Base, Offset, Value)
	utility.write_biz_addr(Base + Offset, Value, 8)
	return Base
end

--ARM Manual A4-204
function utility.STRH(Base, Offset, Value)
	--Add Offset to base address in Base. Store bits 0-15 of Value at the resulting address
	local bit_0_15 = bit.band(0xFFFF, Value)	-- binary 1111 1111 1111 1111
	utility.write_biz_addr(Base + Offset, bit_0_15, 32)
	return Base
end

--ARM Manual A4-80, A7-77 (THUMB)
function utility.MUL(Rd, Rs, CPSR)
--For the ARM version, pretend Rd is Rm instead. ie. Rm * Rs
	return utility.MLA(Rd, Rs, 0, CPSR)
end

--ARM Manual A4-251
function utility.UMULL(RdLo, RdHi, Rm, Rs, CPSR)
	return utility.UMLAL(0, 0, Rm, Rs, CPSR)
end

function utility.SMULL(RdLo, RdHi, Rm, Rs, CPSR)
	local low32, high32, temp_CPSR = utility.UMLAL(RdLo, RdHi, Rm, Rs, CPSR)
	high32 = (bit.check(Rm,31) ~= bit.check(Rs,31)) and bit.set(high32,31) or bit.clear(high32,31)
	return low32, high32, temp_CPSR
end

--ARM Manual A4-249
function utility.UMLAL(RdLo, RdHi, Rm, Rs, CPSR)
--http://tasvideos.org/forum/viewtopic.php?p=489523#489523
	local reslow = Rm * (Rs%0x10000)                   -- 0x0000LLLLLLLLLLLL
	local reshigh = Rm * math.floor(Rs/0x10000)        -- 0xHHHHHHHHHHHH0000
	
	local reslow_lo = reslow%0x100000000             -- 0x00000000LLLLLLLL
	local reslow_hi = math.floor(reslow/0x100000000) -- 0x0000LLLL00000000
	
	local reshigh_lo = reshigh%0x10000               -- 0x00000000HHHH0000
	local reshigh_hi = math.floor(reshigh/0x10000)   -- 0xHHHHHHHH00000000
	
	local low32 = reshigh_lo*0x10000 + reslow_lo
	local high32 = reshigh_hi + reslow_hi
	high32 = high32 + math.floor(low32/0x100000000) -- add what carries over
	low32 = (low32 + RdLo)%0x100000000 -- 32 bit
	high32 = (high32 + RdHi + carry_from(low32, RdLo))%0x100000000 -- 32 bit
	local flag = {}	--For CPSR update
	flag[flags.N] = bit.check(high32, flags.N)
	flag[flags.Z] = (high32 == 0 and low32 == 0)
	return low32, high32, utility.set_flag(CPSR, flag)
end

--ARM Manual A4-146
function utility.SMLAL(RdLo, RdHi, Rm, Rs, CPSR)
--[[Signed bit
	Rm	Rs	Rm x Rs
	0	0	0
	0	1	1
	1	0	1
	1	1	0
]]--
	local low32, high32, temp_CPSR = utility.UMLAL(RdLo, RdHi, Rm, Rs, CPSR)
	high32 = (bit.check(Rm,31) ~= bit.check(Rs,31)) and bit.set(high32,31) or bit.clear(high32,31)
	return low32, high32, temp_CPSR
end

--ARM Manual A4-66
function utility.MLA(Rm, Rs, Rn, CPSR)
--http://tasvideos.org/forum/viewtopic.php?p=489512#489512
--Rd = (Rm * Rs + Rn)[31:0]
	local reslow = Rm * (Rs%0x10000) -- Rm multiplied with lower 16 bits of Rs
	local reshigh = Rm * (math.floor(Rs/0x10000)%0x10000) -- Rm multiplied with higher 16 bits of Rs (shifted down)
	reshigh = reshigh%0x10000 -- only 16 bits can matter here if result is 32 bits
	
	local result = (reshigh*0x10000 + reslow + Rn)%0x100000000 -- recombine and cut off to 32 bits
	local flag = {}	--For CPSR update
	flag[flags.N] = bit.check(result, flags.N)
	flag[flags.Z] = (result == 0)
	return result, utility.set_flag(CPSR, flag)
end

--[[
ARM Manual A4-36
LDM(1)
MemoryAccess(B-bit, E-bit)
if ConditionPassed(cond) then
	address = start_address
	for i = 0 to 14
		if register_list[i] == 1 then
			Ri = Memory[address,4]
			address = address + 4
	if register_list[15] == 1 then
		value = Memory[address,4]
		if (architecture version 5 or above) then
			pc = value AND 0xFFFFFFFE
			T Bit = value[0]
		else
			pc = value AND 0xFFFFFFFC
		address = address + 4
	assert end_address == address - 4 

ARM Manual A4-38	
LDM(2)
MemoryAccess(B-bit, E-bit)
if ConditionPassed(cond) then
	address = start_address
	for i = 0 to 14
		if register_list[i] == 1
			Ri_usr = Memory[address,4]
			address = address + 4
	assert end_address == address - 4

ARM Manual A4-40
LDM(3)
MemoryAccess(B-bit, E-bit)
if ConditionPassed(cond) then
	address = start_address
	for i = 0 to 14
		if register_list[i] == 1 then
			Ri = Memory[address,4]
			address = address + 4
	if CurrentModeHasSPSR() then
		CPSR = SPSR
	else
		UNPREDICTABLE
	value = Memory[address,4]
	PC = value
	address = address + 4
	assert end_address == address - 4
	
--ARM Manual A5-43
LDM/STM IA (Increment After)
start_address = Rn
end_address = Rn + (Number_Of_Set_Bits_In(register_list) * 4) - 4
if ConditionPassed(cond) and W == 1 then
	Rn = Rn + (Number_Of_Set_Bits_In(register_list) * 4)

--ARM Manual A5-44
LDM/STM IB (Increment Before)
start_address = Rn + 4
end_address = Rn + (Number_Of_Set_Bits_In(register_list) * 4)
if ConditionPassed(cond) and W == 1 then
	Rn = Rn + (Number_Of_Set_Bits_In(register_list) * 4)

--ARM Manual A5-45
LDM/STM DA (Decrement After)
start_address = Rn - (Number_Of_Set_Bits_In(register_list) * 4) + 4
end_address = Rn
if ConditionPassed(cond) and W == 1 then
	Rn = Rn - (Number_Of_Set_Bits_In(register_list) * 4)

--ARM Manual A5-46
LDM/STM DB (Decrement Before)
start_address = Rn - (Number_Of_Set_Bits_In(register_list) * 4)
end_address = Rn - 4
if ConditionPassed(cond) and W == 1 then
	Rn = Rn - (Number_Of_Set_Bits_In(register_list) * 4)

--ARM Manual A5-48 for name if Rn is stack
Plan:
There are 5 bits
	P  U  S  W  L are bits 
	24 23 22 21 20 respectively

	P (bit 24)
		P == 0
			indicates that the word addressed by Rn is included in the range of memory
			locations accessed, lying at the top (U==0) or bottom (U==1) of that range.
			
			arm-instructionset.pdf claims it means post; add offset after transfer
		P == 1
			indicates that the word addressed by Rn is excluded from the range of memory
			locations accessed, and lies one word beyond the top of the range (U==0) or one
			word below the bottom of the range (U==1).
			
			arm-instructionset.pdf claims it means pre; add offset before transfer
			
	U (bit 23)
		U == 0
			indicates transfer is made upwards from the base address
		U == 1
			indicates transfer is made downwards from the base address
	
	S (bit 22)
		S == 0
			For LDMs that load the PC, the S bit indicates that the CPSR is loaded from the SPSR.
			For LDMs that do not load the PC and all STMs, the S bit indicates that when the processor is in a
			privileged mode, the User mode banked registers are transferred instead of the registers of
			the current mode.
		S == 1
			LDM with the S bit set is UNPREDICTABLE in User or System mode. 
]]--
--Make a table of each integer with number of bits set
local num_to_bits = {[0] = 0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4};
--ARM Manual A4-36, A4-38, A4-40
-- function utility.LDM1(Base, RList, registers)
	-- --[[3 versions:
	-- 1. Load Multiple
	-- 2. User Registers Load Multiple
	-- 3. Load Multiple with Restore CPSR
	-- ]]--
	-- local address = Base
	-- --it's 16 bits, so split the number into 4
	-- local num = 
	-- for i = 0,14 do
		-- if bit.check(RList,i) then
			-- registers[i] = utility.load_biz_addr(address, 32)
			-- address = address + 4
		-- end
	-- end
	-- if bit.check(RList,15) then
		-- local value = utility.load_biz_addr(address, 32)
		-- registers[15] = bit.band(value,0xFFFFFFFC)	--GBA is ARMv4, so no need to check if ARMv5+
		-- address = address + 4
	-- end
	-- local end_cond = ()
-- end

--Arith without ADC use
--ARM Manual A4-6 (ARM), A7-5, A7-6, A7-7, A7-8, A7-9, A7-10, A7-11, A7-12 (THUMB)
function ADD(Rd, Rn, CPSR)
--If Rn is PC, it should be the address of the ADD function + 8 bytes
--CPSR isn't updated for certain situations; take this into account on the format functions
--This is without using ADC
	local result = (Rd + Rn) % 4294967296
	local flag = {}	--For CPSR update
	flag[flags.N] = bit.check(result, flags.N)
	flag[flags.Z] = (result == 0)
	flag[flags.C] = carry_from(Rd, Rn)
	flag[flags.V] = overflow_from_add(Rd, Rn)
	return result, utility.set_flag(CPSR, flag)
end

function SUB(Rd, Rn, CPSR)
	local result = Rd - Rn
	local flag = {}	--For CPSR update
	flag[flags.N] = bit.check(result, flags.N)
	flag[flags.Z] = (result == 0)
	flag[flags.C] = (borrow_from(Rd, Rn) == 1)	--NOT borrow_from
	flag[flags.V] = overflow_from_sub(Rd, Rn)
	return result, utility.set_flag(CPSR, flag)
end

return utility
