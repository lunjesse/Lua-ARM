local utility = {}

function utility.set_flag(CPSR, N, Z, C, V, Q)
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
	local temp = CPSR
	-- console.log("Now: "..bizstring.binary(temp))
	if N > 0 then temp = bit.set(temp,31) else temp = bit.clear(temp,31) end
	if Z > 0 then temp = bit.set(temp,30) else temp = bit.clear(temp,30) end
	if C > 0 then temp = bit.set(temp,29) else temp = bit.clear(temp,29) end
	if V > 0 then temp = bit.set(temp,28) else temp = bit.clear(temp,28) end
	if Q > 0 then temp = bit.set(temp,27) else temp = bit.clear(temp,27) end
	-- console.log("N: "..N.." Z: "..Z.." C: "..C.." V: "..V.." Q: "..Q)
	-- console.log("After: "..bizstring.binary(temp))
	return temp
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
	return A+B > 4294967295 and 1 or 0
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
	local A31 = bit.check(A, 31) and 1 or 0
	local B31 = bit.check(B, 31) and 1 or 0
	local AB31 = bit.check(A+B, 31) and 1 or 0
	return (A31 == B31 and A31 ~= AB31) and 1 or 0
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
	local A31 = bit.check(A, 31) and 1 or 0
	local B31 = bit.check(B, 31) and 1 or 0
	local AB31 = bit.check(A-B, 31) and 1 or 0
	return (A31 ~= B31 and A31 ~= AB31) and 1 or 0
end

function ADC(Rs, Rn, Carry, CPSR, Sub)
	--Insert a boolean to determine if subtract or not. Default false
	--we need carry as well, since some instructions ignore carry flag
	local result = (Rs + Rn + Carry)
	local sum32 = result % 4294967296
	local N = bit.check(sum32,31) and 1 or 0
	local Z = (sum32 == 0) and 1 or 0
	local C = carry_from(Rs, Rn + Carry)
	local V = 0
	--Can't seem to figure out how to implement SUB as ADD using ADC, so just using a bool to check which version of overflow to use
	if Sub == true then
		V = overflow_from_sub(Rs, bit.bnot(Rn))
	else
		V = overflow_from_add(Rs, Rn + Carry)
	end
	local Q = bit.check(CPSR, 27) and 1 or 0	--unchanged
	-- console.log("After: N: "..N.." Z: "..Z.." C: "..C.." V: "..V.." Q: "..Q)
	return sum32, utility.set_flag(CPSR, N, Z, C, V, Q)
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
	local C = nil
	--LSL immediate
	if Offset == 0 then
		C = bit.check(CPSR, 29) and 1 or 0	--C flag unaffected if 0 shift
		result = Rs
	elseif Offset < 32 then 
		C = bit.check(Rs, 32-Offset) and 1 or 0
		result = bit.lshift(Rs, Offset)
	--LSL register
	elseif Offset == 32 then
		C = bit.check(Rs, 0) and 1 or 0
		result = 0
	else	--Greater than 32
		C = 0
		result = 0
	end
	local N = bit.check(result, 31) and 1 or 0
	local Z = (result == 0) and 1 or 0
	--V, Q flag unchanged
	local V = bit.check(CPSR, 28) and 1 or 0
	local Q = bit.check(CPSR, 27) and 1 or 0
	return result, utility.set_flag(CPSR, N, Z, C, V, Q)
end

--ARM Manual A5-11, A7-68 (THUMB)
function utility.LSR1(Rs, Offset, CPSR)
	--There are 2 cases. LSR immediate offset of 5 bits, and LSR register offset using the least significant byte (bits 7 to 0). 
	--In this case, it's immediate offset. An offset of 0 indicates logical right shift of 32 rather than 0; 
	--instead, LSR #0 is converted to LSL #0. This applies to ASR and ROR as well
	local result = nil
	local C = nil
	if Offset == 0 then
		C = bit.check(Rs, 31) and 1 or 0
		result = 0
	else
		C = bit.check(Rs, Offset-1) and 1 or 0
		result = bit.rshift(Rs, Offset)
	end
	local N = bit.check(result,31) and 1 or 0
	local Z = (result == 0) and 1 or 0
	--V, Q flag unchanged
	local V = bit.check(CPSR, 28) and 1 or 0
	local Q = bit.check(CPSR, 27) and 1 or 0
	return result, utility.set_flag(CPSR, N, Z, C, V, Q)
end

--ARM Manual A5-12, A7-70 (THUMB)
function utility.LSR2(Rd, Rs, CPSR)
	--There are 2 cases. LSR immediate offset of 5 bits, and LSR register offset using the least significant byte (bits 7 to 0). 
	--In this case, it's register offset. Unlike LSR1, this does allow LSR #0 to occur.
	--We first mask the Offset (Rs, in this case) into an 8 bit number
	Rs = bit.band(0xFF, Rs)
	local result = nil
	local C = nil
	if Rs == 0 then
		C = bit.check(CPSR, 29) and 1 or 0	--C flag unaffected if 0 shift
		result = Rd
	elseif Rs < 32 then
		C = bit.check(Rd, Rs-1) and 1 or 0
		result = bit.rshift(Rd, Rs)
	elseif Rs == 32 then
		C = bit.check(Rd, 31) and 1 or 0
		result = 0
	else	--Greater than 32
		C = 0
		result = 0
	end
	local N = bit.check(result,31) and 1 or 0
	local Z = (result == 0) and 1 or 0
	--V, Q flag unchanged
	local V = bit.check(CPSR, 28) and 1 or 0
	local Q = bit.check(CPSR, 27) and 1 or 0
	return result, utility.set_flag(CPSR, N, Z, C, V, Q)
end

--ARM Manual A5-13, A7-15 (THUMB)
function utility.ASR1(Rm, Offset, CPSR)
	--There are 2 cases. ASR immediate offset of 5 bits, and ASR register offset using the least significant byte (bits 7 to 0). 
	--In this case, it's immediate offset. An offset of 0 indicates arithmetic right shift of 32 rather than 0; 
	--instead, ASR #0 is converted to LSL #0. This applies to LSR and ROR as well
	local result = nil
	local C = nil
	if Offset == 0 then
		C = bit.check(Rm, 31) and 1 or 0
		if C == 0 then
			result = 0
		else	--bit 31 of Rm is 1
			result = 0xFFFFFFFF
		end
	else
		C = bit.check(Rm, Offset-1) and 1 or 0
		result = bit.arshift(Rs, Offset)
	end
	local N = bit.check(result,31) and 1 or 0
	local Z = (result == 0) and 1 or 0
	--V, Q flag unchanged
	local V = bit.check(CPSR, 28) and 1 or 0
	local Q = bit.check(CPSR, 27) and 1 or 0
	return result, utility.set_flag(CPSR, N, Z, C, V, Q)
end

--ARM Manual A5-14, A7-17 (THUMB)
function utility.ASR2(Rd, Rs, CPSR)
	--There are 2 cases. ASR immediate offset of 5 bits, and ASR register offset using the least significant byte (bits 7 to 0). 
	--In this case, it's register offset. Unlike ASR1, this does allow ASR #0 to occur.
	--We first mask the Offset (Rs, in this case) into an 8 bit number
	Rs = bit.band(0xFF, Rs)
	local result = nil
	local C = nil
	if Rs == 0 then
		C = bit.check(CPSR, 29) and 1 or 0	--C flag unaffected if 0 shift
		result = Rd
	elseif Rs < 32 then
		C = bit.check(Rd, Rs-1) and 1 or 0
		result = bit.arshift(Rs, Rs)
	else --Greater than 32
		C = bit.check(Rd, 31) and 1 or 0
		if C == 0 then
			result = 0
		else	--bit 31 of Rd is 1
			result = 0xFFFFFFFF
		end
	end
	local N = bit.check(result,31) and 1 or 0
	local Z = (result == 0) and 1 or 0
	--V, Q flag unchanged
	local V = bit.check(CPSR, 28) and 1 or 0
	local Q = bit.check(CPSR, 27) and 1 or 0
	return result, utility.set_flag(CPSR, N, Z, C, V, Q)
end

--ARM Manual pA7-92
function utility.ROR(Rd, Rs, CPSR)
	--THUMB version
	--Rotate by the least significant byte (bits 7 to 0).
	--We first mask the Offset (Rs, in this case) into an 8 bit number
	Rs = bit.band(0xFF, Rs)
	local result = nil
	local C = nil
	if Rs == 0 then
		C = bit.check(CPSR, 29) and 1 or 0	--C flag unaffected if 0 rotate
		result = Rd
	else
		--Apparently we now only care about bits 4 to 0 for the else
		Rs = bit.band(0xF, Rs)
		if Rs == 0 then 
			C = bit.check(Rd, 31) and 1 or 0
			result = Rd
		else	--Rs[4:0] > 0
			C = bit.check(Rd, Rs-1) and 1 or 0
			result = bit.ror(Rd, Rs)
		end
	end
	local N = bit.check(result,31) and 1 or 0
	local Z = (result == 0) and 1 or 0
	--V, Q flag unchanged
	local V = bit.check(CPSR, 28) and 1 or 0
	local Q = bit.check(CPSR, 27) and 1 or 0
	return result, utility.set_flag(CPSR, N, Z, C, V, Q)
end

--ARM Manual A5-15, A5-17 (RRX)
function utility.ROR1(Rm, Offset, CPSR)
	--This is not used in THUMB; instead it is for ARM, data processing
	--There are 3 cases. ROR immediate offset of 8 bits, ROR immediate offset of 5 bits, and ROR register offset using the least significant byte (bits 7 to 0). 
	--Bit 25 is 0, so in this case, it's either immediate offset of 5 bits, or register offset using the least significant byte. 
	--Bit 4 is 0, so it's immediate offset of 5 bits
	--"If R15 is specified as register Rm or Rn, the value used is the address of the current instruction plus 8"
	local result = nil
	local C = nil
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
		result = temp == 1 and bit.set(result, 31) or result
	else
		result = bit.ror(Rs, Offset)
		C = bit.check(Rm, Offset-1) and 1 or 0
	end
	local N = bit.check(result,31) and 1 or 0
	local Z = (result == 0) and 1 or 0
	--V, Q flag unchanged
	local V = bit.check(CPSR, 28) and 1 or 0
	local Q = bit.check(CPSR, 27) and 1 or 0
	return result, utility.set_flag(CPSR, N, Z, C, V, Q)
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
	local C = nil
	if Rs == 0 then
		result = Rm
		C = bit.check(CPSR, 29) and 1 or 0	--C flag unaffected if 0 rotate
	else
		Rs = bit.band(0x1F, Rs) --Only care about first 5 bits
		if Rs == 0 then
			result = Rm
			C = bit.check(Rm, 31) and 1 or 0	--Differnt than above
		else	--Bits 0-4 are not 0
			result = bit.ror(Rm, Rs)
			C = bit.check(Rm, Rs-1) and 1 or 0
		end
	end
	local N = bit.check(result,31) and 1 or 0
	local Z = (result == 0) and 1 or 0
	--V, Q flag unchanged
	local V = bit.check(CPSR, 28) and 1 or 0
	local Q = bit.check(CPSR, 27) and 1 or 0
	return result, utility.set_flag(CPSR, N, Z, C, V, Q)
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
	local C = nil
	if rotate_imm == 0 then
		C = bit.check(CPSR, 29) and 1 or 0	--C flag unaffected if 0 rotate
	else
		result = bit.ror(immed_8, rotate_imm*2)
		C = bit.check(result, 31) and 1 or 0	--Set this to bit 31 of the shifted number instead of the original
	end
	local N = bit.check(result,31) and 1 or 0
	local Z = (result == 0) and 1 or 0
	--V, Q flag unchanged
	local V = bit.check(CPSR, 28) and 1 or 0
	local Q = bit.check(CPSR, 27) and 1 or 0
	return result, utility.set_flag(CPSR, N, Z, C, V, Q)
end

--ARM Manual A7-14
function utility.AND(Rd, Rs, CPSR)
	local result = bit.band(Rd,Rs)
	local N = bit.check(result,31) and 1 or 0
	local Z = (result == 0) and 1 or 0
	local C = bit.check(Rs, 32) and 1 or 0
	--V, Q flag unchanged
	local V = bit.check(CPSR, 28) and 1 or 0
	local Q = bit.check(CPSR, 27) and 1 or 0
	return result, utility.set_flag(CPSR, N, Z, C, V, Q)
end

--ARM Manual A7-43
function utility.EOR(Rd, Rs, CPSR)
	local result = bit.bxor(Rd, Rs)
	local N = bit.check(result,31) and 1 or 0
	local Z = (result == 0) and 1 or 0
	--C, V, Q flag unchanged
	local C = bit.check(CPSR, 29) and 1 or 0
	local V = bit.check(CPSR, 28) and 1 or 0
	local Q = bit.check(CPSR, 27) and 1 or 0
	return result, utility.set_flag(CPSR, N, Z, C, V, Q)
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
	local C = bit.check(CPSR,29) and 1 or 0
	return ADC(Rs, Rn, C, CPSR, false)
end

--ARM Manual A4-125 (ARM), A7-94
function utility.SBC(Rs, Rn, CPSR)
	local C = bit.check(CPSR, 29) and 0 or -1
	return ADC(Rs, bit.bnot(Rn), C, CPSR, true)
end

--ARM Manual A4-117
function utility.RSC(Rs, Rn, CPSR)
--Subtract contents of Rs from contents of Rn, with NOT carry. Ie. Rn - Rs
	local C = bit.check(CPSR,29) and 0 or -1	--NOT C flag; Also needs to be - C, which you can do by making C negative
	return ADC(Rn, bit.bnot(Rs), C, CPSR, true)
end

--ARM Manual A4-230 (ARM), A7-122
function utility.TST(Rd, Rs, CPSR)
--From  ARM manual: Test (register) performs a logical AND operation on a register value and an optionally-shifted register value.
--It updates the condition flags based on the result, and discards the result.
	local _, CPSR2 = utility.AND(Rd, Rs, CPSR)
	return Rd, CPSR2	--Need to return Rd to make it same as other functions for lookup table
end

--ARM Manual A4-228
function utility.TEQ(Rd, Rs, CPSR)
--From ARM manual: TEQ (Test Equivalence) compares a register value with another arithmetic value. The condition flags are
-- updated, based on the result of logically exclusive-ORing the two values, so that subsequent instructions can
--be conditionally executed.
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
	local result = bit.bor(Rd, Rs)
	local N = bit.check(result,31) and 1 or 0
	local Z = (result == 0) and 1 or 0
	--Manual sets carry by LSL shift 0 with Rs (Rm in ARM manual); this means 32 - 0 = 32th bit
	local C = bit.check(Rs, 32) and 1 or 0
	--V, Q flag unchanged
	local V = bit.check(CPSR, 28) and 1 or 0
	local Q = bit.check(CPSR, 27) and 1 or 0
	return result, utility.set_flag(CPSR, N, Z, C, V, Q)
end

--ARM Manual A4-68 (ARM), A7-72, A7-73, A7-75
function utility.MOV(dummy, Offset8, CPSR)
--Need dummy to make it same argument placement as other functions for lookup table
	local N = bit.check(Offset8,31) and 1 or 0
	local Z = (Offset8 == 0) and 1 or 0
	local C = bit.check(CPSR, 29) and 1 or 0	--not sure if changed
	--V, Q flag unchanged
	local V = bit.check(CPSR, 28) and 1 or 0
	local Q = bit.check(CPSR, 27) and 1 or 0
	return Offset8, utility.set_flag(CPSR, N, Z, C, V, Q)
end

--ARM Manual A4-12 (ARM), A7-23
function utility.BIC(Rd, Rs, CPSR)
	local result = bit.band(Rd, bit.bnot(Rs))
	local N = bit.check(result,31) and 1 or 0
	local Z = (result == 0) and 1 or 0
	--Manual sets carry by LSL shift 0 with Rs (Rm in ARM manual); this means 32 - 0 = 32th bit
	local C = bit.check(Rs, 32) and 1 or 0
	--V, Q flag unchanged
	local V = bit.check(CPSR, 28) and 1 or 0
	local Q = bit.check(CPSR, 27) and 1 or 0
	return result, utility.set_flag(CPSR, N, Z, C, V, Q)
end

--ARM Manual A4-82 (ARM), A7-79
function utility.MVN(dummy, Rs, CPSR)
	local N = bit.check(Rs,31) and 1 or 0
	local Z = (Rs == 0) and 1 or 0
	--Manual sets carry by LSL shift 0; this means 32 - 0 = 32th bit
	local C = bit.check(Rs, 32) and 1 or 0	
	--V, Q flag unchanged
	local V = bit.check(CPSR, 28) and 1 or 0
	local Q = bit.check(CPSR, 27) and 1 or 0
	return bit.bnot(Rs)
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
	for i = 16, 31 do
		bit.clear(result,i)
	end
	return result
end

--ARM Manual A4-56
function utility.LDRSB(Base, Offset)
--Add Offset to base address in Base. Load bits 0-7 of Rd fOffsetm the resulting address, and set bits 8-31 of Rd to bit 7.
	local result = utility.load_biz_addr(Base + Offset, 32)
	local bit7 = bit.check(result,7) and 1 or 0
	result = bit.band(0xFF, result)	-- binary 1111 1111
	for i = 8, 31 do
		bit.set(result,bit7)
	end
	return result
end

--ARM Manual A4-58
function utility.LDRSH(Base, Offset)
--Add Offset to base address in Base. Load bits 0-15 of Rd fOffsetm the resulting address, and set bits 16-31 of Rd to bit 15.
	local result = utility.load_biz_addr(Base + Offset, 32)
	local bit15 = bit.check(result,15) and 1 or 0
	result = bit.band(0xFFFF, result)	-- binary 1111 1111 1111 1111
	for i = 16, 31 do
		bit.set(result,bit15)
	end
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

--Arith without ADC use
--ARM Manual A4-6 (ARM), A7-5, A7-6, A7-7, A7-8, A7-9, A7-10, A7-11, A7-12 (THUMB)
function ADD(Rd, Rn, CPSR)
--If Rn is PC, it should be the address of the ADD function + 8 bytes
--CPSR isn't updated for certain situations; take this into account on the format functions
--This is without using ADC
	local result = (Rd + Rn) % 4294967296
	local N = bit.check(result,31) and 1 or 0
	local Z = (result == 0) and 1 or 0
	local C = carry_from(Rd, Rn)
	local V = overflow_from_add(Rd, Rn)
	--Q flag unchanged
	local Q = bit.check(CPSR, 27) and 1 or 0
	return result, utility.set_flag(CPSR, N, Z, C, V, Q)
end

function SUB(Rd, Rn, CPSR)
	local result = Rd - Rn
	local N = bit.check(result,31) and 1 or 0
	local Z = (result == 0) and 1 or 0
	local C = (borrow_from(Rd, Rn) == 1) and 0 or 1	--NOT borrow_from
	local V = overflow_from_sub(Rd, Rn)
	--Q flag unchanged
	local Q = bit.check(CPSR, 27) and 1 or 0
	return result, utility.set_flag(CPSR, N, Z, C, V, Q)
end

return utility
